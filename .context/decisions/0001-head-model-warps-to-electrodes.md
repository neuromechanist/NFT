# ADR 0001: Head model warps to electrodes (not electrodes to head model)

**Status:** accepted
**Date:** 2026-07-11
**Owner:** Seyed Yahya Shirazi

## Context

EEG source localization needs the forward-model geometry to match where the sensors
actually are. EEGLAB's DIPFIT keeps a fixed template head and warps the *electrode
coordinates* onto it (rigid / rescale / nonlinear transforms). NFT does the reverse:
it deforms a 4-layer MNI template head mesh onto the subject's real electrode
positions, via a 3-D thin-plate-spline radial-basis warp implemented in
`warping_main_function.m` (and applied to all mesh layers + the source-space grid).
Accurate electrode positions and subject head models measurably reduce localization
error (Akalin Acar & Makeig 2013; Shirazi & Huang 2019).

## Decision

The head-model-warps-to-electrodes approach is NFT's defining scientific capability
and is preserved as-is. The warping math in `warping_main_function.m` is treated as a
crown-jewel component: refactored for clarity and de-duplicated, but not
re-derived or replaced without validation against reference outputs.

## Consequences

- Easier: honest subject-specific forward models; a clear differentiator from DIPFIT.
- Harder: the warp can create mesh self-intersections, requiring a mesh-repair step
  (currently the closed `procmesh` binary) — this couples the science to a binary
  dependency (see ADR 0003).
- Obligation: any refactor of the warp must reproduce existing reference results
  before it is considered done.

## Alternatives considered

- **Adopt DIPFIT's electrode-to-head warp:** rejected — it discards the exact
  capability that makes NFT scientifically worthwhile.
- **Rewrite the warp from scratch:** rejected for now — high risk against a
  validated, self-contained implementation; clarity refactor is enough.

## Receipts

- `warping_main_function.m`, `nft_warping_mesh.m` (+ duplicates) — see `.context/research.md` §warping.
- `docs/references/`: Akalin Acar & Makeig 2013 (`10.1007/s10548-012-0274-6`);
  Shirazi & Huang 2019 (`10.3389/fnins.2019.01159`).
