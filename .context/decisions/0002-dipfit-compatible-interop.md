# ADR 0002: DIPFIT is a compatibility contract, not code to fork

**Status:** accepted
**Date:** 2026-07-11
**Owner:** Seyed Yahya Shirazi

## Context

NFT aims to be a lightweight replacement/complement for EEGLAB's DIPFIT plugin
(`../dipfit`, actively maintained, v5.6). DIPFIT owns a rich downstream ecosystem
(`pop_dipplot`, `pop_leadfield`, `pop_multifit`, `pop_dipfit_loreta`) and a data
contract on the `EEG` structure (`EEG.dipfit.{hdmfile,mrifile,chanfile,coordformat,
coord_transform,chansel,model}`). NFT already partially populates this (e.g.
`test_script.m` sets `EEG.dipfit.model = EEG.etc.nft.model`) but also hardcodes
stale, version-pinned paths (`plugins/dipfit2.2/...`) that no longer exist in modern
EEGLAB, and vendors renamed forks of EEGLAB internals (`eeglab_readlocs.m`, dead).

## Decision

NFT interoperates with DIPFIT by targeting its `EEG.dipfit.*` data contract, keeping
NFT-specific state under `EEG.etc.nft.*`, and calling EEGLAB/DIPFIT functions on the
path rather than vendoring or forking them. NFT does not reimplement DIPFIT's UI or
copy its internals; it produces a superior subject-specific head model and its own
SCS/SCALE inverse solvers that plug into the same structure.

## Consequences

- Easier: DIPFIT's mature visualization/leadfield tools work unchanged on NFT models;
  smaller NFT surface area; users stay in a familiar EEGLAB workflow.
- Harder: NFT must track DIPFIT's `EEG.dipfit` schema as it evolves; version-agnostic
  path resolution is required (no hardcoded `dipfitN.N` folder names).
- Obligation: delete vendored EEGLAB forks (`eeglab_readlocs.m`) and fix stale paths;
  add an interop test that a DIPFIT tool consumes an NFT-built model.

## Alternatives considered

- **Fork DIPFIT / vendor EEGLAB functions:** rejected — creates drift and maintenance
  debt; the existing dead `eeglab_readlocs.m` is exactly this anti-pattern.
- **Standalone toolbox, ignore DIPFIT:** rejected — abandons the installed user base
  and the downstream plotting/leadfield ecosystem.
- **Route through vendored FieldTrip (`nft_dipfit/`):** rejected — that snapshot is
  dead and unsynchronized; adopting it is a separate, deliberate decision if ever needed.

## Receipts

- `../dipfit/dipfitdefs.m`, `pop_dipfit_settings.m`; `eeglab/functions/sigprocfunc/coregister.m`.
- NFT stale paths: `test_script.m:51-52`, `Inverse_Problem_Solution.m:260`,
  `nft_inverse_problem_solution.m:150`. See `.context/research.md`.
