# NFT Modernization Plan

**Goal:** Transform NFT from an unmaintainable, binary-opaque MATLAB toolbox into a
clean, reproducible, DIPFIT-compatible flagship for EEG source localization — where
the head model warps to real electrode positions and SCS/SCALE are the headline
inverse methods. This is a software/reproducibility effort: preserve the science,
fix the engineering.

**Stack:** MATLAB / EEGLAB plugin + compiled BEM/FEM/mesh binaries + FreeSurfer.
**Owner:** Seyed Yahya Shirazi (`neuromechanist/NFT`, upstream `sccn/NFT`).

Status markers: `[ ]` pending, `[~]` in progress, `[x]` complete.

## Phase 0 — Make it run on a modern machine (stabilize)
Get the *existing* shipped pipeline working on Apple Silicon macOS without hand-patching.
- [ ] Remove hardcoded dev paths: `nft_get_config.m:70-76` (the `/home/zeynep/...`
      FEM override) and `metufem_calcpot.m:44-46` ("Fix before release" hack).
- [ ] Define the missing config fields (`conf.freesurfer`, `conf.showmesh2`,
      `conf.coordmap`) with autodetection + clear errors when absent.
- [ ] Rewrite `nft_get_config.m` path/arch detection: use `fileparts`, `uname -m`,
      handle `arm64`; every binary path guarded (exists + executable) with an
      actionable error instead of silent failure.
- [ ] Fix the plugin path story: `eegplugin_nft.m` must add whatever subfolders the
      pipeline needs (or excise the `nft_dipfit/` `ft_voltype`/`ft_senstype` calls).
- [ ] Smoke-test the dipole pipeline end-to-end against `../NFT_test` on this machine;
      log failures in `.context/scratch_history.md`.

## Phase 1 — Reproducibility & binary provenance
The central maintainability blocker (see ADR 0003).
- [ ] Add a top-level `LICENSE` (GPL v2+, matching source headers) and per-binary
      provenance records (upstream, version, license, build recipe).
- [ ] Catalog each binary: rebuild from upstream (tetgen, geodesic already have
      source), replace with a maintained library (ITK/OpenMEEG/iso2mesh), or flag as
      unrecoverable (procmesh, METU-FP/FEM — needs the owner's source archive).
- [ ] Provide arm64-native builds (or documented Rosetta fallback) for every binary
      the light pipeline needs.
- [ ] Stand up CI (GitHub Actions, MATLAB) that at least lints and runs a headless
      smoke test; see `.rules/ci_cd.md`.
- [ ] Decide binary hosting: keep ~150 MB in git, move to releases/LFS, or fetch on
      install. (ADR candidate.)

## Phase 2 — The "light NFT" DIPFIT-compatible core
A minimal, scriptable path: subject electrodes → warped head model → forward → localize.
- [ ] Extract the warping science (`warping_main_function.m`) into a single clean,
      headless function; delete the ×3 duplication (`nft_warping_mesh.m`,
      `nft_warping_mesh2.m`, inline `Warping_mesh.m`).
- [ ] Define and document the DIPFIT interop contract: populate
      `EEG.dipfit.{hdmfile,mrifile,coordformat,coord_transform,chanfile}` +
      `EEG.etc.nft.*`; fix the stale `dipfit2.2` paths (ADR 0002).
- [ ] Verify DIPFIT downstream tools (`pop_dipplot`, `pop_leadfield`,
      `pop_multifit`) work on an NFT-built model.
- [ ] Ship a "no-MRI, warp-template-to-electrodes" quickstart as the headline UX.

## Phase 3 — Segmentation & custom head models
- [ ] Make MRI/fMRI segmentation straightforward; document the FreeSurfer path
      (the validated one per `../NFT_test` history) and the legacy path.
- [ ] Replace the closed `matitk` ITK bridge dependency where feasible with a
      maintained/rebuildable backend.
- [ ] One-command custom head-model creation from a subject MRI.

## Phase 4 — Flagship inverse methods: SCS + SCALE
- [ ] Harden SCS (`selection==3`) and SBL (`selection==2`); de-duplicate the DSL code
      (currently in `nft_dsl_*.m` and inline in `Distributed_Source_Localization.m`).
- [ ] **Bring SCALE into the repo** (Akalin Acar et al. 2016 — not present today);
      get the algorithm/source from the owner and integrate as a first-class method.
- [ ] Validate SCS/SBL/SCALE against the reference outputs in
      `/Volumes/S1/git/NFTplugin_demo_cortical` (`cortex_source_scs.mat`, `_sbl.mat`).

## Phase 5 — Electrode localization from 3D scans
- [ ] Revive the working parts of `../get_chanlocs` (fiducial align + template
      electrode mapping) with a portable, mex-free geometry backend; drop the
      `../automated_digitization` dead ends. Study Brainstorm's approach.
- [ ] Output directly in DIPFIT-compatible `chanlocs`; wire into the NFT warp path.
- [ ] Lower the barrier so digitizing electrodes is the easy default.

## Phase 6 — Cleanup, docs, release
- [ ] Delete confirmed-dead code (`*_old.m`, `eeglab_readlocs.m`, `asc2/4/8`, orphan
      warping utils); modernize `isstr`→`ischar`, `==`→`strcmp`.
- [ ] Plan the GUIDE → App Designer (or headless-first) GUI migration.
- [ ] Docs that get a user to a localized source in <30 min (`.rules/documentation.md`).
- [ ] Tag a release; coordinate upstreaming to `sccn/NFT`.

## Success Criteria
- [ ] Fresh-install NFT runs the dipole pipeline on Apple Silicon with no hand-editing.
- [ ] Every shipped binary has recorded provenance + a build/replace path.
- [ ] An NFT head model drops into DIPFIT and its tools work unchanged.
- [ ] SCS, SBL, and SCALE reproduce the reference demo outputs.
- [ ] A 3D-scan → electrodes → localized source path exists and is documented.

## Notes / open decisions
- Scope of "light" NFT: BEM-only path first, FEM optional? (lean BEM-first)
- Binary hosting strategy (git vs releases vs fetch-on-install).
- Get the owner's full source archive + Zeynep tutorial to resolve provenance.
- Confirm SCALE source availability and license.
