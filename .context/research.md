# NFT Research Notes

Findings that inform the modernization. Kept current as investigation proceeds.
Companion literature lives in `docs/references/` (PDFs + `nft-references.bib`).

## Where NFT sits in the ecosystem

NFT is the SCCN forward/inverse head-modeling toolbox: it segments an MRI,
builds a realistic subject BEM/FEM head model, warps a template mesh to the
subject's electrode positions, solves the forward problem, and localizes
sources. The flagship goal is to make NFT a lightweight, maintainable,
DIPFIT-compatible source-localization platform whose differentiator is that the
**head model deforms to real electrode positions**, with **SCS** and **SCALE**
as the headline inverse methods.

Sibling repositories in `../` (surveyed 2026-07-11):

| Repo | Role | State |
|------|------|-------|
| `dipfit` | EEGLAB DIPFIT plugin - the integration/compatibility target | Actively maintained (v5.6, 2025) |
| `get_chanlocs` | Electrode localization from 3D head scans (EEGLAB plugin) | Broken on Apple Silicon (missing mex, disabled MATLAB fallback, GUIDE GUIs) |
| `automated_digitization` | Fully-automated electrode detection from scans | Abandoned prototype; SURF + CNN paths never worked |
| `eLocs` | Predecessor digitization toolbox (mocap probe + 3D scan) | Unmaintained since 2022; Fieldtrip 2018 pin |
| `NFT_test` | Real-data test fixtures (MRI, meshes, 258-ch electrodes, FreeSurfer subject) | Working fixture set (2023) |

## The four flagship references (and two supporting)

Primary (see `docs/references/README.md` for the full table):

1. **NFT** - Akalin Acar & Makeig 2010, J. Neurosci. Methods. The toolbox paper.
2. **SCS** - Cao, Akalin Acar, Kreutz-Delgado & Makeig 2012, IEEE EMBC. Sparse,
   Compact, and Smooth distributed source localization. Flagship inverse #1.
3. **SCALE** - Akalin Acar, Acar & Makeig 2016, NeuroImage. Simultaneous
   Conductivity And source Location Estimation. Flagship inverse #2.
4. **Forward-model errors** - Akalin Acar & Makeig 2013, Brain Topography. Why
   accurate electrode positions and head models matter.
5. **Shirazi & Huang 2019**, Front. Neurosci. Electrode digitization accuracy vs
   source estimation uncertainty. Motivates the 3D-scan electrode goal.

Supporting PDFs copied from the owner's Paperpile (BibTeX TBD):
- Akalin Acar et al. 2016 - *High-resolution EEG source imaging of one-year-old
  children* (the infant-study SCS context).
- Akalin Acar & Makeig 2020 - *Improved cortical source localization of
  ICA-derived EEG components using a source scalp projection noise model*.

## DIPFIT is the compatibility contract, not the code to imitate

DIPFIT warps **electrodes onto** a template head model. NFT intentionally
inverts this: it warps the **head model to the electrodes**. To interoperate,
NFT should still populate DIPFIT's data structure so DIPFIT's downstream
visualization/leadfield tools keep working:

- `EEG.dipfit.{hdmfile, mrifile, chanfile, coordformat, coord_transform, chansel}`
- `coordformat` in `{'MNI','Spherical','Custom'}`; NFT models are subject-`Custom`.
- DIPFIT's warp lives in `eeglab/functions/sigprocfunc/coregister.m` +
  `dipfit/electroderealign.m` (methods: rigidbody, globalrescale, traditional,
  nonlin1-5, realignfiducial).
- `test_script.m` already sets `EEG.dipfit.model = EEG.etc.nft.model`, so partial
  interop exists today.
- Downstream DIPFIT functions to keep working: `pop_dipplot`, `pop_leadfield`,
  `pop_dipfit_loreta`, `pop_multifit`.

## The binary-provenance problem (central maintainability blocker)

NFT ships ~150 MB of precompiled third-party binaries with **no in-repo source**
(except `geodesic/`, the mesh geodesic C++ library). Platform dispatch is done by
POSIX wrapper scripts (`asc1`, `asc2/4/8`, `qslim`, `bem_matrix`, `procmesh`,
`Showmesh`) that `exec` a `.64`/`.32`/`.osx` sibling:

```sh
case "${OS}-${ARCH}" in            # OS=`uname -s`  ARCH=`uname -p`
  ( "Linux-x86_64" ) exec $0.64 ;;
  ( "Linux-i686"  ) exec $0.32 ;;
  ( "Darwin-i386" ) exec $0.osx ;;  # Intel Mac ONLY
esac
```

Concrete breakages:
- **Apple Silicon (arm64) is unhandled** - `uname -p` returns `arm`, no case
  matches, the wrapper exits 0 doing nothing (silent failure). No arm64 binaries
  exist; `.osx` builds are Intel x86 (need Rosetta or recompilation).
- `uname -p` is unreliable on Linux too (often `unknown`; arch is `uname -m`).
- `nft_get_config.m` **hardcodes** `conf.metufem = '/home/zeynep/Programs/metu_fem-0.4/forward'`,
  overriding autodetection - a dead absolute path from the original author's machine.

