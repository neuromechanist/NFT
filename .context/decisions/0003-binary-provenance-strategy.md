# ADR 0003: Binary provenance and build-from-source strategy

**Status:** proposed
**Date:** 2026-07-11
**Owner:** Seyed Yahya Shirazi

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
