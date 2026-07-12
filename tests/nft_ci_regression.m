function nft_ci_regression()
%NFT_CI_REGRESSION Real-data regression gate for the self-hosted CI runner.
%
%   Runs the full NFT test suite and errors (so `matlab -batch` exits non-zero and
%   the CI job fails) if any test fails OR if the DSL inverse regression was skipped
%   -- on a fixture-provisioned runner it must actually RUN, not skip. Kept as a
%   versioned .m file so the CI step is a single-line `matlab -batch` call rather
%   than a multi-line shell-quoted command.

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

  r = nft_run_tests;
  failed = sum([r.Failed]);
  isDsl  = contains({r.Name}, 'DslInverseRegressionTest');
  dslInc = sum([r(isDsl).Incomplete]);
  fprintf('CI regression: %d passed, %d failed, DSL incomplete=%d\n', ...
      sum([r.Passed]), failed, dslInc);
  if failed > 0
      error('NFT:ci:failed', '%d regression test(s) failed.', failed);
  end
  if dslInc > 0
      error('NFT:ci:dslSkipped', ...
          'DSL regression skipped -- fixtures not found at NFT_DSL_DIR (%s).', ...
          getenv('NFT_DSL_DIR'));
  end
end
