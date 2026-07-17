# Epic 4: Code health

Tracking issue: [#34](https://github.com/neuromechanist/NFT/issues/34)

Part of program #1. Test-gated on **E3**.

## Goal

Bring the MATLAB source to a maintainable, consistent standard — the cleanup that is real but not on the critical path, and that must never be done without a regression anchor underneath it.

## Measured starting point (2026-07-16)

The old plan marked much of this done. An evidence-based audit says otherwise:

- **A3 documentation:** overstated. 9 files got H1/Inputs/Outputs headers, not the ~35 claimed. **42 of 116** top-level `.m` files still lack an `Inputs:` section, including `Segmentation.m`, `Forward_Problem_Solution.m`, `Distributed_Source_Localization.m`, `Mesh_generation.m`, `Warping_mesh.m`, `Coregistration.m`.
- **A4 idioms:** ~40% done. `isstr`->`ischar` fully done (0 left); `eval`->`feval` done; the unknown-solver fall-through fixed. But **`findstr`->`strfind` never started** (16 occurrences remain in live code) and **`exist(x)` qualification never started** (dozens remain, including `eegplugin_nft.m:39,45`).
- **A5 config/path hygiene:** partial. `computer('arch')` dispatch landed. But binary exist/executable guards were **never added** (no caller checks a binary before invoking it); `'/'`->`filesep` **not done** (`Forward_Problem_Solution.m:99`, `Segmentation.m:968`, `nft_source_space_generation.m:58`); the magic conductivity constants (0.33/0.0132/1.79) are still hardcoded across 6 live files with no shared config.
- **A6 rename:** not started (unblocked now that fixtures exist).
- **A7 long files:** not started. `Segmentation.m` 1207 lines, `Forward_Problem_Solution.m` 1151 lines.
- **A8 style:** genuinely done (`.editorconfig`, `.gitattributes`, 0 CRLF files).

## Scope

- Finish A3 (the 42 undocumented files), A4 (`findstr`, `exist`), A5 (guards, `filesep`, shared conductivity config).
- A6: rename cryptic identifiers — **one file at a time, each verified against its regression output**. This is NOT a global find-replace: in MATLAB a rename can change behavior via `save`/`load` (variable names persist in `.mat`), `eval`/`evalin`/`assignin`/`inputname`, GUIDE `handles.*` fields, and struct field names.
- A7: split long/mixed-concern files (largely subsumed by E2's GUI-to-thin-wrapper work).

## Constraints

- Every change is verified against the regression anchors. No cleanup without grounding.
- Binary guards must produce an actionable error, never a silent no-op.

## Success criteria

- Every callable entry point has EEGLAB-style help.
- No deprecated idioms remain in live code.
- No hardcoded machine paths or separators; conductivity constants come from one place.
- Every binary call is guarded.