Binary origins per `README` (all open-source upstreams, licenses to be restored):
ASC (adaptive skeleton climbing), QSLIM (quadric mesh simplification), BEM_MATRIX
(METU-FP toolkit), PROCMESH (mesh correction - "contact developers for source"),
MATITK (MATLAB + ITK), plus TETGEN and the METU-FEM `forward` solver (PetSc-based).

Licensing: no `LICENSE` file at repo root, but source headers (e.g.
`nft_get_config.m`) declare **GPL v2-or-later**, (c) Zeynep Akalin Acar, SCCN.

> **Zeynep's source archive (SCCN cluster) — return here often.** Her full working
> tree (the source for most of NFT's opaque binaries + the algorithm code) lives on
> the SCCN cluster. Because her home root is permission-locked, a durable copy is
> kept at `/data/projects/zeynep/Programs` (backed up so it survives home cleanup).
> Highlights relevant to NFT:
> - **FEM solver source:** `metu_fem-0.1` … `metu_fem-0.7` (the `forward` binary).
> - **BEM/mesh source:** `bem`, `fem`, `fem_util`, `Quadmesh`, `geodesic`,
>   `Showmesh.2/.3/.4`, `openskull`, `segmentation` — resolves the binary provenance.
> - **Algorithm code:** `scale_codes` (SCALE → now `sccn/SCALE`), `SourceLoc`,
>   `FS_sourceloc` (compactness/DSL), `NFT-1.0`, `NFT-ani`.

### Zeynep's NFT tutorial (authoritative workflow reference)

In the `../NFT_test` repo: **`NFT_demo2021.pdf`** (EEGLAB workshop, June 2021, 106
slides) and **`NFT_presentation18.pdf`** (2018). These are the definitive
step-by-step walkthroughs — consult per stage. Key facts confirmed from the 2021 deck:

- **Positioning vs DIPFIT:** DIPFIT uses a fixed 3-layer MNI model (~3000 vertices)
  with precomputed forward matrices (fast). NFT generates a **subject-specific** model
  and does the forward solve (more accurate). Confirms ADR 0001/0002.
- **Two entry paths:** "From an MRI" (Image Segmentation → Mesh Generation → Source
  Space → Electrode Co-Registration) and "From electrode position data" (Template
  Warping). Then Source Localization (Dipole Fitting / Distributed).
- **MR prep via FreeSurfer** (exact commands): `mri_convert -i brain.nii -ot analyze
  -o test1.img`; `mri_nu_correct.mni --i test1.img --o t1c.img --n 2`; `mri_convert -i
  t1c.img --conform_size 1 --out_orientation PSR -ot analyze -o test2.img`.
- **Segmentation:** 4 tissues (scalp, skull, CSF, brain) via curvature-anisotropic
  filtering + Otsu multi-threshold + region growing + watershed + morphology (matitk/ITK).
- Demo subject is **`jc` / session `s1`** in `NFTplugin_demo_dipole` — the same
  subject as the `../NFT_test` fixtures and the `/Volumes/S1/git` reference runs.
- Demo data also hosted at `rdl-share.ucsd.edu`; contact `zeynep@sccn.ucsd.edu`.
  (Full 106-slide walkthrough mined below for warping + SCS.)

## Warping + SCS: the core of the new source localization

The owner's target workflow is the **no-MRI path**: warp a template head model to
the subject's real electrodes, then localize with SCS. Both are scriptable (headless).

### Head-model-to-electrodes warping (the DIPFIT-replacement path)

Scriptable API (from the tutorial's "NFT Matlab Scripts" slides):

```matlab
% BEM path (last arg 0 = BEM):
nft_warping_mesh(subject_name, session_name, elec_file, nl, of, 0, 0);
nft_forward_problem_solution(subject_name, session_name, of);
dip1 = nft_inverse_problem_solution(subject_name, session_name, of, EEG, comp_index, plotting, elec_file);

% FEM path (last arg 1 = FEM):
nft_warping_mesh(subject_name, session_name, elec_file, nl, of, 0, 1);
nft_fem_forward_problem_solution(subject_name, session_name, of);
```

`nft_warping_mesh` deforms the 4-layer MNI template (`Warping_MNIdata4L.mat`) onto
the subject electrodes via a 3-D thin-plate-spline RBF warp (`warping_main_function.m`;
see the warping section above), applying the same warp to all mesh layers and the
source-space grid, then repairing self-intersections with `procmesh`. No MRI needed —
just an electrode file whose first three channels are the fiducials. This is the
lightweight DIPFIT replacement.

### SCS distributed (cortical) source localization

Pipeline (tutorial "Distributed Source Localization" / "NIST" section; NIST is the
cortical-imaging module):

1. **Cortical source space:** load FreeSurfer cortical surface → downsample to
   **80,000 vertices** → co-register to the NFT brain surface → regenerate the NFT
   head model → per-vertex normals + node areas → save `<subj>FS_ss.dip` + `Node_area`.
2. **Multi-resolution patches:** Gaussian cortical patches at **3 / 6 / 10 mm** radius
   (the "3,6,10 mm" option → `Generate patches`) form the SCS dictionary.
3. **Forward:** BEM or FEM lead-field matrix over the ~80k-dipole cortical space
   (FEM mesh `<subj>FS.1.msh`, tetgen from the BEM boundaries, METU-FEM solver).
4. **Inverse:** GUI dropdown **"Sparse compact and smooth (SCS) method"** (also SBL).
   In code this is `nft_dsl_inverse_problem_solution` (`selection==3` SCS / `==2` SBL).
5. **Output:** `cortex_source_scs` and/or `cortex_source_sbl` (the exact files in the
   `/Volumes/S1/git/NFTplugin_demo_cortical` reference run).
6. **Visualization:** `Showmesh` on the cortical `.smf` + potential distribution.

Conductivities used in the demo: scalp 0.33, skull **0.0132**, CSF 1.79, brain 0.33
S/m; Isolated Problem Approach (IPA) for BEM. FEM requires tetgen + METU-FEM
(PETSc-built) per `README.FEM`.

### Phase B reconciliation of the SCS/SBL inverse (2026-07-11)

Grounding the SCS/SBL inverse against the demo reference (`cortex_source_scs.mat`,
`cortex_source_sbl.mat`) established:

- **The SCS solver is correct.** The demo dir's `Jit.mat` (the 2023 run's full
  26-iterate trajectory for one component) is **bit-identical** (corr 1.0000, diffs at
  float-storage precision) to the repo's current `patchz2` core called directly on the
  raw leadfield. The Cao 2012 EMBC paper (`docs/references/pdf/SCS_*`) confirms the
  algorithm matches the code.
- **The 2023 `cortex_source_scs.mat` is not reproducible from surviving code.** It is
  denser-but-more-peaked than any patchz2 iterate and localizes 50-109 mm from the
  repo's most-compact-iterate selection; no selection over the iterates (tested to
  `max_it=40`) reaches it. The archive's SCS wrappers reference four cores (patchz2 /
  patchz5 / patchz6 / patchz2d1) but only **patchz2** survives anywhere; the compact
  variants that produced the reference are lost, and the owner confirmed they cannot be
  recovered.
