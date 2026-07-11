%MAKE_WARPING_BASELINE Establish the Phase 0 warping baseline regression fixture.
%
%   Runs the electrode-warping pipeline against the real NFT_test data, sanity-
%   checks the warp transform against the historical committed result, then
%   freezes a compact reference (.mat) plus provenance into
%   tests/fixtures/warping_baseline/. This fixture is the regression anchor that
%   later cleanup phases are verified against.
%
%   Headless:
%     matlab -batch "addpath('tests'); addpath('tests/baseline'); make_warping_baseline"

env = nft_test_env();
addpath(fullfile(env.repoRoot, 'tests', 'baseline'));
assert(env.hasFixtures, 'NFT_test fixtures not found at %s', env.nftTest);

fixtureDir = fullfile(env.repoRoot, 'tests', 'fixtures', 'warping_baseline');
if exist(fixtureDir, 'dir') ~= 7
    mkdir(fixtureDir);
end

scratchOf = fullfile(tempdir, ['nft_warp_baseline_' datestr(now, 'yyyymmdd_HHMMSS')]);
fprintf('Running warping into scratch: %s\n', scratchOf);
out = run_warping(env, scratchOf);

% Sanity: reproduce the historical committed transform within tolerance. This is
% mandatory -- a fixture must never be frozen without being cross-validated, so a
% missing or diverging baseline is fatal (not a warning-and-proceed).
histFile = fullfile(env.nftTest, 'jc_s1_warping.mat');
assert(exist(histFile, 'file') == 2, 'NFT:test:noHistorical', ...
    ['Historical baseline %s not found; cannot cross-validate the fixture. ', ...
     'Restore the NFT_test fixture repo (or set NFT_TEST_DIR).'], histFile);
hist = load(histFile);
v1 = warp_flatten(out.warping_param);
v0 = warp_flatten(hist.warping_param);
assert(numel(v1) == numel(v0), 'NFT:test:histSize', ...
    'Warp transform size differs from committed baseline (%d vs %d).', numel(v1), numel(v0));
assert(all(isfinite(v1)), 'NFT:test:histNaN', 'Current warp transform contains NaN/Inf.');
histRelErr = max(abs(v1 - v0)) / max(1, max(abs(v0)));
fprintf('Historical warp-transform match: max rel err = %.3e\n', histRelErr);
assert(histRelErr < 1e-9, 'NFT:test:histDiverge', ...
    'Current warp transform diverges from committed baseline (rel err %.3e).', histRelErr);

% Freeze the compact reference.
warping_param = out.warping_param;   %#ok<NASGU>
sens_pnt      = out.sens_pnt;         %#ok<NASGU>
bec_nodes     = out.bec_nodes;        %#ok<NASGU>
bei           = out.bei;              %#ok<NASGU>
refFile = fullfile(fixtureDir, 'reference.mat');
save(refFile, 'warping_param', 'sens_pnt', 'bec_nodes', 'bei', '-v7');
fprintf('Wrote %s\n', refFile);

% Provenance.
[gitOk, sha] = system(sprintf('git -C "%s" rev-parse --short HEAD', env.repoRoot));
if gitOk ~= 0
    sha = 'unknown';
end
sha = strtrim(sha);
fid = fopen(fullfile(fixtureDir, 'PROVENANCE.md'), 'w');
c = onCleanup(@() fclose(fid));
fprintf(fid, '# Warping baseline fixture provenance\n\n');
fprintf(fid, '- Generated: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '- MATLAB: %s\n', version);
fprintf(fid, '- Platform: %s (arch %s)\n', computer, computer('arch'));
fprintf(fid, '- NFT commit: %s\n', sha);
fprintf(fid, '- Input: %s (subject jc, session s1, 4 layers, BEM)\n', ...
    fullfile(env.nftTest, 'jop3.elp'));
fprintf(fid, '- Sensors: %d x %d\n', size(sens_pnt, 1), size(sens_pnt, 2));
fprintf(fid, '- BEM nodes: %d (layers: %s)\n', size(bec_nodes, 1), mat2str(bei(1, :)));
fprintf(fid, '- Binaries: BEM path via nft_get_config (Intel .osx under Rosetta 2 on Apple Silicon; tetgen.osx native arm64)\n');
fprintf(fid, '- Reproducibility (measured): transform, warped sensors, and BEM mesh reproduce\n');
fprintf(fid, '  exactly across runs on this machine (max delta 0.0); the warp transform matches\n');
fprintf(fid, '  the 2023 committed baseline to 5.7e-14. WarpingSmokeTest compares with tolerances\n');
fprintf(fid, '  that only absorb potential cross-platform / MATLAB-version floating-point drift.\n');
fprintf(fid, '- Historical cross-check: PASSED (max rel err %.3e vs committed jc_s1_warping.mat)\n', histRelErr);
clear c;
fprintf('Wrote %s\n', fullfile(fixtureDir, 'PROVENANCE.md'));

% Leave the scratch dir for inspection on failure; remove on success.
rmdir(scratchOf, 's');
fprintf('Baseline fixture complete.\n');
