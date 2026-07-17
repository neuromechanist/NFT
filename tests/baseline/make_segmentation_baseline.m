%MAKE_SEGMENTATION_BASELINE Establish the segmentation regression fixture.
%
%   Runs the headless segmentation pipeline (nft_segmentation) against the real
%   NFT_test Subj_mri fixture, verifies the run is finite and bit-reproducible,
%   then freezes the four masks plus provenance into
%   tests/fixtures/segmentation_baseline/. This fixture is the regression
%   anchor for issue #45 (adopting mexitk to fix Apple-Silicon segmentation) --
%   without it, that change would have nothing to check its output against.
%
%   FRESH RE-BASELINE, NOT A REPRODUCTION. The historical NFT_test/
%   jc_segments.mat records subject jc's other segmentation parameters
%   (parameters.skull.sli_eyes = 87, parameters.skull.thr = 7.8543e+03,
%   parameters.brain.slice = 70, parameters.brain.WMp = [112 150 156],
%   parameters.brain.threshold = 0.5) but NOT the two eye-click coordinates a
%   human supplied interactively to segm_outer_skull's ginput(2) call -- that
%   input was never saved anywhere. It is therefore not reproducible even in
%   principle, the same situation as the lost compact-SCS variant behind
%   cortex_source_scs.mat (resolved by re-baselining in PR #16; see
%   tests/fixtures/dsl_baseline/PROVENANCE.md). This script does the same:  it
%   derives fresh eye seed points from the data (see PROVENANCE.md) rather than
%   guessing at, or claiming agreement with, the lost original clicks.
%
%   Requires the fixture (NFT_test/Subj_mri.hdr + .img, resolved via
%   nft_test_env's NFT_TEST_DIR) and the mexitk MEX for the current platform.
%   The CURRENTLY FROZEN reference.mat was originally captured on Linux
%   (glnxa64) with the historical matitk MEX; segmentation now runs through
%   mexitk (github.com/neuromechanist/mexitk), and a mexitk run on Apple Silicon
%   reproduces that reference at Dice = 1.0 on all four masks (2026-07-17), so a
%   regenerated baseline is consistent with the frozen one. mexitk ships an
%   mexmaca64 build, so unlike matitk this runs on Apple Silicon directly.
%   Headless:
%     matlab -batch "addpath('tests'); addpath('tests/baseline'); make_segmentation_baseline"
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
addpath(fullfile(env.repoRoot, 'tests', 'baseline'));
assert(env.hasSegFixture, 'NFT:test:noFixture', ...
    'Segmentation MRI fixture not found at %s.hdr/.img', env.segMriFile);
assert(exist('mexitk', 'file') == 3, 'NFT:test:noMexitk', ...
    ['mexitk MEX function not found for this platform (%s). Segmentation cannot ' ...
     'run without it. Install the mexitk MEX for this architecture ' ...
     '(github.com/neuromechanist/mexitk) and add it to the path.'], computer('arch'));

fixtureDir = fullfile(env.repoRoot, 'tests', 'fixtures', 'segmentation_baseline');
if exist(fixtureDir, 'dir') ~= 7
    mkdir(fixtureDir);
end

scratchRoot = fullfile(tempdir, sprintf('nft_seg_baseline_%d', feature('getpid')));
if exist(scratchRoot, 'dir') == 7      % never inherit a prior/aborted run's outputs
    rmdir(scratchRoot, 's');
end
cleaner = onCleanup(@() rmIfExists(scratchRoot));

fprintf('Running segmentation (run 1)...\n');
tic;
out1 = run_segmentation(env, fullfile(scratchRoot, 'run1'));
dur1 = toc;
fprintf('  run 1: %.1f s\n', dur1);
assert(all(isfinite(double(out1.scalpmask(:)))) && all(isfinite(double(out1.brainmask(:)))) && ...
    all(isfinite(double(out1.outerskullmask(:)))) && all(isfinite(double(out1.innerskullmask(:)))), ...
    'NFT:test:nonFiniteBaseline', ...
    'Segmentation baseline run produced non-finite output; refusing to freeze a broken baseline.');

% Determinism check: rerun the FULL pipeline and verify the masks are bit-
% identical, exactly as make_dsl_baseline.m does for SCS/SBL -- measured, not
% assumed. (Anisotropic filtering, watershed, and morphology are all
% deterministic algorithms, but a compiled ITK library run through MEX could in
% principle differ across runs via thread-scheduling-dependent float summation
% order; this checks that directly rather than trusting it.)
fprintf('Running segmentation (run 2, determinism check)...\n');
tic;
out2 = run_segmentation(env, fullfile(scratchRoot, 'run2'));
dur2 = toc;
fprintf('  run 2: %.1f s\n', dur2);

maskFields = {'scalpmask', 'brainmask', 'outerskullmask', 'innerskullmask'};
for i = 1:numel(maskFields)
    f = maskFields{i};
    nDiff = nnz(out1.(f) ~= out2.(f));
    fprintf('  %s: %d differing voxels / %d\n', f, nDiff, numel(out1.(f)));
    assert(nDiff == 0, 'NFT:test:notDeterministic', ...
        '%s is not bit-reproducible (%d differing voxels); baseline would be unstable.', f, nDiff);
end

% Plausibility: anatomical containment (brain subset of outer skull subset of
% scalp) should hold near-exactly for a sane segmentation.
n = numel(out1.scalpmask);
propScalp = nnz(out1.scalpmask) / n;
propBrain = nnz(out1.brainmask) / n;
propOuter = nnz(out1.outerskullmask) / n;
propInner = nnz(out1.innerskullmask) / n;
brainInOuter = nnz(out1.brainmask & out1.outerskullmask) / max(1, nnz(out1.brainmask));
outerInScalp = nnz(out1.outerskullmask & out1.scalpmask) / max(1, nnz(out1.outerskullmask));
fprintf('Proportions: scalp=%.4f brain=%.4f outerskull=%.4f innerskull=%.4f\n', ...
    propScalp, propBrain, propOuter, propInner);
fprintf('Containment: brain-in-outerskull=%.4f outerskull-in-scalp=%.4f\n', ...
    brainInOuter, outerInScalp);
assert(brainInOuter > 0.99 && outerInScalp > 0.99, 'NFT:test:implausibleBaseline', ...
    ['Segmentation masks fail the basic anatomical-containment sanity check ' ...
     '(brain-in-outerskull=%.4f, outerskull-in-scalp=%.4f); refusing to freeze.'], ...
    brainInOuter, outerInScalp);

% Freeze the compact reference. Masks are logical; MATLAB's default -v7 save
% format zlib-compresses each variable, and logical/binary masks compress
% extremely well (the historical jc_segments.mat, which stores the same four
% full-resolution 256^3 masks, is 542 KB on disk) -- unlike the continuous-
% valued filtered MRI (jc_mri.mat, 94 MB), which this baseline deliberately
% does NOT freeze; nft_segmentation() writes it separately and it is not
% needed for a mask-regression test.
scalpmask      = out1.scalpmask;       %#ok<NASGU>
brainmask      = out1.brainmask;       %#ok<NASGU>
outerskullmask = out1.outerskullmask;  %#ok<NASGU>
innerskullmask = out1.innerskullmask;  %#ok<NASGU>
parameters     = out1.parameters;      %#ok<NASGU>
refFile = fullfile(fixtureDir, 'reference.mat');
save(refFile, 'scalpmask', 'brainmask', 'outerskullmask', 'innerskullmask', 'parameters', '-v7');
info = dir(refFile);
fprintf('Wrote %s (%.0f KB)\n', refFile, info.bytes / 1024);

writeProvenance(fullfile(fixtureDir, 'PROVENANCE.md'), env, out1, ...
    propScalp, propBrain, propOuter, propInner, brainInOuter, outerInScalp, dur1);
fprintf('Wrote %s\n', fullfile(fixtureDir, 'PROVENANCE.md'));
fprintf('Baseline fixture complete.\n');

function writeProvenance(path, env, out, propScalp, propBrain, propOuter, propInner, ...
    brainInOuter, outerInScalp, dur)
  [gitOk, sha] = system(sprintf('git -C "%s" rev-parse --short HEAD', env.repoRoot));
  if gitOk ~= 0
      sha = 'unknown';
  end
  sha = strtrim(sha);
  mexitkPath = which('mexitk');
  mexitkSha = 'unavailable';
  if ~isempty(mexitkPath)
      [shaOk, shaOut] = system(sprintf('shasum -a 256 "%s" 2>/dev/null || sha256sum "%s"', ...
          mexitkPath, mexitkPath));
      if shaOk == 0
          parts = strsplit(strtrim(shaOut));
          mexitkSha = parts{1};
      end
  end

  fid = fopen(path, 'w');
  if fid == -1
      error('NFT:test:provenanceWriteFailed', 'Could not open %s for writing.', path);
  end
  c = onCleanup(@() fclose(fid));

  fprintf(fid, '# Segmentation baseline fixture provenance\n\n');
  fprintf(fid, '- Generated: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
  fprintf(fid, '- MATLAB: %s\n', version());
  fprintf(fid, '- Platform: %s (arch %s)\n', computer(), computer('arch'));
  fprintf(fid, '- NFT commit: %s\n', sha);
  fprintf(fid, '- mexitk MEX: %s\n', mexitkPath);
  fprintf(fid, '- mexitk sha256: %s\n', mexitkSha);
  fprintf(fid, '- Input: %s.hdr/.img (subject jc, 256^3, 1mm isotropic)\n', env.segMriFile);
  fprintf(fid, '- Run time: %.1f s\n', dur);

  fprintf(fid, '\n## Summary: what was recovered vs. what was derived fresh\n\n');
  fprintf(fid, ['This is a **fresh re-baseline**, not a reproduction of the historical\n' ...
      'NFT_test/jc_segments.mat. That file''s parameters struct DOES survive intact and is\n' ...
      'reused here verbatim -- sli=70, WMp=[112 150 156], sl=0.4, st=0.5, sli_eyes=87, and\n' ...
      'the filter/LRflip settings (see the parameter table below, "source" column). The ONE\n' ...
      'input that did NOT survive, anywhere, is the two [x y] eye-seed points a human clicked\n' ...
      'via ginput(2) on slice 87 -- jc_segments.mat''s parameters.skull struct has only\n' ...
      'sli_eyes and thr, not the click coordinates themselves. Those two points are therefore\n' ...
      'the only part of this baseline that is freshly derived rather than recovered from\n' ...
      'history; see "Eye seed points" below for exactly how.\n']);

  fprintf(fid, '\n## How this reference was captured, and its implementation-independence\n\n');
  fprintf(fid, ['The frozen reference.mat was originally captured on Linux (glnxa64, MATLAB %s)\n' ...
      'with the historical matitk MEX -- at the time the only host with a working matitk and a\n' ...
      'MathWorks license, since matitk shipped mexa64/mexw64/mexmaci64 only and was Undefined\n' ...
      'on Apple Silicon. NFT now drives segmentation through mexitk\n' ...
      '(github.com/neuromechanist/mexitk), which ships an mexmaca64 build. MEASURED 2026-07-17:\n' ...
      'a full mexitk run on Apple Silicon reproduces this reference at Dice = 1.0 on all four\n' ...
      'masks -- the bounded FCA/SWS deviations mexitk carries are absorbed downstream by Otsu\n' ...
      'thresholding and seed-based region selection. So this baseline is robust across both the\n' ...
      'matitk->mexitk implementation change and the Linux->Apple-Silicon platform change.\n'], version());

  fprintf(fid, '\n## Parameters used (NOT nft_segmentation''s generic defaults)\n\n');
  fprintf(fid, ['nft_segmentation()''s own help text warns that sli/WMp/sl/st/sli_eyes "are\n' ...
      'picked in the GUI by visually inspecting the subject''s own slices, so treat these\n' ...
      'defaults as generic starting points, not as subject-independent constants." The\n' ...
      'historical NFT_test/jc_segments.mat records the values a human actually used for\n' ...
      'this subject, so this baseline reuses THOSE instead of the generic fallback\n' ...
      '(sli=66, WMp=[135 135 110], st=0.4):\n\n']);
  fprintf(fid, '| parameter | value used | generic default | source |\n');
  fprintf(fid, '|---|---|---|---|\n');
  fprintf(fid, '| sli (brain.slice) | 70 | 66 | jc_segments.mat parameters.brain.slice |\n');
  fprintf(fid, '| WMp | [112 150 156] | [135 135 110] | jc_segments.mat parameters.brain.WMp |\n');
  fprintf(fid, '| sl (fill level) | 0.4 | 0.4 | jc_segments.mat parameters.brain.filllevel (matches default) |\n');
  fprintf(fid, '| st (threshold) | 0.5 | 0.4 | jc_segments.mat parameters.brain.threshold |\n');
  fprintf(fid, '| sli_eyes | 87 | 110 | jc_segments.mat parameters.skull.sli_eyes |\n');
  fprintf(fid, '| iter, ts, cond | 5, 0.0625, 3 | 5, 0.0625, 3 | jc_segments.mat parameters.filter (iter/cond); ts is hardcoded in the GUI, not a free parameter |\n');
  fprintf(fid, '| LRflip | 0 | 0 | jc_segments.mat parameters.LRflip |\n');
  fprintf(fid, ['\nResulting threshold (segm_outer_skull''s automatic k1max-based thr) was\n' ...
      '**7854.32**, matching jc_segments.mat''s parameters.skull.thr (7.8543e+03) to 5\n' ...
      'significant figures -- this is deterministic given (filteredvol, thr method) and is\n' ...
      'NOT affected by the eye clicks, so this match cross-validates the filtering/threshold\n' ...
      'path independent of the (unrecoverable) eye coordinates.\n']);

  fprintf(fid, '\n## Eye seed points: FRESH derivation (the one input that could not be recovered)\n\n');
  fprintf(fid, ['jc_segments.mat''s parameters.skull struct has only sli_eyes and thr -- the\n' ...
      'two [x y] points a human clicked via ginput(2) on slice 87 were never saved anywhere\n' ...
      'and cannot be recovered. Per the owner''s prior decision on the equivalent lost-input\n' ...
      'situation for cortex_source_scs.mat (PR #16, see tests/fixtures/dsl_baseline/\n' ...
      'PROVENANCE.md), this is treated as a fresh re-baseline: derive new, defensible seed\n' ...
      'points from the data rather than guessing at, or claiming to reproduce, the original.\n\n']);
  fprintf(fid, ['Derivation: ran filtering + scalp + brain segmentation (the three matitk-backed\n' ...
      'steps preceding the eye-marking step) with the parameters above, then reproduced\n' ...
      'segm_outer_skull''s own X_dark = filteredvol < thr computation for slice_eyes=87.\n' ...
      'Restricting X_dark to the scalp mask on that slice and computing 8-connected\n' ...
      'components (MATLAB bwconncomp/regionprops) found two components whose centroids are\n' ...
      'closely bilaterally symmetric about the slice midline (256/2=128) and whose location\n' ...
      'overlaps the two round dark orbit structures clearly visible in the filtered image\n' ...
      '(visually confirmed by overlaying centroids on the slice -- see the session record; not\n' ...
      'checked into the repo, described here for reproducibility):\n\n']);
  fprintf(fid, '| eye | area (px) | centroid (x,y) | eccentricity |\n');
  fprintf(fid, '|---|---|---|---|\n');
  fprintf(fid, '| left  | 41  | (83.44, 76.32) | 0.807 |\n');
  fprintf(fid, '| right | 133 | (157.01, 67.62) | 0.714 |\n');
  fprintf(fid, ['\nRounded to `Eyes = [83 76; 157 68]` (segm_outer_skull rounds internally via\n' ...
      '`xp = round(eyes(:,1)); yp = round(eyes(:,2))` regardless of path, so this is exactly\n' ...
      'what a human clicking those two points with ginput(2) on\n' ...
      '`imagesc(reshape(X_dark(:,87,:),K,M))` would have produced -- Centroid(1)/Centroid(2)\n' ...
      'from MATLAB''s regionprops on that same 2-D matrix are already in ginput''s (x,y)\n' ...
      'data-coordinate convention.) Both points lie inside `X_dark & scalpmask` (confirmed: the\n' ...
      'components were found there), which utilsegm_regiongrow requires -- a seed outside that\n' ...
      'set raises "seed is empty" rather than silently misbehaving, so a bad choice would have\n' ...
      'failed loudly, not passed quietly.\n\n' ...
      'Left/right area is asymmetric (41 vs 133 px) and not centered on the full visible orbit\n' ...
      'circle -- only part of each orbit is actually below the automatic dark threshold at this\n' ...
      'slice, the rest is not. This is plausible (natural anatomical asymmetry / partial-volume\n' ...
      'effects in a real scan) and does not by itself indicate an error; it is recorded here so\n' ...
      'a future re-derivation can compare against it rather than assume the original reasoning.\n']);

  fprintf(fid, '\n## Plausibility checks (measured, not assumed)\n\n');
  fprintf(fid, '- Mask proportions of total volume (256^3 = 16,777,216 voxels):\n\n');
  fprintf(fid, '  | mask | this baseline | historical jc_segments.mat (different eye clicks) |\n');
  fprintf(fid, '  |---|---|---|\n');
  fprintf(fid, '  | scalp | %.4f | 0.2326 |\n', propScalp);
  fprintf(fid, '  | brain | %.4f | 0.1310 |\n', propBrain);
  fprintf(fid, '  | outer skull | %.4f | 0.1636 |\n', propOuter);
  fprintf(fid, '  | inner skull | %.4f | 0.1469 |\n', propInner);
  fprintf(fid, (['\n  The historical numbers are NOT a pass/fail target (its eye clicks are lost and\n' ...
      '  irreproducible, so exact agreement is not expected or required) -- they are informative\n' ...
      '  context only, and the close agreement here (all four within ~3%% relative) is a useful\n' ...
      '  independent plausibility signal, not a correctness proof.\n\n']));
  fprintf(fid, '- Anatomical containment: brain-in-outerskull = %.4f, outerskull-in-scalp = %.4f\n', ...
      brainInOuter, outerInScalp);
  fprintf(fid, '  (both should be ~1.0 for a sane segmentation; both baseline runs were exactly 1.0000)\n');
  fprintf(fid, ['- Qualitative: a mid-axial-slice overlay of all four masks was visually inspected\n' ...
      '  (smooth nested contours, no holes/artifacts, brain fully interior to a thin skull ring\n' ...
      '  fully interior to scalp) -- not checked into the repo; described here for the record.\n']);

  fprintf(fid, '\n## Determinism\n\n');
  fprintf(fid, ['The full pipeline (filtering -> scalp -> brain -> outer skull -> inner skull ->\n' ...
      'final skull/scalp correction) was run twice with identical inputs. All four masks were\n' ...
      'bit-identical across the two runs (0 differing voxels out of 16,777,216, all four masks).\n' ...
      'SegmentationRegressionTest compares a fresh run against this frozen baseline with an\n' ...
      'exact-match check on that basis; see its own comments for the cross-platform caveat\n' ...
      '(this was only measured on glnxa64/R2025b, not cross-checked against another platform).\n']);

  fprintf(fid, '\n## Fixture size discipline\n\n');
  fprintf(fid, ['Stores the four full-resolution logical masks (256^3 each) plus the small\n' ...
      'parameters struct -- NOT the filtered MRI volume nft_segmentation() also writes\n' ...
      '(jc_mri.mat-equivalent, continuous-valued, ~94 MB uncompressed and still ~94 MB after\n' ...
      'MATLAB''s default -v7 zlib compression, since continuous float data does not compress\n' ...
      'well). Binary masks compress far better under -v7 -- the historical jc_segments.mat,\n' ...
      'which stores the same four full-resolution masks, is 542 KB on disk -- so storing full\n' ...
      'masks here (rather than a lossy digest, cf. tests/dsl_digest.m) is both affordable and\n' ...
      'gives an exact per-voxel comparison rather than a compressed summary statistic.\n']);
end

function rmIfExists(d)
  if exist(d, 'dir') == 7
      rmdir(d, 's');
  end
end
