function env = nft_test_env()
%NFT_TEST_ENV Resolve and set up paths for the NFT test suite (portable).
%
%   env = NFT_TEST_ENV() puts the NFT repository, its test helpers, and EEGLAB on
%   the MATLAB path and returns a struct describing the test environment. All
%   locations are overridable by environment variable so the suite runs unchanged
%   on a developer machine or a CI runner.
%
%   Fields:
%     repoRoot    - NFT repository root (this file lives in <repoRoot>/tests)
%     nftTest     - real-data fixture directory holding the inputs. Resolved from
%                   the NFT_TEST_DIR environment variable, else <repoRoot>/../NFT_test
%     eeglab      - EEGLAB root that was actually added to the path ('' if EEGLAB
%                   was already available or could not be located)
%     hasEeglab   - true when readlocs (and thus EEGLAB) is resolvable after setup
%     hasFixtures - true when the primary input (jop3.elp) exists under nftTest
%     segMriFile  - path stub (no extension) to the segmentation MRI fixture,
%                   fullfile(nftTest, 'Subj_mri'); segm_readanalyze()/
%                   nft_segmentation() accept a stub or a '.hdr' path
%     hasSegFixture - true when both Subj_mri.hdr and Subj_mri.img exist under
%                   nftTest
%     dslDir      - distributed-source-localization (cortical) fixture directory
%                   holding the precomputed inverse inputs (s1_LFM.mat, ss_g10.mat,
%                   FSss_cor.mat, Node_area.mat, jc_s1.sensors, the .set). Resolved
%                   ONLY from the NFT_DSL_DIR environment variable -- it is a large
%                   read-only reference dataset with no portable in-tree location,
%                   so there is deliberately no machine-path default.
%     hasDsl      - true when dslDir holds the SCS/SBL inverse inputs
%
%   The regression inputs (MRI, jop3.elp, ...) live in nftTest; the frozen
%   expected outputs live in <repoRoot>/tests/fixtures. Tests gate on hasFixtures
%   and hasEeglab so they skip cleanly (never hard-error) when those inputs are
%   absent, e.g. on a bare CI checkout without a sibling NFT_test/EEGLAB.
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

  thisDir  = fileparts(mfilename('fullpath'));
  repoRoot = fileparts(thisDir);

  % Real-data fixtures (inputs).
  nftTest = getenv('NFT_TEST_DIR');
  if isempty(nftTest)
      nftTest = fullfile(repoRoot, '..', 'NFT_test');
  end

  % EEGLAB (readlocs and friends). Skip entirely if already available.
  eeglabRoot = '';
  if isempty(which('readlocs'))
      candidate = getenv('EEGLAB_DIR');
      if isempty(candidate)
          candidate = fullfile(repoRoot, '..', 'eeglab');
      end
      if exist(fullfile(candidate, 'eeglab.m'), 'file') == 2
          addpath(candidate);
          try
              evalc('eeglab nogui');   % set up EEGLAB subpaths without a GUI
          catch err
              % Do not hide the failure: report it, then fall back to a
              % best-effort path setup (weaker than eeglab nogui).
              warning('NFT:test:eeglabSetup', ...
                  'eeglab nogui failed (%s); falling back to addpath(genpath(functions)).', ...
                  err.message);
              addpath(genpath(fullfile(candidate, 'functions')));
          end
          eeglabRoot = candidate;   % record only the root we actually added
      end
  end

  % Put THIS repo and its test helpers on the front of the path, unconditionally
  % and last, so the checkout under test always wins over any other NFT copy on
  % the saved MATLAB path and stays resolvable after tests change the current
  % folder. (A merely conditional addpath is fooled when the repo happens to be
  % the current folder; run_warping lives in tests/baseline, so add it too or a
  % direct runtests('WarpingSmokeTest') would error on an undefined function.)
  addpath(repoRoot);
  addpath(thisDir);                        % tests/
  addpath(fullfile(thisDir, 'baseline'));  % tests/baseline (run_warping)

  % Distributed source localization (cortical) fixture. Large, read-only, and
  % machine-specific (e.g. the reference demo run) -- resolved only from an env
  % var so the suite never depends on a hardcoded absolute path and skips cleanly
  % when the dataset is not mounted.
  dslDir = getenv('NFT_DSL_DIR');
  % The full set both solvers need: SCS uses ss_g10; SBL additionally uses the
  % ss_g6/ss_g3 multi-resolution kernels. Gate on all of them so a partial
  % fixture skips cleanly instead of crashing mid-run inside the SBL path.
  dslInputs = {'s1_LFM.mat', 'ss_g10.mat', 'ss_g6.mat', 'ss_g3.mat', ...
      'FSss_cor.mat', 'Node_area.mat', 'jc_s1.sensors', 'Amica_comps_nft_sh.set'};
  hasDsl = ~isempty(dslDir);
  for kInput = 1:numel(dslInputs)
      hasDsl = hasDsl && exist(fullfile(dslDir, dslInputs{kInput}), 'file') == 2;
  end

  segMriFile = fullfile(nftTest, 'Subj_mri');
  hasSegFixture = exist([segMriFile '.hdr'], 'file') == 2 && ...
      exist([segMriFile '.img'], 'file') == 2;

  env = struct( ...
      'repoRoot',    repoRoot, ...
      'nftTest',     nftTest, ...
      'eeglab',      eeglabRoot, ...
      'hasEeglab',   ~isempty(which('readlocs')), ...
      'hasFixtures', exist(fullfile(nftTest, 'jop3.elp'), 'file') == 2, ...
      'segMriFile',    segMriFile, ...
      'hasSegFixture', hasSegFixture, ...
      'dslDir',      dslDir, ...
      'hasDsl',      hasDsl);
end