- **Decision (owner): re-baseline** to the surviving deterministic pipeline. Frozen in
  `tests/fixtures/dsl_baseline/` and enforced by `DslInverseRegressionTest`. The lost
  2023 reference is documented, not chased.
- **SBL had a real bug:** the patch-normalization loop used `ii = length(ss)` with `ss`
  undefined, crashing headless SBL. Fixed to `length(ss_10)` (both GUI + headless
  copies). Fixed SBL reproduces `cortex_source_sbl.mat` at ~0.73-0.91 per-component
  correlation (mean ~0.83), which **cross-validates the shared inputs** (leadfield,
  kernels, electrode matching, component set) and thereby isolates the SCS gap to
  the lost variant, not the pipeline.
- Both SCS and SBL solvers are **deterministic** (comp-1 rerun delta 0), so the frozen
  digest is a stable regression anchor for the coming GUI/headless de-duplication (A2).

### SCALE sits on top of this

SCALE (now `sccn/SCALE`) wraps this SCS inverse in an outer loop that also estimates
skull conductivity from FEM sensitivity — i.e. warping + SCS are the substrate the
new conductivity-aware source localization builds on.

## Electrode localization: an unsolved gap to re-solve

Motivation is empirical: accurate electrode positions and subject head models
substantially reduce source-localization error (Akalin Acar & Makeig 2013;
Shirazi & Huang 2019). The three prior attempts bracket the design space:
`eLocs` (working reference, unmaintained), `get_chanlocs` (semi-manual, broken by
environment drift), `automated_digitization` (automation attempt that failed).
Brainstorm also ships a working 3D-scan electrode tool worth studying. Pragmatic
path: revive the working parts of `get_chanlocs` (fiducial align + template
electrode mapping) with a portable, mex-free geometry backend, output in
DIPFIT-compatible `chanlocs`.

## Real-data test harness already exists

`../NFT_test` holds one full real case: Analyze T1 MRI, a 258-channel `.elp`
electrode file, legacy **and** FreeSurfer segmentations of the same subject
(`jc` / `jcFS`), BEM boundary meshes, a dipole source space, and electrode-warp
transform artifacts. Its git log records that bypassing FreeSurfer segmentation
failed and the FreeSurfer path is the validated one. This is the end-to-end
regression fixture; no mocks needed (satisfies the no-mocks testing rule).

## Open questions

- Which binaries can be rebuilt from public upstream source vs. must be replaced
  (PROCMESH and the METU-FEM `forward` solver are the provenance risks)?
- Can BEM matrix assembly / mesh ops be replaced by maintained libraries
  (OpenMEEG, iso2mesh, Fieldtrip meshing) to shrink the binary surface?
- Exact scope of the "light" DIPFIT-replacement: minimum pipeline that produces a
  usable subject head model + SCS/SCALE localization without FEM.

<!-- Append new research entries below with date + context. -->
