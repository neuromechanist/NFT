function make_dsl_baseline()
%MAKE_DSL_BASELINE Freeze the distributed-source-localization regression baseline.
%
%   Runs the NFT inverse solver (SCS and SBL) on the cortical demo fixture and
%   writes a compact digest of each estimate to
%   tests/fixtures/dsl_baseline/reference.mat, plus a PROVENANCE.md.
%
%   RE-BASELINE NOTE. This baseline is the current deterministic output of the
%   surviving SCS variant (patchz2, called directly on the raw leadfield -- the
%   only SCS core that still exists in source) and of the SBL path after fixing
%   its undefined-`ss` normalization bug. It is NOT the historical 2023
%   cortex_source_scs.mat: that file was produced by a compact SCS variant whose
%   core (patchz5/z6/d1) is lost, and no selection over the surviving solver's
%   iterates reproduces it (the solver's iterate trajectory itself is verified
%   bit-identical to the 2023 run's saved Jit.mat). The reference is therefore
%   re-created from scratch here, per the owner decision to canonicalize the
%   reproducible surviving pipeline. See PROVENANCE.md and .context/research.md.
%
%   Requires the fixture (env var NFT_DSL_DIR pointing at the cortical demo dir).
%   Run headless, e.g.:
%     NFT_DSL_DIR=/path/to/NFTplugin_demo_cortical \
%       matlab -batch "addpath('tests'); addpath('tests/baseline'); make_dsl_baseline"
%
% Author: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026
%
% Copyright (C) 2026 Seyed Yahya Shirazi, SCCN, INC, UCSD, shirazi@ieee.org
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  env = nft_test_env();
  assert(env.hasDsl, ['DSL fixture not found. Set NFT_DSL_DIR to the cortical demo ' ...
      'directory (holding s1_LFM.mat, ss_g10.mat, ss_g6.mat, ss_g3.mat, ' ...
      'FSss_cor.mat, Node_area.mat, jc_s1.sensors, Amica_comps_nft_sh.set).']);

  comps = 1:11;
  scratchRoot = fullfile(tempdir, sprintf('nft_dsl_baseline_%d', feature('getpid')));
  if exist(scratchRoot, 'dir') == 7      % never inherit a prior/aborted run's outputs
      rmdir(scratchRoot, 's');
  end
  cleaner = onCleanup(@() rmIfExists(scratchRoot));

  fprintf('Running SCS (selection 3) on %d components...\n', numel(comps));
  scsOut = run_dsl(env, fullfile(scratchRoot, 'scs'), 3, comps);
  fprintf('  SCS solver: %.1f s\n', scsOut.dur);
  assert(all(isfinite(scsOut.sourceJ(:))), 'NFT:test:nonFiniteBaseline', ...
      'SCS baseline run produced non-finite output; refusing to freeze a broken baseline.');

  fprintf('Running SBL (selection 2) on %d components...\n', numel(comps));
  sblOut = run_dsl(env, fullfile(scratchRoot, 'sbl'), 2, comps);
  fprintf('  SBL solver: %.1f s\n', sblOut.dur);
  assert(all(isfinite(sblOut.sourceJ(:))), 'NFT:test:nonFiniteBaseline', ...
      'SBL baseline run produced non-finite output; refusing to freeze a broken baseline.');

  % Determinism check across ALL components: the regression test relies on the
  % solvers being reproducible, so verify (not assume) it here before freezing.
  fprintf('Verifying solver determinism (full rerun)...\n');
  scsDet = run_dsl(env, fullfile(scratchRoot, 'scs2'), 3, comps);
  sblDet = run_dsl(env, fullfile(scratchRoot, 'sbl2'), 2, comps);
  scsDelta = max(abs(scsOut.sourceJ(:) - scsDet.sourceJ(:)));
  sblDelta = max(abs(sblOut.sourceJ(:) - sblDet.sourceJ(:)));
  fprintf('  SCS max|delta| = %.3g ; SBL max|delta| = %.3g\n', scsDelta, sblDelta);
  assert(scsDelta == 0, 'SCS solver is not bit-reproducible; baseline would be unstable.');
  assert(sblDelta == 0, 'SBL solver is not bit-reproducible; baseline would be unstable.');

  % Measure how well the fixed SBL reproduces the legacy SBL reference (a
  % cross-check that the shared inputs are correct). Reported in provenance.
  sblRefCorr = sblReferenceCorr(env, sblOut.sourceJ, comps);

  scs = dsl_digest(scsOut.sourceJ);
  sbl = dsl_digest(sblOut.sourceJ);
  meta = struct( ...
      'comps',        comps, ...
      'nVoxel',       size(scsOut.sourceJ, 1), ...
      'matlab',       version(), ...
      'arch',         computer('arch'), ...
      'gitSha',       localGitSha(env.repoRoot), ...
      'scsFval',      scsOut.fvalJ, ...
      'sblFval',      sblOut.fvalJ, ...
      'sblRefCorr',   sblRefCorr);

  outDir = fullfile(env.repoRoot, 'tests', 'fixtures', 'dsl_baseline');
  if exist(outDir, 'dir') ~= 7
      mkdir(outDir);
  end
  save(fullfile(outDir, 'reference.mat'), 'scs', 'sbl', 'meta', '-v7');
  writeProvenance(fullfile(outDir, 'PROVENANCE.md'), meta, scsOut, sblOut);
  fprintf('Wrote %s\n', fullfile(outDir, 'reference.mat'));
end

function s = sblReferenceCorr(env, sourceJ, comps)
% Per-component correlation of the fixed SBL output with the legacy
% cortex_source_sbl.mat reference; returns [] if the reference is absent.
  refFile = fullfile(env.dslDir, 'cortex_source_sbl.mat');
  if exist(refFile, 'file') ~= 2
      s = [];
      return
  end
  R = load(refFile);
  n = numel(comps);
  cvec = zeros(1, n);
  for k = 1:n
      cc = corrcoef(sourceJ(:, k), R.sourceJ(:, comps(k)));
      cvec(k) = cc(1, 2);
  end
  s = struct('perComp', cvec, 'min', min(cvec), 'mean', mean(cvec), 'max', max(cvec));
end

function sha = localGitSha(repoRoot)
  [st, out] = system(sprintf('git -C "%s" rev-parse HEAD', repoRoot));
  if st == 0
      sha = strtrim(out);
  else
      warning('NFT:test:gitShaUnavailable', ...
          'git rev-parse HEAD failed (status %d): %s', st, strtrim(out));
      sha = 'unknown';
  end
end

function writeProvenance(path, meta, scsOut, sblOut)
  fid = fopen(path, 'w');
  if fid == -1
      error('NFT:test:provenanceWriteFailed', 'Could not open %s for writing.', path);
  end
  c = onCleanup(@() fclose(fid));
  fprintf(fid, '# DSL regression baseline provenance\n\n');
  fprintf(fid, '- Generated by `tests/baseline/make_dsl_baseline.m`\n');
  fprintf(fid, '- MATLAB: %s\n', meta.matlab);
  fprintf(fid, '- Arch: %s\n', meta.arch);
  fprintf(fid, '- NFT git SHA: %s\n', meta.gitSha);
  fprintf(fid, '- Components: %s; voxels: %d\n', mat2str(meta.comps), meta.nVoxel);
  fprintf(fid, '- SCS solver time: %.1f s; SBL solver time: %.1f s\n', scsOut.dur, sblOut.dur);
  if ~isempty(meta.sblRefCorr)
      fprintf(fid, '- SBL vs legacy cortex_source_sbl.mat: per-component corr %.2f-%.2f (mean %.2f)\n', ...
          meta.sblRefCorr.min, meta.sblRefCorr.max, meta.sblRefCorr.mean);
  end
  fprintf(fid, '\n## What this baseline is\n\n');
  fprintf(fid, ['This is a **re-baseline** of the distributed-source-localization inverse\n' ...
      'solvers to their current *deterministic* output, per the owner decision.\n\n']);
  fprintf(fid, ['- **SCS**: the surviving `patchz2` core called directly on the raw\n' ...
      '  leadfield. Its iterate trajectory is verified bit-identical to the 2023\n' ...
      '  reference run (`Jit.mat`), so the solver is preserved; only the final compact\n' ...
      '  source extraction of the lost 2023 variant (patchz5/z6/d1 core, no longer in\n' ...
      '  source anywhere) is not reproduced. This baseline freezes the reproducible\n' ...
      '  surviving pipeline instead.\n']);
  fprintf(fid, ['- **SBL**: the multi-resolution path after fixing the undefined-`ss`\n' ...
      '  normalization bug. With inputs shared with SCS, it reproduces the 2023\n' ...
      '  `cortex_source_sbl.mat` closely (see the correlation range above), which\n' ...
      '  cross-validates that the leadfield, kernels, electrode matching, and\n' ...
      '  component set are correct.\n\n']);
  fprintf(fid, '## Caveat: SCS iterate selection is a discrete argmax\n\n');
  fprintf(fid, ['SCS picks `sourceJ = Jit(:,maxcomiter)` via an argmax over per-iterate\n' ...
      'compactness scores. Same-platform this is bit-reproducible (verified: delta 0\n' ...
      'across a full rerun of all components). Across platforms/MATLAB versions a\n' ...
      'near-tie in the compactness curve could flip the selected iterate, jumping to a\n' ...
      'materially different column -- so a future cross-platform failure of the exact\n' ...
      '`peakMatch` assertion may be a selection flip, not a solver regression.\n\n']);
  fprintf(fid, 'The digest stores, per component: peak voxel id/value, L2 norm,\n');
  fprintf(fid, 'count of voxels above 5%% of peak, and the top-200 voxels (idx+val).\n');
end

function rmIfExists(d)
  if exist(d, 'dir') == 7
      rmdir(d, 's');
  end
end
