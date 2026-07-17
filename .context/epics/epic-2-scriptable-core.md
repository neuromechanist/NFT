# Epic 2: Scriptable-first core

Tracking issue: [#32](https://github.com/neuromechanist/NFT/issues/32)

Part of program #1.

## Goal

NFT is usable **entirely from scripts**, with the GUI as an optional thin shell over the same code — the way EEGLAB offers both a GUI and a command-line path. One implementation, two front ends.

## Measured starting point (2026-07-16)

A scriptable pipeline **already exists** — `test_script.m` drives it, and 7 of 9 steps have working headless `nft_*` entry points (mesh, source space, warping, forward BEM, forward FEM, dipole inverse, DSL).

**The 2 gaps (GUI-only, no headless twin):**

- **Segmentation** — but its compute is already factored into 8 `segm_*.m` files, so `nft_segmentation.m` is a thin driver, not new science.
- **Coregistration** — only calls existing `warping_*` helpers, so likewise composable.

**The real debt:** *not one* of the six GUIs calls its headless twin. `Warping_mesh`, `Mesh_generation`, `Source_space_generation`, `Forward_Problem_Solution`, `Inverse_Problem_Solution` and `Distributed_Source_Localization` each **embed their own copy** of the pipeline (verified by grep: zero references to the `nft_*` counterpart in any of them). That duplication is why the flagship SCS solver once existed in two independently-editable copies.

## Why it matters beyond tidiness

The headless path is the part CI can run on Linux and Mac, x86_64 and arm64, **without a display**. Making the GUIs thin wrappers over `nft_*` is the same work as the scriptable goal approached from the other end, and it is what makes the platform North Star testable at all. GUIDE GUIs have no automated correctness coverage and can only be launch-smoke-tested.

## Scope

- `nft_segmentation.m` — thin driver over the existing `segm_*.m` compute.
- `nft_coregistration.m` — thin driver over the existing `warping_*` helpers.
- Each GUI becomes a thin wrapper calling its `nft_*` twin (one GUI per PR, each launch-smoke-tested).
- Finish the de-duplication of the genuinely-diverged helpers left after #22/#23/#28: `Create_regular_source_space`, `EdgeList`, `flipElem`, `ElemNormal`, `ElementsOfTheNodes`, `mesh_final_correction` vs `_v2`, and the `load_model`/`set_session_changed`/`update_display` FP_FEM-vs-Forward_Problem_Solution trio.
- A documented public API surface, plus the `EEG.dipfit.*` interop contract.
- Fix #29 (`Distributed_Source_Localization` cannot launch standalone).

## Constraints

- **Preserve the science.** The warping math and SCS/SBL solvers are the crown jewels; refactor around them, never rewrite them casually.
- Every GUI change is grounded by the headless regression anchors plus a launch smoke test. **GUI correctness confirmation is the owner's**, via Codex + computer use; a launch test alone must never be reported as "the GUI works".
- No new GUIDE GUIs.

## Success criteria

- All 9 pipeline steps have a headless entry point.
- No GUI embeds pipeline logic; each delegates to its `nft_*` twin.
- Full regression suite stays green and bit-for-bit throughout.
- Every GUI launches, returns a valid handle, and closes cleanly under `matlab -batch`.
