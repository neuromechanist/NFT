function out = run_segmentation(env, scratchOf)
%RUN_SEGMENTATION Run the headless segmentation pipeline into a scratch dir.
%
%   out = RUN_SEGMENTATION(env, scratchOf) runs nft_segmentation for subject
%   'jc' against the Analyze-format MRI fixture at env.segMriFile (Subj_mri),
%   writing outputs into scratchOf, and returns the four segmentation masks
%   plus the parameters struct nft_segmentation recorded.
%
%   The keyword arguments are NOT nft_segmentation's generic defaults -- they
%   are the per-subject values recorded in the historical NFT_test/
%   jc_segments.mat (parameters.brain.slice=70, WMp=[112 150 156],
%   threshold=0.5; sli_eyes=87), which nft_segmentation's own help text warns
%   are "picked in the GUI by visually inspecting the subject's own slices,
%   so treat [the generic] defaults as generic starting points, not as
%   subject-independent constants". Reusing jc's own recorded values is more
%   defensible than the generic fallback for this subject's anatomy.
%
%   The eye seed points (the one input jc_segments.mat did NOT record -- see
%   tests/fixtures/segmentation_baseline/PROVENANCE.md) were derived fresh by
%   inspecting slice 87 of the filtered volume: X_dark (the same b < thr dark-
%   voxel mask segm_outer_skull computes) was intersected with the scalp mask,
%   connected components were computed, and the centroids of the two bilateral
%   components overlapping the visually-identified orbit locations were used.
%   See PROVENANCE.md for the exact derivation and plausibility checks
%   (anatomical containment, proportion-vs-historical comparison, bit-exact
%   determinism across two full runs).
%
%   Shared by make_segmentation_baseline.m (to freeze the fixture) and
%   SegmentationRegressionTest (to compare a fresh run against it).
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
  if exist([env.segMriFile '.hdr'], 'file') ~= 2
      error('NFT:test:missingFixture', 'Segmentation MRI fixture not found: %s.hdr', env.segMriFile);
  end

  % Guard: run the checkout under test, not a stray copy elsewhere on the saved
  % MATLAB path (same rationale as run_warping.m).
  resolved = which('nft_segmentation');
  assert(~isempty(resolved), 'NFT:test:notFound', 'nft_segmentation is not on the path.');
  expectedPrefix = [env.repoRoot filesep];
  if ~strncmp(resolved, expectedPrefix, numel(expectedPrefix))
      error('NFT:test:pathShadow', ...
          'nft_segmentation resolved to %s (expected under %s); refusing to run shadowed code.', ...
          resolved, env.repoRoot);
  end

  eyes = [83 76; 157 68];   % see PROVENANCE.md for derivation

  Segm = nft_segmentation('jc', scratchOf, env.segMriFile, ...
      'sli', 70, 'WMp', [112 150 156], 'sl', 0.4, 'st', 0.5, ...
      'sli_eyes', 87, 'Eyes', eyes);

  out = struct( ...
      'scalpmask',      Segm.scalpmask, ...
      'brainmask',       Segm.brainmask, ...
      'outerskullmask', Segm.outerskullmask, ...
      'innerskullmask', Segm.innerskullmask, ...
      'parameters',     Segm.parameters);
end
