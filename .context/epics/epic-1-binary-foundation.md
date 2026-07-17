# Epic 1: Reproducible binary foundation

Tracking issue: [#31](https://github.com/neuromechanist/NFT/issues/31)

Part of program #1. **Gates the entire platform North Star.**

## Goal

Every binary NFT ships builds from **in-tree source** via CMake, reproducibly, on the
supported MATLAB targets, with Windows as a best-effort lane that never blocks. No
unattributed binaries.

## Targets (CORRECTED 2026-07-16 — the original list was not achievable)

The North Star was "Linux and Mac, x86_64 and arm64; Windows if doable as a workflow".
Verified against MathWorks docs: **MATLAB does not exist on every listed target**, and
NFT is a MATLAB plugin.

| Target | MATLAB status | Verdict |
|---|---|---|
| Linux x86_64 (`glnxa64`) | supported | **primary** |
| Linux arm64 | **not supported** — Runtime is glnxa64-only; ARM64 Linux is only an Embedded Coder *deployment* target | **impossible, dropped** |
| Mac arm64 (`maca64`) | supported; **the ONLY Mac from R2026a on** | **primary — the critical gap** |
| Mac x86_64 (`maci64`) | **R2025b is the FINAL Intel-Mac release** | legacy; build while free, never block |
| Windows x86_64 (`win64`) | supported | best-effort, never a blocker |

Sources: [Linux reqs](https://www.mathworks.com/support/requirements/matlab-linux.html),
[Apple Silicon](https://www.mathworks.com/support/requirements/apple-silicon.html),
[Platform Road Map](https://www.mathworks.com/support/requirements/platform-road-map.html)

**So the goal is 2 primary + 1 best-effort, not 5.** Mac arm64 matters most.

## Why this is first

Measured 2026-07-16, on the targets that actually exist:

| Target | Segmentation | BEM / warping | FEM |
|---|---|---|---|
| Linux x86_64 | works | works | works |
| **Mac arm64** | **broken** (`matitk` has no `mexmaca64`) | Rosetta only | **broken** (no `.osx`) |
| Mac x86_64 | works | works (Intel `.osx`) | **broken** (no `.osx`) |
| Windows | works | partial | broken |

So the full pipeline runs on **one target**, and the Mac platform with a future is the
worst off. No amount of MATLAB-side cleanup moves any of this. The binaries are the gate.

## The biggest risk: matitk

`matitk` is the ONE tool with no source found in the archive, it is **live** in the
segmentation path (`segm_aniso_filtering.m:36`, `segm_scalp.m:34`, `segm_brain.m:53,61`),
it ships ~43 MB of Intel-only MEX, and it has **no `mexmaca64`**. MEX cannot run under
Rosetta — it must match MATLAB's arch — so **segmentation is dead on Apple Silicon**
(verified: `computer('arch')`=`maca64`, `matitk` Undefined).

**Owner decision: rebuild against modern ITK, preserving the exact filters** (Phase 8,
#45). Swapping to the Image Processing Toolbox was rejected because IPT's equivalents are
*different algorithms*, so segmentation output would change — contrary to "preserve the
science". This makes E1 **not independent of E2/E3**: verifying the rebuild needs a
segmentation baseline, which needs `nft_segmentation.m` (E2) and a test (E3), captured on
hallu where `matitk.mexa64` still works.

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
