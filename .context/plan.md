# NFT Production-Readiness Plan

**Goal:** Turn NFT from an unmaintainable legacy MATLAB toolbox into a clean,
reproducible, community/production-ready EEG source-localization platform whose
differentiator is that the head model warps to real electrode positions, with SCS
and SCALE as flagship inverse methods. Preserve the science; fix the engineering.

**Stack:** MATLAB / EEGLAB plugin + compiled BEM/FEM/mesh binaries + FreeSurfer.
**Owner:** Seyed Yahya Shirazi (`neuromechanist/NFT`, upstream `sccn/NFT`).

**Fork/upstream state (2026-07-11):** the owner's earlier Mac/Windows compatibility
fixes (`e0d6af6`, `8ffa090`) are *already merged into upstream* (PR #4); upstream is
only 7 README-only commits ahead, so fork and upstream are **code-identical** today.
All modernization happens here on the fork; merge back to `sccn/NFT` once the whole
pipeline works end-to-end. The merge-back is clean (README-only reconciliation).

**Sequencing (per owner):** clean the code → verify it works → make it robust. One
adjustment grounded in the audit: establish a *baseline run + safety net first*, so
cleanup is verifiable against a frozen reference (you can't safely refactor 25k lines
without a regression anchor). Status markers: `[ ]` pending, `[~]` in progress, `[x]` done.

> Grounded in three code audits (2026-07-11): code hygiene, test/verification
> readiness, and binary/build/CI. Full findings in `.context/research.md` companions.

## What actually works today (audit-verified)

- The **no-MRI warping path runs end-to-end on Apple Silicon in ~35 s** via Rosetta 2
  (`nft_warping_mesh('jc','s1',jop3.elp,4,tmp,0,0)` produced a real 4-layer mesh).
  The `.osx` binaries (`asc`, `bem_matrix`, `procmesh`, `qslim`, `Showmesh`) are Intel
  and run under Rosetta; `tetgen.osx` is already arm64.
- **BEM forward** runs but is slow under Rosetta (8+ min; needs ≥30 min budget).
- The **SCS/SBL inverse is pure MATLAB and portable** — testable against pre-built
  fixtures with no binary/FreeSurfer/config dependency (best portability story).
- **Broken:** FEM path and fresh-FreeSurfer distributed forward generation (see Phase B4).

## Phase 0 — Baseline & safety net (do before touching code)

- [ ] **Establish the baseline run** the audit already proved: script the warping
      pipeline against `../NFT_test` (`jc`/`s1`/`jop3.elp`), freeze its output mesh as
      the first expected fixture (with provenance: MATLAB version + binary used).
- [ ] **Add root `LICENSE` (GPL-2.0-or-later)** — matches every source header; also the
      first step toward resolving the bundled-TetGen AGPL exposure (Phase C1).
- [ ] **Fix the one live bug that blocks the FEM pipeline for everyone:** delete the
      hardcoded `conf.metufem = '/home/zeynep/...'` override at `nft_get_config.m:70-76`
      (the correct cross-platform path is computed at line 62, then overwritten); turn
      the 3 silent `warning()`-after-`system()`-failure sites in `metufem_calcrf.m`/
      `metufem_calcpot.m` into `error()` to match the other 51 call sites.
- [ ] **Add two canary tests now** so all later cleanup is verifiable: a binary
      presence/executable/exit-0 check, and the warping smoke test vs the frozen mesh.

## Phase A — Code quality / hygiene ("good code")

- [ ] **A1 Delete confirmed-dead files** (~17, ~15% of the tree; own commit, revertible):
      `ip_dipolefitting_old.m`, `nft_warping_mesh_old.m`, `nft_warping_mesh2.m`
      (byte-dup), `FP_FEM_model.m` (+`.fig`, name-collides with `FP_FEM`),
      `eeglab_readlocs.m`, `nft_eeglab_dipplot.m`, `mesh2vol.m`,
      `bem_create_spherical_mesh.m`, `bem_plot_mesh.m`, `fem_save_mesh.m`,
      `mesh_generation_single.m`, `utilbem_pot_unbound2.m`, `utilmesh_correct.m`,
      `warping_eloc_to_MNI.m`, `warping_MNI_to_eloc.m`, `metufem_calcpot.m`
      (dead + carries a hardcoded-path bug → delete, don't fix),
      `nft_dsl_source_visualization.m`.
- [ ] **A2 De-duplicate GUI-embedded algorithm copies (highest-leverage correctness fix).**
      Every GUIDE screen embeds a copy-pasted copy of the headless `nft_*` logic. Make
      GUIs *call* the headless function. Start with `Distributed_Source_Localization.m`
      (1847 lines) which embeds full SCS/SBL copies → call `nft_dsl_inverse_problem_solution`;
      then `Warping_mesh.m`→`nft_warping_mesh`, mesh/source-space/forward/inverse GUIs.
      The flagship SCS algorithm currently exists in two independently-editable copies.
- [ ] **A3 Documentation:** add EEGLAB-style H1 + Inputs/Outputs help to the ~35 files
      lacking it (prioritize callable algo files: `ss_cortex_gaus.m`, `nft_*` entry
      points); fix misleading headers (`bem_load_transfer_matrix.m:52` wrong error ID);
      delete the ~33 commented-out dead-code blocks and the "changelog-in-comments".
- [ ] **A4 Modernize deprecated idioms** (mechanical, low-risk): `isstr`→`ischar` (42),
      `findstr`→`strfind` (17), `exist(x)`→`exist(x,'var'|'file')` (23), `eval`→`feval`
      (4 in `segm_inhomogeneity_correction.m`). Handle `==`-on-strings (43) carefully:
      `nft_forward_problem_solution.m:112-127` (`solver=='bem'`) needs an
      `else error('unknown solver')` (currently falls through leaving `mesh`/`vol` undefined).
- [ ] **A5 Config & path hygiene:** rewrite `nft_get_config.m` to dispatch on
      `computer('arch')` (`glnxa64`/`maci64`/`maca64`/`win64`) not `uname`; guard every
      binary with `exist`+executable check and an actionable error (no silent no-op);
      replace hardcoded `'/'` with `filesep` (10 files); extract the magic conductivity
      constants (0.33/0.0132/1.79 in 8 files) into one shared config; fix the path story
      (`eegplugin_nft.m` must add `nft_dipfit/` + `geodesic/`, or excise their callers).
- [ ] **A6 Rename cryptic identifiers to meaningful names (test-gated; depends on
      Phase B fixtures).** This is the one readability task that is *not* behavior-safe
      in MATLAB: a rename can change behavior via `save`/`load` (variable names persist
      in `.mat` files), `eval`/`evalin`/`assignin`/`inputname`, GUIDE `handles.*` fields,
      and struct field names. So it is NOT a global find-replace. Do it one file at a
      time, each change verified against that file's regression output (`cortex_source_scs.mat`,
      `s1_LFM.mat`, `Dipole_soln.mat`). Because of that dependency, run this pass *after*
      Phase B's fixtures exist, or pull the relevant fixture forward per file. (Comments
      and H1/Inputs-Outputs docs are separate and already landed in A3, which is additive
      and behavior-safe.)
