# Warping baseline fixture provenance

- Generated: 2026-07-11 09:37:29
- MATLAB: 25.2.0.3055257 (R2025b) Update 2
- Platform: MACA64 (arch maca64)
- NFT commit: 071fb8c
- Input: /Users/yahya/Documents/git/eeg/phase0-baseline/../NFT_test/jop3.elp (subject jc, session s1, 4 layers, BEM)
- Sensors: 177 x 3
- BEM nodes: 18772 (layers: [4 37543 18772 3])
- Binaries: BEM path via nft_get_config (Intel .osx under Rosetta 2 on Apple Silicon; tetgen.osx native arm64)
- Reproducibility (measured): transform, warped sensors, and BEM mesh reproduce
  exactly across runs on this machine (max delta 0.0); the warp transform matches
  the 2023 committed baseline to 5.7e-14. WarpingSmokeTest compares with tolerances
  that only absorb potential cross-platform / MATLAB-version floating-point drift.
- Historical cross-check: PASSED (max rel err 4.654e-16 vs committed jc_s1_warping.mat)
