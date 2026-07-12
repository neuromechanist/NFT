function out = run_warping(env, scratchOf)
%RUN_WARPING Run the electrode-warping pipeline into a scratch dir; return outputs.
%
%   out = RUN_WARPING(env, scratchOf) runs nft_warping_mesh for subject 'jc',
%   session 's1', using the 258-channel fiducial file jop3.elp from env.nftTest,
%   writing all intermediate and output files into scratchOf. It returns the
%   defining, comparable outputs of a BEM (femmesh=0) warp:
%
%     warping_param - the thin-plate-spline / RBF warp transform (bit-reproducible)
%     sens_pnt      - warped electrode positions, Nx3
%     bec_nodes     - warped 4-layer BEM node coordinates, Mx3 single
%     bei           - per-layer mesh header (small integer matrix)
%
%   Shared by make_warping_baseline.m (to freeze the fixture) and
%   WarpingSmokeTest (to compare a fresh run against it).
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
  elec = fullfile(env.nftTest, 'jop3.elp');
  if exist(elec, 'file') ~= 2
      error('NFT:test:missingFixture', 'Electrode fixture not found: %s', elec);
  end

  % Guard: run the checkout under test, not a stray copy elsewhere on the saved
  % MATLAB path. nft_test_env prepends env.repoRoot, so this should always hold.
  % Fail hard (not warn) on a mismatch: validating the code under test is the
  % whole point, so producing results from other code is never useful. The
  % trailing-filesep comparison is path-boundary-safe, so a sibling directory
  % such as '<repoRoot>-old' cannot masquerade as being under repoRoot.
  resolved = which('nft_warping_mesh');
  assert(~isempty(resolved), 'NFT:test:notFound', 'nft_warping_mesh is not on the path.');
  expectedPrefix = [env.repoRoot filesep];
  if ~strncmp(resolved, expectedPrefix, numel(expectedPrefix))
      error('NFT:test:pathShadow', ...
          'nft_warping_mesh resolved to %s (expected under %s); refusing to run shadowed code.', ...
          resolved, env.repoRoot);
  end

  % Run inside the scratch dir so any stray cwd-relative writes stay contained.
  % Binary paths (nft_get_config) and elec are absolute, so changing dir is safe.
  origDir = pwd;
  restore = onCleanup(@() cd(origDir));
  cd(scratchOf);

  [~, ~, warping] = nft_warping_mesh('jc', 's1', elec, 4, scratchOf, 0, 0);

  S   = load(fullfile(scratchOf, 'jc_s1.sensors'), '-mat');   % struct: fn eloc pnt ind
  bec = load(fullfile(scratchOf, 'jc.bec'));                  % [idx x y z] per node
  bei = load(fullfile(scratchOf, 'jc.bei'));                  % per-layer header

  out = struct( ...
      'warping_param', warping, ...
      'sens_pnt',      S.pnt, ...
      'bec_nodes',     single(bec(:, 2:4)), ...
      'bei',           bei);
end
