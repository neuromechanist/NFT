function results = nft_run_tests()
%NFT_RUN_TESTS Run the NFT test suite and return the results array.
%
%   results = NFT_RUN_TESTS() puts the test folder (and its baseline helpers) on
%   the path and runs every matlab.unittest test directly under tests/. Helper
%   functions and the baseline scripts are not tests and are ignored.
%
%   Named nft_* to avoid collision with the generic run_tests functions shipped
%   by other toolboxes on the MATLAB path.
%
%   Headless, exit-coded:
%     matlab -batch "addpath('tests'); r = nft_run_tests; exit(any([r.Failed]))"

  here = fileparts(mfilename('fullpath'));
  addpath(here);
  addpath(fullfile(here, 'baseline'));

  results = runtests(here, 'IncludeSubfolders', false);
  disp(results);
end
