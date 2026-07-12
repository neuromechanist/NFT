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
%   Symlinks avoid copying the ~230 MB of leadfield/kernel inputs; if the
%   platform refuses a symlink the file is copied instead.
%
%   Returned struct fields:
%     sourceJ - estimated cortical source [n_voxel x numel(comps)]
%     fvalJ   - per-component normalized residual variance
%     dur     - wall-clock seconds for the solver call

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
      if exist(dst, 'file') == 2 || exist(dst, 'file') == 7
          delete(dst);
      end
      [st, ~] = system(sprintf('ln -s "%s" "%s"', src, dst));
      if st ~= 0
          copyfile(src, dst);   % fallback where symlinks are unavailable
      end
  end

  S = load(fullfile(env.dslDir, 'Amica_comps_nft_sh.set'), '-mat');
  EEG = S.EEG;

  t0 = tic;
  nft_dsl_inverse_problem_solution('jc', 's1', scratchOf, EEG, comps, selection, ...
      fullfile(scratchOf, 'jc_s1.sensors'));
  dur = toc(t0);

  if selection == 3
      m = load(fullfile(scratchOf, 'cortex_source_scs.mat'));
  else
      m = load(fullfile(scratchOf, 'cortex_source_sbl.mat'));
  end
  out = struct('sourceJ', m.sourceJ, 'fvalJ', m.fvalJ, 'dur', dur);
end
