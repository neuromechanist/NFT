# NFT Epics

Program tracking issue: [#1](https://github.com/neuromechanist/NFT/issues/1)

This directory is the **live roadmap**, replacing the flat phase plan in
[`../plan.md`](../plan.md) (now PAUSED, kept for its audit trail).

## Why the restructure (2026-07-16)

The old plan was organized by *activity* — clean, then verify, then robustify.
Two measured findings broke that model:

1. **The binaries gate everything.** NFT runs its full pipeline on **one** supported
   target (Linux x86_64). On Mac arm64 — the only Mac from R2026a on — segmentation is
   dead, FEM is broken, and the rest runs only under Rosetta. No MATLAB-side cleanup
   moves any of that, yet binaries sat in Phase C, third.
2. **The binary source is not lost.** The old Phase C was scoped around
   `asc`/`qslim`/`bem_matrix`/`procmesh`/`Showmesh`/`metufem` having no recoverable
   source, with `procmesh` requiring "contact developers". Source was located for
   essentially every shipped tool, and `procmesh` already ships a CMakeLists.txt.
   So the strategy is **rebuild, not replace**, which also preserves the exact
   algorithms — the project's stated priority.

The epics below are therefore organized by *capability*, each one deliverable and
verifiable on its own, with honest dependencies.

## The epics

| Epic | Goal | Depends on |
|---|---|---|
| [E1 Reproducible binary foundation](epic-1-binary-foundation.md) ([#31](https://github.com/neuromechanist/NFT/issues/31)) | Every binary builds from in-tree source via CMake on Linux x86_64 + Mac arm64; Windows best-effort | — (except P8, see below) |
| [E2 Scriptable-first core](epic-2-scriptable-core.md) ([#32](https://github.com/neuromechanist/NFT/issues/32)) | All 9 pipeline steps scriptable; GUIs become thin wrappers over `nft_*` | — |
| [E3 Verification and cross-platform proof](epic-3-verification.md) ([#33](https://github.com/neuromechanist/NFT/issues/33)) | Tests that cannot pass by accident, green on every claimed target | E1, E2 |
| [E4 Code health](epic-4-code-health.md) ([#34](https://github.com/neuromechanist/NFT/issues/34)) | Docs, idioms, guards, renames, long-file splits | E3 (test-gated) |
| [E5 Packaging and release](epic-5-packaging-release.md) ([#35](https://github.com/neuromechanist/NFT/issues/35)) | Versioned EEGLAB plugin, docs, upstream merge | E1, E2, E3 |
| [E6 SCALE integration](epic-6-scale.md) ([#36](https://github.com/neuromechanist/NFT/issues/36)) | SCALE as a first-class inverse method | E1, E2, E3 |

Dependency shape: E1 and E2 are *mostly* parallel (C/C++ vs MATLAB, disjoint files),
and both feed **E3**, which gates E4, E5 and E6. **One exception, found 2026-07-16:**
E1 Phase 8 (matitk/Apple-Silicon, [#45](https://github.com/neuromechanist/NFT/issues/45))
is blocked on E2's `nft_segmentation.m` and an E3 segmentation baseline — you cannot
verify a matitk rebuild without a reference, and segmentation has neither a headless
entry point nor a test today. So `nft_segmentation.m` should be taken early in E2.

## Supported targets (CORRECTED 2026-07-16)

The stated North Star ("Linux and Mac, x86_64 and arm64") is not achievable as written:
MATLAB does not exist on Linux arm64, and R2025b is the last Intel-Mac release.

| Target | Verdict |
|---|---|
| Linux x86_64 (`glnxa64`) | **primary** |
| Mac arm64 (`maca64`) | **primary** — the only Mac from R2026a on |
| Windows x86_64 (`win64`) | best-effort, never a blocker |
| Mac x86_64 (`maci64`) | legacy/sunsetting |
| Linux arm64 | **impossible — no MATLAB** |

Today the full pipeline runs on **one** of these, and Mac arm64 — the Mac with a
future — is the worst off: segmentation dead (`matitk`), FEM broken (no `.osx`),
everything else Rosetta-only.

## Current state

**E1 is the active epic.** Phases:

| Phase | Issue | Status |
|---|---|---|
| 1 Archive survey and provenance manifest | [#37](https://github.com/neuromechanist/NFT/issues/37) | active |
| 2 Licensing foundation and provenance gate | [#38](https://github.com/neuromechanist/NFT/issues/38) | pending |
| 3 Import and CMake the dependency-light tools | [#39](https://github.com/neuromechanist/NFT/issues/39) | pending |
| 4 Build the OpenGL-dependent tools headless | [#40](https://github.com/neuromechanist/NFT/issues/40) | pending |
| 5 METU-FEM (PETSc) and FEM on Mac | [#41](https://github.com/neuromechanist/NFT/issues/41) | pending |
| 6 Cross-platform CI build matrix | [#42](https://github.com/neuromechanist/NFT/issues/42) | pending |
| 7 Runtime dispatch, guards, and distribution | [#43](https://github.com/neuromechanist/NFT/issues/43) | pending |
| 8 Rebuild matitk against ITK for Apple Silicon | [#45](https://github.com/neuromechanist/NFT/issues/45) | blocked on E2 + E3 |

## Superseded

Old phase epics closed with pointers to where their remaining work went; their
merged PRs keep their history and credit.

| Old | Absorbed by |
|---|---|
| #2 Phase 0 Baseline | complete — nothing carried forward |
| #6 Phase A Code quality | E2 (#32) + E4 (#34) |
| #3 Phase B Verify | E3 (#33) |
| #4 Phase C Robustness | E1 (#31) |
| #5 Phase D Community | E5 (#35) + E6 (#36) |

## Standing principles

- **Preserve the science, fix the engineering.** The warping math and SCS/SBL
  solvers are the crown jewels; refactor around them, don't rewrite them casually.
- **Measure, don't assume.** Two roadmap premises turned out false (source
  unrecoverable; `metu_fem` dependency-free). Claims need evidence.
- **No mocks / real data only.** Every change is grounded against the regression
  anchors.
- **GUI correctness is confirmed by the owner** (Codex + computer use). A launch
  smoke test proves a GUI *opens*, never that it *works*.
