# Epic 6: SCALE integration

Tracking issue: [#36](https://github.com/neuromechanist/NFT/issues/36)

Part of program #1. Depends on **E1**, **E2**, **E3**.

## Goal

SCALE becomes a first-class distributed-source method alongside SCS, completing the headline pair named in the project charter.

## Measured starting point (2026-07-16)

- SCALE is **not in this repo**. `SCS` and `SBL` are implemented; SCALE is not.
- `vendor/from-hallu-2018/scale_codes/` exists on the owner's local disk but **`vendor/` is gitignored** — it is untracked local scratch, not part of the repository, and carries no README or provenance. It cannot be credited toward this epic.
- Source exists in the archive (`scale_codes`) and as a private repo `sccn/SCALE`.
- SCALE wraps SCS plus conductivity estimation, so it depends on a trustworthy SCS — which the DSL regression anchor now provides.

## Scope

- Confirm SCALE source, license, and which copy is authoritative (archive `scale_codes` vs private `sccn/SCALE`).
- Import with provenance and attribution.
- Wire in as an inverse method alongside SCS/SBL, reachable from both the scriptable API and the GUI.
- Regression-test against a reference output.

## Constraints

- Preserve the algorithm exactly; this is an integration epic, not a rewrite.
- Do not expose internal cluster paths in any public repo.

## Success criteria

- SCALE runs from the scriptable API and reproduces a reference within tolerance.
- Provenance and licensing are recorded like any other imported source.
