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

## Known-broken (fix before/around any refactor)

Details and file:line in `.context/research.md`. Highlights:
- **Hardcoded dev paths:** `nft_get_config.m:70` overwrites the portable FEM path
  with `/home/zeynep/Programs/metu_fem-0.4/forward`; `metufem_calcpot.m:44` has a
  self-admitted "Fix before release" hack. Remove these.
- **Undefined config fields:** `conf.freesurfer`, `conf.showmesh2`, `conf.coordmap`
  are used but never defined → the DSL/FEM paths error out of the box.
- **Apple Silicon:** binary wrappers dispatch on `uname -p` and only handle
  Linux-x86_64/i686 and Intel Mac; no arm64 binaries except a rebuilt `tetgen.osx`.
  On Apple Silicon most binaries silently fail. Use `uname -m` and handle arm64.
- **Binary provenance:** only `geodesic/` has in-repo source; `tetgen` is buildable
  upstream; asc/qslim/bem_matrix/procmesh/Showmesh/metufem/matitk have **no source**
  (procmesh: "contact developers"). No `LICENSE` file though code is GPL v2+.
- **Duplication/dead code:** warping logic exists ×3, DSL logic ×2; `*_old.m`,
  `eeglab_readlocs.m`, `asc2/4/8`, `warping_eloc_to_MNI/MNI_to_eloc` are dead.
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

## Development Workflow

1. **Check context:** `.context/plan.md` (tasks/phases), `.context/research.md`
   (findings), `.context/ideas.md` (design), `.context/scratch_history.md` (dead ends).
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

Context (`.context/`): `plan.md`, `research.md`, `ideas.md`, `scratch_history.md`,
`decisions/` (ADRs).

---
Preserve the science. Make it reproducible. NFT is the flagship; everything else
orbits it.
