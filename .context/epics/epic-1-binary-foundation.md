# Epic 1: Reproducible binary foundation

Tracking issue: [#31](https://github.com/neuromechanist/NFT/issues/31)

Part of program #1. **Gates the entire platform North Star.**

## Goal

Every binary NFT ships builds from **in-tree source** via CMake, reproducibly, on Linux and Mac across x86_64 and arm64, with Windows as a best-effort lane that never blocks. No unattributed binaries.

## Why this is first

NFT currently runs its full pipeline on **one of five targets**. Measured 2026-07-16:

| Target | BEM / warping | FEM |
|---|---|---|
| Linux x86_64 | works | works |
| Linux arm64 | nothing (every binary is x86-64 ELF) | no |
| Mac x86_64 | works (Intel `.osx`) | broken (no `.osx` exists) |
| Mac arm64 | works (Rosetta 2) | broken (no `.osx` exists) |
| Windows | partial (`.exe` for some) | broken (no `.exe`) |

No amount of MATLAB-side cleanup moves any of this. The binaries are the gate.

## What changed: the source is NOT lost

AGENTS.md and the old Phase C plan were built on the premise that `asc`/`qslim`/`bem_matrix`/`procmesh`/`Showmesh`/`metufem` have **no source**, and that `procmesh` means "contact developers". **This is false.** Verified against the SCCN cluster archive on 2026-07-16:

| Binary | Source | Build system |
|---|---|---|
| `bem_matrix` | `bem/metu_bem-0.2/` (20 src files) | Makefile |
| `procmesh` | `FMT_tools.0/ProcMesh.old/` (12 src files) | **CMakeLists.txt** + Makefile |
| `Showmesh` | `Showmesh.2.cmap/` (23 src files) | **CMakeLists.txt** + Makefile |
| `coordmap` | `fem_util/coordmap/` (63 src files) | Makefile |
| `asc` | `FMT_tools.0/asc.0/src/` (46 src files) | none |
| `quadmesh` | `Quadmesh/quadmesh.cpp` (17 src files) | none |
| `lin2quad` | `rfmatlab/lin2quad.cc` | none |
| `forward` (METU-FEM) | `metu_fem-0.1` .. `0.7` | makefile (PETSc) |
| `geodesic` | already in-repo | done, arm64 built (#18) |
| `tetgen` | public upstream (AGPL) | upstream |

So the strategy is **rebuild, not replace**. The old plan's C3 (swap BEM for OpenMEEG, `asc` for iso2mesh, `procmesh` for CGAL/MeshFix) was designed around unrecoverable source, so it becomes a **fallback**, not the plan. Rebuilding preserves the exact algorithms, which is the project's stated priority: retain the science, fix the engineering.

## Decisions (owner, 2026-07-16)

- Source is imported into this repo under `src/tools/` (single repo, simplest provenance; a clean checkout builds everything).
- Source is GPL and cleared to publish.
- Import scope: **only what NFT actually ships** (~10 tools). `SourceLoc`/`openskull`/`NFT-ani`/`GA` stay in the archive.
- Windows: best-effort CMake lane, never a blocker.

## Known risks (stated honestly)

- **The initial dependency survey was WRONG** — an include regex missed PETSc and reported `metu_fem` as dependency-free. It is not. Phase 1 must *measure* dependencies, not grep-and-assume. Treat any dependency claim not produced by Phase 1 as unverified.
- `procmesh`, `asc`, `Showmesh` include OpenGL/GLUT (Showmesh also libpng) yet run headless mid-pipeline today. The offscreen/headless story needs designing, not assuming.
- METU-FEM/PETSc is the hardest port; Windows likely descoped for it.
- TetGen is redistributed today with neither source nor its AGPLv3 text: a live compliance gap.
- Archive trees are ~2018-era C/C++; modern toolchains may need portability fixes. Any fix must be behavior-preserving and verified against the existing regression anchors.

## Success criteria

- A clean checkout builds every shipped tool on all four primary targets via documented, pinned CMake.
- CI produces `bin/<arch>/` artifacts + `SHA256SUMS` for all four targets; Windows best-effort.
- `provenance/binaries.yaml` carries an honest entry per binary (upstream, version, license, source location, sha256).
- TetGen ships with source + AGPLv3 text.
- A provenance CI gate fails on any unattributed binary.
- **FEM works on Mac** (broken on every Mac today).
- Rebuilt binaries reproduce the frozen regression baselines (warping smoke, DSL) within tolerance.
