# NFT Instructions

Neuroelectromagnetic Forward Modeling Toolbox (NFT) — the SCCN flagship EEG
head-modeling and source-localization platform, distributed as an EEGLAB plugin.
This repo is a fork of `sccn/NFT` (`neuromechanist/NFT`) being transformed into a
clean, reproducible, maintainable product that everything else builds around.

## Project Context

**Purpose:** Turn NFT into a lightweight, maintainable, DIPFIT-compatible source-
localization platform. The scientific methods are sound; the goal is engineering:
make them installable, runnable, and reproducible on modern machines. As the owner
puts it — "there is not much science that needs to be improved, there is science
that needs to be used."

**Differentiator:** NFT warps the **head model to the subject's real electrode
positions** (a 3-D thin-plate-spline deformation of a 4-layer MNI template mesh).
DIPFIT does the opposite — it warps electrodes onto a fixed template head. Real
electrode positions and subject head models cut source-localization error
substantially (Akalin Acar & Makeig 2013; Shirazi & Huang 2019). Preserve this.

**Flagship goals:**
1. A "light NFT" that can replace/complement EEGLAB's template DIPFIT (`../dipfit`),
   populating `EEG.dipfit.*` so DIPFIT's plotting/leadfield tools keep working.
2. Straightforward MRI/fMRI segmentation and custom head-model creation.
3. **SCS** and **SCALE** as the headline distributed source-localization methods.
   (Status: **SCS** and **SBL** are implemented here; **SCALE** is *not in this
   repo yet* and must be brought in — see `.context/research.md`.)
4. Reliable electrode localization from 3D scans so people actually digitize
   electrodes (revive/replace `../get_chanlocs`, `../automated_digitization`).

**Tech stack:** MATLAB (115 top-level `.m` files) + EEGLAB host + GUIDE GUIs +
~13 platform-specific compiled binaries (BEM/FEM/mesh tools). FreeSurfer (external)
for the cortical DSL path. See `.rules/matlab.md`.

## Architecture Map

Pipeline (GUI dashboard `Neuroelectromagnetic_Forward_Modeling_Toolbox.m`; the
command-line equivalent is `test_script.m`):

```
1. Segmentation        Segmentation.m/.fig · segm_*.m            → matitk (ITK)
2. Mesh generation     Mesh_generation.m · nft_mesh_generation.m → asc1, qslim, procmesh, tetgen, quadmesh, lin2quad
3. Source space        Source_space_generation.m · nft_source_space_generation.m  (pure MATLAB)
4. Coregister / Warp   Coregistration.m (MRI) · Warping_mesh.m · nft_warping_mesh.m
                       └─ warping_main_function.m  ← SCIENTIFIC CORE (head model → electrodes)
5a. Forward — BEM      Forward_Problem_Solution.m · nft_forward_problem_solution.m · bem_*.m → bem_matrix
5b. Forward — FEM      FP_FEM.m · nft_fem_forward_problem_solution.m · metufem_*.m → forward / metufem.mex
6. Dipole inverse      Inverse_Problem_Solution.m · nft_inverse_problem_solution.m · ip_dipolefitting.m
7. Distributed (DSL)   Distributed_Source_Localization.m · nft_dsl_*.m
                       ├─ selection==2 → SBL (Wipf sparse Bayesian learning)
                       └─ selection==3 → SCS (Cao 2011, sparse/compact/smooth)
                       needs FreeSurfer recon-all + geodesic mex (source in geodesic/)
```

Interop surface: NFT writes `EEG.dipfit.{hdmfile,mrifile,coordformat,model}` and
keeps state in `EEG.etc.nft.*`. Downstream DIPFIT/EEGLAB tools consume it.

`nft_dipfit/` is a **dead, unsynchronized vendored FieldTrip snapshot** (never on
path, unused except two broken `ft_voltype`/`ft_senstype` calls). Not a feature.

## Known state (verified 2026-07-16 — do not re-litigate these)

> Everything below was **measured**, not inferred. Several long-standing claims in this
> file turned out to be false; they are recorded as CORRECTED rather than deleted, so
> nobody rediscovers them. If you are about to act on a belief about a binary, its
> licence, or its dependencies, check `provenance/binaries.yaml` first — it is the
> single source of truth, and "unknown" is a legitimate recorded value there.

