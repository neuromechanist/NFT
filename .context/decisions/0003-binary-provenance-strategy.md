# ADR 0003: Binary provenance and build-from-source strategy

**Status:** superseded by ADR-0005
**Date:** 2026-07-11
**Owner:** Seyed Yahya Shirazi

> ## [SUPERSEDED 2026-07-16 by ADR-0005] Its premises were disproven by measurement
>
> This ADR was never accepted, and the E1 Phase 1 archive survey (issue #37) disproved the
> beliefs it rests on. **Do not plan from it.** Kept for the audit trail.
>
> What it got wrong:
> - **"the rest have no source"** and `procmesh` "requires contacting the developers" —
>   **false**. Source exists and is buildable for essentially every shipped tool. `procmesh`
>   already ships a `CMakeLists.txt` and is dependency-free C++03; its OpenGL dependency is
>   dead code.
> - **"a full source archive exists off-repo (to be located)"** — it was located and surveyed.
> - **"nothing runs natively on Apple Silicon except a rebuilt `tetgen.osx`"** — `geodesic`
>   now ships `geodesic.mexmaca64` (PR #18).
> - **"~150 MB"** — measured: ~100 MB across 118 tracked artifacts.
> - Its **Decision** gave equal billing to *replacing* tools with libraries (OpenMEEG,
>   iso2mesh, CGAL). Because source turned out to be recoverable, replacement is demoted to a
>   **last-resort fallback**: swapping a tool changes the algorithm, against NFT's first
>   principle of preserving the science.
>
> The correct strategy, with the measured evidence, is **ADR-0005: rebuild from recovered
> source; replace only as a fallback**.

## Context

NFT ships ~150 MB of precompiled third-party binaries (asc, qslim, bem_matrix/METU-FP,
procmesh, Showmesh, metufem/METU-FEM, matitk/ITK bridge, tetgen, quadmesh, lin2quad,
geodesic) across Linux/Windows/Intel-Mac variants. Only `geodesic/` has in-repo
source; `tetgen` is buildable from a well-known upstream; the rest have **no source in
the repo**, and `procmesh` per the README requires contacting the developers. Platform
dispatch is fragile (POSIX wrappers keyed on `uname -p`, only Linux + Intel-Mac), so
nothing runs natively on Apple Silicon except a rebuilt `tetgen.osx`. There is no
`LICENSE` file though the code is GPL v2+. This opacity is the single biggest barrier
to the repo being maintainable and reproducible. The owner reports a full source
archive exists off-repo (to be located).

## Decision

Every shipped binary must have recorded provenance (upstream source, version, license)
and a reproducible build recipe, or be replaced. Per binary, choose one of:
1. **Rebuild from upstream** where source exists — `tetgen`, `geodesic` (and any tool
   whose upstream is recoverable), producing arm64-native builds.
2. **Replace with a maintained library** — e.g. ITK/VTK/CGAL, OpenMEEG, or iso2mesh
   for mesh/BEM/FEM/segmentation steps where the closed binary's source is unrecoverable.
3. **Flag as blocked** — record what is needed (the owner's archive, an upstream
   contact) and gate the dependent pipeline behind a clear error until resolved.

No unattributed binaries remain in the tree. Add a `LICENSE` and a machine-readable
provenance manifest validated in CI.

## Consequences

- Easier: reproducible builds; native Apple-Silicon support; a repo a stranger can
  trust and rebuild; smaller/legible binary surface over time.
- Harder: real up-front effort to source, rebuild, or replace closed tools;
  library replacements must reproduce the reference demo outputs before swap-in.
- Obligation: hosting decision for large binaries (git vs release assets vs
  fetch-on-install) becomes its own follow-up ADR.

## Alternatives considered

- **Keep shipping opaque binaries:** rejected — perpetuates the unmaintainability and
  the silent Apple-Silicon failures that motivated this project.
- **Rewrite everything in pure MATLAB/Python:** rejected as the default — too costly;
  reserved for cases where no buildable source or library exists.

## Receipts

- `nft_get_config.m` (paths + hardcoded `/home/zeynep/...`), binary wrapper scripts
  (`asc1`, `qslim`, `Showmesh`), README binary list. See `.context/research.md`
  §binary-provenance for the full per-binary table.
- Reference outputs to validate replacements: `/Volumes/S1/git/NFTplugin_demo_*`.
