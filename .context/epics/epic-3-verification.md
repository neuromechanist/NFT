# Epic 3: Verification and cross-platform proof

Tracking issue: [#33](https://github.com/neuromechanist/NFT/issues/33)

Part of program #1. Depends on **E1** (binaries) for the cross-platform lanes.

## Goal

Prove NFT works — on every target we claim, with tests that cannot pass by accident.

## Measured starting point (2026-07-16)

- 11 tests: binary canary (2), warping smoke (5), DSL inverse regression (4).
- Real anchors that work: warping smoke reproduces a frozen baseline through a real ~36 s end-to-end warp; the DSL regression reproduces SCS/SBL bit-for-bit.
- CI: **Linux x86_64 only** — `ci.yml` (ubuntu-latest, no fixtures, so everything fixture-gated skips) and `regression-hallu.yml` (self-hosted Linux, real fixtures).

## Known problems

- **Silent skips (#30).** Without `NFT_DSL_DIR` the suite prints "7 passed, 0 failed, 0 skipped" and looks green; the real run is 11 passed. The 4 skipped tests are the crown-jewel SCS/SBL anchor. A skip that reads as a pass is exactly the failure the anchor exists to prevent.
- **Missing regressions.** The plan's tests 4 and 5 (forward LFM vs `s1_LFM.mat`; dipole fit vs `Dipole_soln.mat`) were never written.
- **The SCS baseline is self-referential.** Per #16 the historical `cortex_source_scs.mat` was produced by a compact SCS variant whose source is lost and unreproducible, so the baseline was re-created from the current pipeline's own output. It is a determinism check, not validation against the historical reference. The old plan text claims otherwise and is wrong.
- **GUIs are untested** beyond ad-hoc launching.
- **Nothing is tested off Linux x86_64**, which is why everything looks green while FEM is broken on every Mac.

## Scope

- Fail loudly when fixtures are absent, with an explicit opt-out (#30). Both CI lanes must then opt out *visibly* rather than tolerating skips implicitly.
- Add the forward-LFM and dipole-fit regressions.
- GUI launch smoke tests in CI (each GUI opens, returns a valid handle, closes).
- Cross-platform regression matrix over the four primary targets (+ Windows best-effort), consuming E1's binaries.
- A fixture staging strategy (`NFT_test` is not on hallu today, which is why 5 warping tests skip there).
- Correct the test-tier taxonomy: only one test file uses `TestTags` today, so the documented Fast/Slow/RequiresExternalFixture scheme is aspirational.

## Success criteria

- A run without fixtures exits non-zero and names exactly what is missing.
- The suite runs green on all four primary targets with real fixtures.
- No test can pass by skipping.
- Every claim in the plan about what a test validates is true.