**Fixed — no longer broken (do not re-report):**
- ~~Hardcoded `/home/zeynep/...` FEM path at `nft_get_config.m:70`~~ — removed (Phase 0).
- ~~`metufem_calcpot.m:44` "Fix before release" hack~~ — **the file no longer exists**;
  deleted in A1 as dead (zero callers in the repo's entire history).
- ~~Undefined `conf.freesurfer` / `conf.showmesh2` / `conf.coordmap`~~ — resolved (#21).
  `conf.freesurfer` resolves via `FREESURFER_HOME`/PATH; `showmesh2` was a typo for the
  existing `conf.showmesh`; `coordmap` is dead by removal (see ADR-0004).
- ~~No root `LICENSE`~~ — added (Phase 0).
- ~~Warping logic ×3, DSL logic ×2~~ — de-duplicated (#22, #23, #28).
- ~~`*_old.m`, `eeglab_readlocs.m`, `warping_eloc_to_MNI/MNI_to_eloc` dead files~~ —
  deleted (A1).

**CORRECTED — these claims were WRONG:**
- **"Binary source is lost"** / **"`procmesh`: contact developers"** — **false.** Source
  was located in the SCCN internal archive for essentially every shipped tool.
  `procmesh` already ships a `CMakeLists.txt` and is **zero-dependency, portable C++03**;
  its OpenGL dependency is **dead code** (`LIBS=` commented out, no
  `TARGET_LINK_LIBRARIES`, `mouse.h` never compiled, `__GLUTMOUSE__` never defined,
  `otool -L` links no GL). Same for `asc` (GL lives only in an unshipped `viewtri`
  target). Only **`matitk`** genuinely has no source. See ADR-0005.
- **"`asc` is academic-only, not GPL-compatible"** — **false.** The archive holds the
  superseded **v2.01 (2004)** licence. Upstream **relicensed**: **v2.01a (2009) is
  BSD-3-Clause**, copyright The Chinese University of Hong Kong. *Lesson: a LICENSE file
  in the archive describes the vintage in the archive, not the component's current terms.*
- **"METU-FEM is PETSc-dependent, therefore FEM is hard to port"** — half true. `forward`
  (CLI) is PETSc (3.1-p4, **sequential MPIUNI**, byte-identical to `metu_fem-0.4`), but it
  only runs the one-time reciprocity precompute. **`metufem.mex*` — the repeatedly-called
  hot path — has NO PETSc/MPI** (its own BiCGSTAB solver), so most of FEM is a low-risk
  MEX recompile.

**Still broken:**
- **Platform coverage.** MATLAB does **not** exist on Linux arm64, and R2025b is the final
  Intel-Mac release, so the real targets are **Linux x86_64 + Mac arm64 primary**, Windows
  best-effort, `maci64` legacy. `nft_get_config` dispatches on `computer('arch')` (#13),
  but the binaries don't exist:

  | Target | Segmentation | BEM / warping | FEM |
  |---|---|---|---|
  | Linux x86_64 | works | works | works |
  | **Mac arm64** | **dead** (`matitk` has no `mexmaca64`; MEX cannot use Rosetta) | Rosetta only | **broken** (no `.osx`) |
  | Mac x86_64 (legacy) | works | works (Intel `.osx`) | **broken** (no `.osx`) |
  | Windows (best-effort) | works | partial | broken |

  So the full pipeline runs on **one** target, and the only Mac with a future is worst off.
  Epic 1 (#31) owns this. `mexitk` (BSD-3, separate repo) replaces `matitk` for arm64.
- **Nothing here reproduces what it claims.** `cortex_source_scs.mat` came from a compact
  SCS variant whose source is lost -> re-baselined (#16). `jc_segments.mat` is
  unreproducible because **the GUI never saved the clicked eye coordinates**
  (`parameters.skull` holds only `sli_eyes`/`thr`) -> re-baseline, don't reproduce.
  `nft_segmentation` now records `parameters.skull.eyes`, closing that hole going forward.
- **The pipeline is 6/9 scriptable**, not 7/9: `segm_outer_skull` used to block headless
  runs with `ginput(2)` **inside the compute function** (fixed, #52 — it now takes an
  optional `eyes`), but **Coregistration still has no headless twin**, and **no GUI calls
  its `nft_*` twin** — each embeds its own copy of the pipeline (E2 #32).
- **Live licence gaps:** `quadmesh` / `lin2quad.cc` / `meshutil.*` have **no licence at
  all** and are presumed METU-authored — NFT does not own them; proceeding on a documented
  GPL-2.0 **working assumption** pending a grant (#51). MixKit's `MxTriProject.cxx` and
  `MxMat3/4-jacobi.cxx` (Numerical Recipes) are **non-commercial-only** — the last real use
  restriction in the tree.
- **GUIDE GUIs (×9)** are deprecated by MathWorks.

## Real data & references

- **Test fixtures:** `../NFT_test` — real T1 MRI, 258-ch `.elp`, legacy + FreeSurfer
  segmentations of subject `jc`, BEM meshes, source space, warp transforms.
- **Reference demo runs:** `/Volumes/S1/git/NFTplugin_demo_dipole` (1.8 GB, dipole)
  and `/Volumes/S1/git/NFTplugin_demo_cortical` (3.7 GB, distributed — contains
  `cortex_source_scs.mat`, `cortex_source_sbl.mat` reference outputs). Read-only
  reference; do not modify.
- **Literature:** `docs/references/` — PDFs + `nft-references.bib` for NFT (2010),
  SCS (Cao 2012), SCALE (2016), forward-model errors (2013), Shirazi & Huang (2019).
- **Owner also has** a full source archive ("whole code for every part") and a
  Zeynep tutorial PDF — location TBD; ask before assuming a binary is unrecoverable.

## Platform & Build (owner directive)

- **Apple Silicon is a first-class target.** NFT must be serviceable on Mac
  (arm64/`maca64`), so the **full arm64 stack gets built**, not routed around: the
  geodesic MEX first (source in `geodesic/`), then the other compiled tools as their
  source/build is recovered. This is a goal, not a nice-to-have.
- **Linux-dependent steps run on an SCCN Linux host (`ssh hallu`).** Anything that
  needs FreeSurfer, the current Linux binaries, or a CI-like Linux run (e.g. the
  forward DSL path, Phase B CI) is tested there until the Mac stack is complete.
- **Installing:** on **Mac, install directly as needed** (including `sudo`/`brew`) —
  pre-authorized. On **hallu, `sudo` is blocked** — ask the owner before any install
  or elevation there.

## Development Workflow

1. **Check context:** `.context/epics/README.md` — the **live roadmap** (6 capability
   epics under program #1; E1 binary foundation is active). `.context/research.md`
   (findings), `.context/ideas.md` (design), `.context/scratch_history.md` (dead ends).
   `.context/plan.md` is **PAUSED/superseded** — kept for its audit trail, but it
   contains claims now known false; do not plan new work from it.
2. **Branch:** `gh issue develop <issue-number>` (fork `origin`, upstream `sccn/NFT`).
3. **Code:** follow `.rules/matlab.md` — thin GUI over scriptable compute, guard
   every binary, no hardcoded paths, call EEGLAB functions rather than vendoring.
4. **Test with real data only** (no mocks): drive the pipeline end-to-end against
   `../NFT_test`; validate DSL against the `/Volumes/S1` reference outputs. See
   `.rules/testing.md`.
5. **Commit:** atomic, <50 chars, no emojis, no AI attribution.
6. **PR + review:** `gh pr create`, then `/review-pr`; address all real findings.
   Do not merge until CI is green.

## [CRITICAL] Core Principles

- **Preserve the science, fix the engineering.** The warping math and SCS/SBL
  solvers are the crown jewels; refactor around them, don't rewrite them casually.
- **No mocks / real data only** — `.rules/testing.md`.
- **No unattributed binaries** — every shipped binary needs source/version/license
  and a reproducible build. `.context/decisions/` records the strategy.
- **No hardcoded machine paths, no silent binary failures, no new GUIDE GUIs.**
- **DIPFIT is a compatibility contract, not code to copy** — interop via
  `EEG.dipfit.*`, don't fork EEGLAB internals.
- No technical debt carried forward; replace, don't deprecate; no TODO without a
  linked issue.

## [REFERENCE] Rules & Context

Rules (`.rules/`): `matlab.md` (primary), `testing.md`, `git.md`, `code_review.md`,
`documentation.md`, `self_improve.md`, `serena_mcp.md`, `ci_cd.md`, `python.md`
(auxiliary Python tooling only).

Context (`.context/`): `epics/` (**live roadmap**), `research.md`, `ideas.md`,
`scratch_history.md`, `decisions/` (ADRs), `plan.md` (PAUSED/superseded).

---
Preserve the science. Make it reproducible. NFT is the flagship; everything else
orbits it.
