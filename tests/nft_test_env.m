function env = nft_test_env()
%NFT_TEST_ENV Resolve and set up paths for the NFT test suite (portable).
%
%   env = NFT_TEST_ENV() puts the NFT repository and EEGLAB on the MATLAB path
%   (only if they are not already there) and returns a struct describing the
%   test environment. All locations are overridable by environment variable so
%   the suite runs unchanged on a developer machine or a CI runner.
%
%   Fields:
%     repoRoot    - NFT repository root (this file lives in <repoRoot>/tests)
%     nftTest     - real-data fixture directory holding the inputs. Resolved from
%                   the NFT_TEST_DIR environment variable, else <repoRoot>/../NFT_test
%     eeglab      - EEGLAB root that was added to the path ('' if already present)
%     hasFixtures - true when nftTest exists on disk
%
%   The regression inputs (MRI, jop3.elp, ...) live in nftTest; the frozen
%   expected outputs live in <repoRoot>/tests/fixtures. Tests gate on hasFixtures
%   so they skip cleanly when the (large, unversioned) fixture repo is absent.

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
      eeglabRoot = getenv('EEGLAB_DIR');
      if isempty(eeglabRoot)
          eeglabRoot = fullfile(repoRoot, '..', 'eeglab');
      end
      if exist(fullfile(eeglabRoot, 'eeglab.m'), 'file') == 2
          addpath(eeglabRoot);
          try
              evalc('eeglab nogui');   % set up EEGLAB subpaths without a GUI
          catch
              addpath(genpath(fullfile(eeglabRoot, 'functions')));
          end
      end
  end

  % Put THIS repo on the front of the path, unconditionally and last, so the
  % checkout under test always wins over any other NFT copy on the saved MATLAB
  % path and remains resolvable after tests change the current folder. (A merely
  % conditional addpath is fooled when the repo happens to be the current folder.)
  addpath(repoRoot);

  env = struct( ...
      'repoRoot',    repoRoot, ...
      'nftTest',     nftTest, ...
      'eeglab',      eeglabRoot, ...
      'hasFixtures', exist(nftTest, 'dir') == 7);
end