- [ ] **A7 Refactor long/mixed-concern files** (highest effort, do after A1-A6 shrink
      the surface): `eeglab_dipplot.m` (806-line fn), `Segmentation.m` (1207),
      `Forward_Problem_Solution.m` (1151); begin the GUIDE→thin-wrapper-over-headless split.
- [ ] **A8 Style normalization** (final commit): LF line endings (36% are CRLF), strip
      trailing whitespace (90 files), tabs→spaces (28 files); add `.editorconfig` + a
      `checkcode`/lint config so it stays clean.

## Phase B — Verify it works (tests + functional fixes)

- [ ] **B1 Test harness:** `matlab.unittest` under `tests/` with a fixture loader
      (`../NFT_test`, `assumeTrue`-skip if absent), tolerance-based comparators, and the
      `assignin('base','EEG',...)` workaround (`nft_inverse_problem_solution` reads `EEG`
      from the base workspace). Tag tests `Fast`/`Slow`/`RequiresExternalFixture`.
- [ ] **B2 First 5 regression tests** against real fixtures + reference outputs:
      1. binary canary (present/executable/exit-0);
      2. warping smoke vs frozen mesh (~35 s);
      3. **SCS cortical** vs `NFTplugin_demo_cortical/cortex_source_scs.mat` (80150×11) —
         call `nft_dsl_inverse_problem_solution` directly on pre-built LFM/patches, skipping
         the broken FreeSurfer step; pure MATLAB, ~1-2 min, highest scientific value;
      4. forward LFM vs `NFTplugin_demo_dipole/s1_LFM.mat` (208×11379; slow, ≥30 min);
      5. dipole fit vs `Dipole_soln.mat` (1×11 struct).
      Use tolerances (RelTol / mm / correlation), not bit-equality (iterative solvers).
- [ ] **B3 CI:** `matlab-actions/run-tests` on a **Linux runner** (native `.64` binaries,
      no Rosetta) — Fast tier (tests 1-3, <2 min) per PR; Slow tier nightly with
      `NFT_DEMO_FIXTURES_DIR` mounted. (Free MATLAB CI licensing for public repos.)
