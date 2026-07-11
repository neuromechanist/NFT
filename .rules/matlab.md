# MATLAB / EEGLAB Development Standards

NFT is a MATLAB toolbox distributed as an **EEGLAB plugin**. These conventions
override the generic Python/JS rules for all `.m` code.

## Language & environment
- **MATLAB** is the implementation language. Target the MATLAB versions EEGLAB
  currently supports; avoid features newer than the oldest supported release.
- **No external MATLAB package manager.** The toolbox is installed by dropping it
  into `eeglab/plugins/`. Keep it self-contained and path-clean.
- **Toolbox dependencies:** minimize. Note every required MathWorks toolbox
  (e.g. Image Processing) explicitly in `AGENTS.md`; do not silently add new ones.
- **EEGLAB is the host,** not a vendored dependency. Call EEGLAB functions
  (`pop_*`, `eeg_*`, `readlocs`, `coregister`) rather than copying them in.

## Plugin conventions
- `eegplugin_nft.m` registers menus and must stay lightweight (version check +
  menu wiring only). Real work lives in `pop_`/`nft_` functions.
- User-facing entry points are `pop_*` (GUI + argument parsing) that call pure
  compute functions (`nft_*`, `bem_*`, `fem_*`, `warping_*`). Keep the GUI layer
  thin and the compute layer scriptable/headless.
- Interop with DIPFIT by populating `EEG.dipfit.*` and storing NFT-specific state
  under `EEG.etc.nft.*`. Never break the `EEG` structure contract.

## Code style
- One function per file, filename == function name (MATLAB requirement).
- Function help block at the top (`% name() - summary`, Inputs/Outputs), matching
  EEGLAB's `help2html` conventions so plugin help renders.
- Prefer explicit variable names over MATLAB's terse historical style; keep new
  code readable even where surrounding legacy code is not.
- Guard platform/binary calls; never assume a binary exists (see below).
- No hardcoded absolute paths. Resolve paths relative to `mfilename('fullpath')`
  or a config function. (The legacy `/home/zeynep/...` path in `nft_get_config.m`
  is exactly the anti-pattern to remove.)

## GUIs
- Legacy GUIs are GUIDE `.fig` + generated `.m`. GUIDE is deprecated in modern
  MATLAB. Do not build new GUIDE GUIs; new UI should be programmatic
  (uifigure/app or plain figure) or, preferably, headless-scriptable functions
  with an optional thin GUI wrapper.

## Native binaries (critical for this repo)
- Binaries are dispatched by `uname`-based shell wrappers and `nft_get_config.m`.
  Any new dispatch **must** handle `arm64` (Apple Silicon) and use `uname -m`,
  not `uname -p`, for architecture.
- Never call a binary without checking it exists and is executable for the
  current platform; fail loudly with an actionable message, never silently.
- Every shipped binary needs recorded provenance: upstream source, version,
  license, and a reproducible build recipe. No unattributed binaries.

## Never do this
- Never hardcode a user- or machine-specific absolute path.
- Never add a GUIDE `.fig` GUI to new code.
- Never assume a platform/binary; guard and error explicitly.
- Never copy an EEGLAB/Fieldtrip function into the repo when you can call it.
- Never leave a binary in the tree without provenance + license.

---
*MATLAB/EEGLAB first. Thin GUI over scriptable compute. Guard every binary.*
