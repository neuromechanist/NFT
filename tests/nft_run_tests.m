function results = nft_run_tests()
%NFT_RUN_TESTS Run the NFT test suite and return the results array.
%
%   results = NFT_RUN_TESTS() puts the test folder (and its baseline helpers) on
%   the path, runs every matlab.unittest test directly under tests/, and prints a
%   summary that distinguishes passed / failed / skipped so a silently-skipped
%   safety net (missing fixtures, binaries, or EEGLAB) can never be mistaken for a
%   green run. Helper functions and the baseline scripts are not tests and are
%   ignored. Named nft_* to avoid collision with generic run_tests functions on
%   the MATLAB path.
%
%   Headless exit codes:
%     % lenient (skips allowed -- bare runner without fixtures):
%     matlab -batch "addpath('tests'); r = nft_run_tests; exit(any([r.Failed]))"
%     % strict (skips are failures -- CI runner that provisions fixtures/EEGLAB):
%     matlab -batch "addpath('tests'); r = nft_run_tests; exit(any([r.Failed]|[r.Incomplete]))"
%   (An NFT_CI_STRICT env-var gate is planned with the CI workflow in Phase B3.)

  here = fileparts(mfilename('fullpath'));
  addpath(here);
  addpath(fullfile(here, 'baseline'));

  results = runtests(here, 'IncludeSubfolders', false);

  nPass = sum([results.Passed]);
  nFail = sum([results.Failed]);
  nInc  = sum([results.Incomplete]);
  fprintf('\nNFT test summary: %d passed, %d failed, %d skipped/incomplete\n', ...
      nPass, nFail, nInc);
  if nInc > 0
      inc = results([results.Incomplete]);
      fprintf('  SKIPPED (did NOT run -- check environment):\n');
      for i = 1:numel(inc)
          fprintf('    - %s\n', inc(i).Name);
      end
      warning('NFT:test:incomplete', ...
          '%d test(s) were skipped, not run. In CI that provisions fixtures, treat skips as failures.', nInc);
  end
end
