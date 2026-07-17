classdef SegmentationRegressionTest < matlab.unittest.TestCase
    %SEGMENTATIONREGRESSIONTEST Regression anchor for the headless segmentation path.
    %
    %   Re-runs nft_segmentation for subject jc (via tests/baseline/run_segmentation.m,
    %   using the historical per-subject parameters and freshly-derived eye seed
    %   points documented in tests/fixtures/segmentation_baseline/PROVENANCE.md)
    %   against the real NFT_test Subj_mri fixture, and compares the four output
    %   masks against the frozen baseline in tests/fixtures/segmentation_baseline/.
    %   This is the safety net issue #45 (adopting mexitk to fix Apple-Silicon
    %   segmentation) is checked against -- without it, that change would have
    %   nothing to verify its output didn't silently regress.
    %
    %   Comparison is Dice-coefficient-based, not isequal/exact. The frozen
    %   baseline was captured on Linux (glnxa64, MATLAB R2025b) with the historical
    %   matitk MEX; NFT now drives segmentation through mexitk (a BSD-3 MATLAB-ITK
    %   bridge, github.com/neuromechanist/mexitk) instead. MEASURED 2026-07-17: a
    %   full mexitk run on Apple Silicon (maca64) reproduces this Linux/matitk
    %   baseline at Dice = 1.0000 on ALL FOUR masks -- the bounded FCA/SWS
    %   filter-level deviations mexitk carries are absorbed downstream by Otsu
    %   thresholding and seed-based region selection, so they do not reach the
    %   masks. The Dice threshold (close to but not exactly 1.0) is retained
    %   anyway: that cross-platform/cross-implementation equality was measured for
    %   one subject and one parameter set, not proven in general, so the threshold
    %   absorbs the unmeasured tail without silently accepting a real regression.
    %
    %   Skips cleanly (assumeTrue) when the NFT_test fixture, mexitk, or the frozen
    %   baseline are unavailable (e.g. a bare CI runner without NFT_test staged, or
    %   a host without the mexitk MEX for its architecture) so it never hard-fails
    %   on a machine that simply lacks the inputs.
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

    properties
        out        % fresh segmentation outputs (computed once in class setup)
        ref        % frozen baseline reference
    end

    properties (Constant)
        % Same-platform determinism was measured EXACT (0/16,777,216 differing
        % voxels across two full reruns); this only needs to absorb an unmeasured
        % cross-platform/MATLAB-version risk, so it stays very tight. Any real
        % regression in the segmentation algorithm would move Dice far below this
        % (see PROVENANCE.md's plausibility numbers for the scale of a "different
        % but still sane" result: ~3% proportion differences from different eye
        % clicks alone).
        DiceTol = 0.999;
    end

    methods (TestClassSetup)
        function runSegmentationOnce(tc)
            env = nft_test_env();
            tc.assumeTrue(env.hasSegFixture, ...
                sprintf('Segmentation MRI fixture not at %s.hdr/.img; skipping.', env.segMriFile));
            tc.assumeTrue(exist('mexitk', 'file') == 3, ...
                sprintf(['mexitk MEX not available for this platform (%s); skipping. ' ...
                'Install the mexitk MEX for this architecture ' ...
                '(github.com/neuromechanist/mexitk) and add it to the path.'], ...
                computer('arch')));
            refFile = fullfile(env.repoRoot, 'tests', 'fixtures', 'segmentation_baseline', 'reference.mat');
            tc.assumeTrue(exist(refFile, 'file') == 2, ...
                'Segmentation baseline fixture missing; run tests/baseline/make_segmentation_baseline.m first.');
            tc.ref = load(refFile);

            scratchOf = fullfile(tempdir, sprintf('nft_seg_smoke_%d', feature('getpid')));
            if exist(scratchOf, 'dir') == 7
                rmdir(scratchOf, 's');
            end
            tc.addTeardown(@() rmIfExists(scratchOf));
            tc.out = run_segmentation(env, scratchOf);
        end
    end

    methods (Test)
        function masksAreLogical(tc)
            % A regression that silently changed a mask's dtype (e.g. to double)
            % would still often compare "close enough" numerically; catch the
            % type change directly instead.
            tc.verifyClass(tc.out.scalpmask, 'logical');
            tc.verifyClass(tc.out.brainmask, 'logical');
            tc.verifyClass(tc.out.outerskullmask, 'logical');
            tc.verifyClass(tc.out.innerskullmask, 'logical');
        end

        function maskShapesMatchBaseline(tc)
            tc.verifyEqual(size(tc.out.scalpmask), size(tc.ref.scalpmask), 'scalpmask shape changed.');
            tc.verifyEqual(size(tc.out.brainmask), size(tc.ref.brainmask), 'brainmask shape changed.');
            tc.verifyEqual(size(tc.out.outerskullmask), size(tc.ref.outerskullmask), 'outerskullmask shape changed.');
            tc.verifyEqual(size(tc.out.innerskullmask), size(tc.ref.innerskullmask), 'innerskullmask shape changed.');
        end

        function scalpMatchesBaseline(tc)
            verifyMaskDice(tc, tc.out.scalpmask, tc.ref.scalpmask, 'scalpmask');
        end

        function brainMatchesBaseline(tc)
            verifyMaskDice(tc, tc.out.brainmask, tc.ref.brainmask, 'brainmask');
        end

        function outerSkullMatchesBaseline(tc)
            verifyMaskDice(tc, tc.out.outerskullmask, tc.ref.outerskullmask, 'outerskullmask');
        end

        function innerSkullMatchesBaseline(tc)
            verifyMaskDice(tc, tc.out.innerskullmask, tc.ref.innerskullmask, 'innerskullmask');
        end

        function containmentIsAnatomicallyPlausible(tc)
            % Independent of the baseline comparison: brain should be (almost)
            % entirely inside the outer-skull mask, which should be (almost)
            % entirely inside the scalp mask, for ANY sane segmentation run. A
            % regression could in principle match the baseline's Dice yet still
            % break this invariant (e.g. a coordinate-order bug), so check it
            % directly rather than relying on the baseline comparison alone.
            brainInOuter = nnz(tc.out.brainmask & tc.out.outerskullmask) / max(1, nnz(tc.out.brainmask));
            outerInScalp = nnz(tc.out.outerskullmask & tc.out.scalpmask) / max(1, nnz(tc.out.outerskullmask));
            tc.verifyGreaterThan(brainInOuter, 0.99, ...
                sprintf('Brain mask is not (almost) fully contained in the outer-skull mask (%.4f).', brainInOuter));
            tc.verifyGreaterThan(outerInScalp, 0.99, ...
                sprintf('Outer-skull mask is not (almost) fully contained in the scalp mask (%.4f).', outerInScalp));
        end
    end
end

function verifyMaskDice(tc, a, b, name)
    % NaN/Inf cannot occur in a logical array by construction, so there is no
    % separate finiteness check here (unlike WarpingSmokeTest's numeric
    % transform) -- masksAreLogical() is what catches a dtype regression that
    % could reintroduce that possibility.
    if ~isequal(size(a), size(b))
        tc.assumeFail(sprintf('%s: size mismatch, skipping Dice comparison (see maskShapesMatchBaseline).', name));
        return
    end
    denom = nnz(a) + nnz(b);
    if denom == 0
        dice = 1;   % both empty: trivially identical
    else
        dice = 2 * nnz(a & b) / denom;
    end
    tc.verifyGreaterThanOrEqual(dice, SegmentationRegressionTest.DiceTol, ...
        sprintf('%s diverged from baseline (Dice = %.6f, threshold %.6f).', ...
        name, dice, SegmentationRegressionTest.DiceTol));
end

function rmIfExists(d)
  if exist(d, 'dir') == 7
      rmdir(d, 's');
  end
end
