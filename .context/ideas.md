# NFT Design Ideas

High-level vision and design decisions behind the modernization, before they harden
into ADRs (`.context/decisions/`). Concrete tasks live in `plan.md`; findings in
`research.md`.

## Vision

NFT should be the tool people reach for when they want *accurate* EEG source
localization — because it uses the subject's real head and real electrode positions
instead of a generic template. Everything else in the EEG-localization ecosystem
(DIPFIT, electrode digitization tools) should orbit NFT as the flagship. The science
is already published and validated; the work is making it installable, reproducible,
and pleasant to use.

**Guiding principles:**
- Preserve the science, fix the engineering. Refactor around the warping math and
  SCS/SBL/SCALE solvers; never casually rewrite them.
- Reproducibility is the product. A method nobody can install is a method nobody uses.
- Meet users where they are: an EEGLAB plugin that speaks DIPFIT's data structures.
- Headless-first. Every capability scriptable; GUI is an optional thin layer.

## The core design inversion (vs DIPFIT)

DIPFIT keeps a fixed template head and **moves the electrodes** onto it (rigid /
rescale / nonlinear warps of electrode coordinates). NFT keeps the electrodes fixed
and **deforms the head model** (a 4-layer MNI template mesh) onto them via a 3-D
thin-plate-spline RBF warp (`warping_main_function.m`). This is the scientific value:
the geometry the forward model sees actually matches where the sensors are. The
modernization must expose this inversion as the headline feature, and still write
results back into `EEG.dipfit.*` so DIPFIT's plotting/leadfield tools keep working.

## System shape (target)

- **Compute core (headless):** segmentation → mesh → warp → forward (BEM/FEM) →
  inverse (dipole / SCS / SBL / SCALE). Pure functions, real-data testable.
- **Interop layer:** read/write `EEG.dipfit.*` + `EEG.etc.nft.*`; import electrode
  files (`readlocs`) and 3D-scan digitizations.
- **Binary/runtime layer:** a single, guarded config that locates or builds every
  native tool per platform, with honest errors — never a silent no-op.
- **GUI layer:** thin, eventually App Designer or web; not on the critical path.

## Key trade-offs being weighed

- **Light vs full NFT.** A BEM-only "light" path (no FEM, no full segmentation) is
  the fastest route to a DIPFIT replacement; FEM/segmentation stay as the "full" path.
  Pro: shippable soon, small binary surface. Con: two code paths to maintain.
- **Rebuild vs replace binaries.** Rebuild from upstream where source exists
  (tetgen, geodesic); replace closed tools with maintained libraries (ITK/OpenMEEG/
  iso2mesh) where the closed source is gone (procmesh, METU-FP/FEM). Pro: kills the
  provenance debt. Con: replacements must reproduce the reference outputs.
- **Vendored FieldTrip (`nft_dipfit/`).** It's dead today. Either delete it, or
  deliberately adopt FieldTrip's forward/inverse API as the interop path. Leaning
  delete unless a concrete need appears.

## Feature ideas

- **One-command quickstart:** electrodes in → warped subject head model + localized
  sources out, no MRI required. This is the demo that sells the tool.
- **Provenance manifest:** a machine-readable record of every binary's source,
  version, license, and build recipe, checked in CI.
- **Electrode-localization on-ramp:** make 3D-scan digitization easy enough that
  using real electrode positions becomes the default, not the exception.
- **Reproducible demos:** turn the `/Volumes/S1` demo runs into small, documented,
  runnable examples with expected outputs.

## Non-goals (for now)

- Inventing new source-localization math (the science is done; use it).
- Backward-compatibility shims for ancient EEGLAB/DIPFIT folder names (fix forward).
- A polished GUI before the headless core is solid.
