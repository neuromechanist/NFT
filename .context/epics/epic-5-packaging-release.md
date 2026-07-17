# Epic 5: Packaging and release

Tracking issue: [#35](https://github.com/neuromechanist/NFT/issues/35)

Part of program #1. Depends on **E1**, **E2**, **E3**.

## Goal

NFT installs as a versioned EEGLAB plugin, on every supported platform, and a newcomer can localize a source quickly.

## Measured starting point (2026-07-16)

Nothing here has started:

- No `nft_version.m`; `eegplugin_nft.m:32` hardcodes `vers = 'nft2.3'`.
- No `release.yml`, no release automation, no Zenodo DOI.
- `docs/` contains only `references/` (literature). No `BUILDING.md`, no getting-started guide.
- Upstream `sccn/NFT` is configured as a remote but no merge-back exists. Fork and upstream were code-identical as of 2026-07-11 and the reconciliation is README-only, so the merge-back is expected to be clean.

## Scope

- `nft_version.m` as the single source of truth; sync `eegplugin_nft.m`.
- Release zip named `NFT<version>/` (EEGLAB requires `<name><version>`, no separators).
- `release.yml` on `v*` tags, assembling the multi-platform binaries from E1.
- Distribution: GitHub Release assets (not Git-LFS — EEGLAB installs a plain zip), plus a self-contained fat zip covering all supported platforms.
- `docs/BUILDING.md` (per-platform, pinned toolchains) and a getting-started that localizes a source in under 30 minutes.
- Refresh the stale manual build instructions in `README` / `README.FEM`.
- Update the SCCN plugin list; mint a Zenodo DOI per release.
- Coordinate merge back to `sccn/NFT`.

## Open question

History rewrite to purge ~100 MB of old binary blobs from git is a separate, higher-risk decision. It is deliberately NOT bundled here.

## Success criteria

- A fresh EEGLAB install runs the dipole/warping pipeline on Apple Silicon with no hand-edits.
- Version is defined in exactly one place.
- Docs get a new user to a localized source fast.
