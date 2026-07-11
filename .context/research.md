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
  (Later slides cover mesh generation, warping, forward BEM/FEM, dipole, and the
  cortical/DSL path — read those sections when working the relevant pipeline stage.)

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
