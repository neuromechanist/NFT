function out = run_dsl(env, scratchOf, selection, comps)
%RUN_DSL Run the NFT distributed-source-localization inverse solver on the fixture.
%
%   out = RUN_DSL(env, scratchOf, selection, comps) runs
%   nft_dsl_inverse_problem_solution for the cortical demo fixture (env.dslDir)
%   into the fresh scratch directory scratchOf and returns the estimated source.
%
%     selection = 2 -> SBL (needs ss_g6/ss_g3 in addition)
%     selection = 3 -> SCS
%     comps         -> vector of independent-component indices (e.g. 1:11)
%
%   The solver cd's into its output directory and writes cortex_source_*.mat
%   there, so RUN_DSL never runs inside env.dslDir (that reference set is
%   read-only): it symlinks the large inputs into scratchOf and runs there.
%   Symlinks avoid copying the inputs (SCS needs ~234 MB, SBL ~283 MB; the
%   ~42 MB .set is read directly from env.dslDir, not symlinked); if the platform
%   refuses a symlink the file is copied instead. Every staged path is verified to
%   resolve, because `ln -s` succeeds even when the source is missing -- so a
%   typo'd NFT_DSL_DIR or partial fixture fails here with a clear message rather
%   than as an opaque file-not-found deep inside the solver.
%
%   Returned struct fields:
%     sourceJ - estimated cortical source [n_voxel x numel(comps)]
%     fvalJ   - per-component normalized residual variance
%     dur     - wall-clock seconds for the solver call
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

  if exist(scratchOf, 'dir') ~= 7
      mkdir(scratchOf);
  end

  need = {'s1_LFM.mat', 'ss_g10.mat', 'FSss_cor.mat', 'Node_area.mat', 'jc_s1.sensors'};
  if selection == 2
      need = [need, {'ss_g6.mat', 'ss_g3.mat'}];
  end
  for k = 1:numel(need)
      src = fullfile(env.dslDir, need{k});
      dst = fullfile(scratchOf, need{k});
      if exist(src, 'file') ~= 2
          error('NFT:test:missingFixtureInput', ...
              'DSL fixture input not found: %s (check NFT_DSL_DIR).', src);
      end
      if exist(dst, 'file') == 2 || exist(dst, 'file') == 7
          delete(dst);
      end
      system(sprintf('ln -s "%s" "%s"', src, dst));
      if exist(dst, 'file') ~= 2
          copyfile(src, dst);   % fallback where symlinks are unavailable
      end
      if exist(dst, 'file') ~= 2
          error('NFT:test:stageFailed', 'Failed to stage %s into %s.', src, dst);
      end
  end

  % Never read a previous run's output: the solver writes cortex_source_*.mat with
  % a fixed name, so a stale file from a reused scratch dir would otherwise be
  % loaded silently if the solver died before saving.
  if selection == 3
      outName = 'cortex_source_scs.mat';
  else
      outName = 'cortex_source_sbl.mat';
  end
  outFile = fullfile(scratchOf, outName);
  if exist(outFile, 'file') == 2
      delete(outFile);
  end

  S = load(fullfile(env.dslDir, 'Amica_comps_nft_sh.set'), '-mat');
  EEG = S.EEG;

  t0 = tic;
  nft_dsl_inverse_problem_solution('jc', 's1', scratchOf, EEG, comps, selection, ...
      fullfile(scratchOf, 'jc_s1.sensors'));
  dur = toc(t0);

  if exist(outFile, 'file') ~= 2
      error('NFT:test:noSolverOutput', ...
          'Solver did not produce %s; the run did not complete.', outFile);
  end
  m = load(outFile);
  out = struct('sourceJ', m.sourceJ, 'fvalJ', m.fvalJ, 'dur', dur);
end
