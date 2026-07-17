# ADR 0004: Drop coordmap rather than revive it

**Status:** accepted
**Date:** 2026-07-16
**Owner:** Seyed Yahya Shirazi

## Context

`coordmap` is a FEM coordinate-mapping utility referenced by `nft_get_config` history and
by NFT's old FEM potential path. It ships as a binary on **no** platform — it is absent from
every platform variant in this repo — while its source does exist and is complete in the
SCCN archive (`fem_util/coordmap`, 63 source files, self-contained Makefile dated 2021,
depending only on zlib).

Epic 1 (#31) is importing source for every shipped tool and rebuilding it with CMake. That
forces a decision on `coordmap`: rebuild it like the others, or formally drop it. Continuing
to "not build it" without deciding leaves a permanently ambiguous entry in the provenance
manifest.

## Decision

Drop `coordmap`. It will not be imported, built, or shipped. Its entry in
`provenance/binaries.yaml` records it as deliberately dropped, with this ADR as the reason.

## Consequences

Easier: one fewer tool to build, license, and carry across four platforms; the provenance
manifest gets an honest, closed entry instead of a silent omission; NFT keeps exactly one
FEM potential-calculation route rather than two.

Harder / obligations: if a future feature needs **direct dipole-based FEM potentials** — as
opposed to the reciprocity/LFM approach the live pipeline uses — this decision must be
revisited. SCALE integration (E6, #36) is the most plausible trigger, since it wraps SCS
plus conductivity estimation; that work should re-check this ADR before assuming the
capability is absent. Reviving it later is cheap: the source is complete and self-contained.

Note this is a decision to drop a *tool*, not a capability. The coordinate-to-element
mapping and interpolation-weight computation that `coordmap` performs still exists in NFT —
it lives inside the `metufem` MEX.

## Alternatives considered

- **Revive and rebuild it.** The source is complete, dependency-light (zlib only) and would
  be trivial to build on every target. It lost because nothing calls it, and reviving it
  would resurrect a *second, parallel* potential-calculation route that duplicates what the
  live pipeline already does — including the hardcoded-path bug its caller carried
  (`conf.coordmap = '/home/zeynep/Programs/fem_util/coordmap/coordmap'`, with the source's
  own comment "XXX for testing only. Fix before release"). Adding a duplicate code path with
  no callers and no tests is technical debt, not robustness.
- **Leave it undecided.** Rejected: silently continuing not to build a tool leaves the
  provenance manifest ambiguous, which is exactly what Epic 1 exists to end.

## Receipts

Evidence gathered during the E1 Phase 1 archive survey (issue #37):

- `coordmap` ships on no platform: exhaustive `find . -iname "*coordmap*"` returns nothing.
- Its only MATLAB caller, `metufem_calcpot.m`, was deleted in commit `4174f69`
  ("Delete 17 confirmed-dead files") as having zero external callers.
  `git log --all -p -- '*metufem_calcpot*'` confirms it was introduced whole in the initial
  squashed commit and **never called from any other `.m` file at any point in this repo's
  history**. Its pre-deletion content is recoverable via `git show 4174f69^:metufem_calcpot.m`.
- The live FEM paths use the MEX instead: `nft_fem_forward_problem_solution.m:135-138` and
  `ip_dipolefitting.m` both obtain potentials via `metufem('pot', ss, 'interp')`;
  `metufem_calcrf.m` computes reciprocity fields via `forward -rfpot`. Neither references
  `coordmap`.
- Source (not imported): `fem_util/coordmap` in the SCCN internal archive — GPLv2+ headers
  (Akalin Acar / Acar / Gencer, 2008) on most files, though `coordmap.cc` and `meshutil.*`
  carry none.

Related: ADR-0003 (binary provenance strategy), issue #37 (survey), issue #38 (licensing).