- [ ] **B4 Fix the FEM / distributed-forward blockers** (each behind a test first):
      define `conf.freesurfer`/`conf.showmesh2`/`conf.coordmap` (undefined but read);
      ship the missing `coordmap` binary (absent on all platforms → `metufem_calcpot`
      broken everywhere); provide macOS builds of `quadmesh`/`lin2quad`/`forward`
      (currently Linux-only, so `.osx` paths point at nonexistent files).

## Phase C — Robustness: binaries, builds, cross-platform

- [ ] **C1 Provenance & licensing foundation:** `provenance/binaries.yaml` (one honest
      entry per binary: upstream, version, license, source_location, sha256 — many start
      `owner-archive`/`unrecoverable`, that's the point); `THIRD_PARTY_LICENSES/` with
      verbatim texts; **bundle TetGen source + AGPLv3 text** (currently redistributed with
      neither — a live compliance gap); a CI provenance gate that fails on any
      unattributed binary.
- [ ] **C2 Recover source & rebuild with arm64:** retrieve from `/data/projects/zeynep/Programs`.
      Order: `geodesic` (source already in-repo — first CI proof-of-concept),
      `tetgen` (public upstream, closes AGPL gap), `qslim` (public upstream), then archive
      builds: `bem_matrix`/METU-FP, `asc*`, `Showmesh`, `quadmesh`, `lin2quad`,
      `forward`/`metufem` (PETSc), `coordmap`. Author one `CMakeLists.txt` per tool.
- [ ] **C3 Library replacements where source is lost/awkward:** `OpenMEEG` for BEM (has
      arm64 conda-forge builds — the highest-leverage swap); `iso2mesh` for ASC
      (volume→surface, arm64 mex today); CGAL/MeshFix for `procmesh` (self-intersection
      repair — time-box the "ask Zeynep for source" first); MATLAB Image Processing
      Toolbox for the ~4 `matitk` ITK filters. `procmesh`/`coordmap` are the risk items.
- [ ] **C4 Cross-platform CI matrix** {ubuntu-22.04, macos-13 (Intel), macos-14 (arm64),
      windows}: native tools via CMake; MEX via `matlab-actions/setup-matlab`+`run-command`
      (free on public repos; Octave `mkoctfile` as a license-free smoke lane); PETSc via
      conda-forge (Linux + both macOS); **Windows FEM explicitly descoped for v1**.
      Collect job assembles `bin/<arch>/`, writes `SHA256SUMS`, runs the provenance gate.
- [ ] **C5 Distribution:** GitHub Release assets (not Git-LFS — EEGLAB installs a plain
      zip) + `nft_fetch_binaries.m` (uses `computer('arch')`, SHA256-verifies, `NFT_BIN_DIR`
      override) + a self-contained fat zip (all 4 platforms) for the EEGLAB plugin.
      Stop tracking new binaries in git going forward.

## Phase D — Community / production readiness

- [ ] **D1 EEGLAB packaging:** `nft_version.m` as single source of truth (sync
      `eegplugin_nft.m`'s `vers`, currently hardcoded `'nft2.3'`); release zip named
      `NFT<version>/` (EEGLAB requires `<name><version>`, no separators); `release.yml` on
      `v*` tags; update the SCCN plugin list + a Zenodo DOI per release.
- [ ] **D2 Docs:** `docs/BUILDING.md`; a getting-started that localizes a source in
      <30 min; refresh the stale manual build instructions in `README`/`README.FEM`.
- [ ] **D3 Upstreaming:** coordinate merge back to `sccn/NFT`.
- [ ] **D4 SCALE integration:** wire `sccn/SCALE` in as a first-class inverse method once
      warping + SCS are solid (SCALE wraps SCS + conductivity estimation).

## Success criteria

- [ ] Fresh install runs the dipole/warping pipeline on Apple Silicon with no hand-edits.
- [ ] `Fast` CI tier green on every PR; SCS/SBL/dipole reproduce reference outputs within tolerance.
- [ ] Every shipped binary has provenance + a build-or-replace path; TetGen AGPL compliant.
- [ ] Cross-platform binaries (incl. arm64) built automatically in CI.
- [ ] Installable as a versioned EEGLAB plugin; docs get a user to a localized source fast.

## Risks / open items

- `procmesh` source is undocumented ("contact developers"); `coordmap` binary is missing
  entirely — both may need Zeynep directly or a library replacement.
- METU-FEM (`forward`) is PETSc-dependent → hardest to make portable; keep BEM the default.
- History rewrite to purge ~100 MB of old binary blobs from git is a separate, higher-risk
  decision — not bundled into Phase C5.
- Confirm SCALE source/license for Phase D4.
