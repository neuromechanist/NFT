classdef WarpingSmokeTest < matlab.unittest.TestCase
    %WARPINGSMOKETEST End-to-end regression anchor for the electrode-warping path.
    %
    %   Re-runs nft_warping_mesh for subject jc / session s1 against the real
    %   NFT_test data and compares the warp transform, warped electrode positions,
    %   and warped BEM mesh against the frozen baseline in
    %   tests/fixtures/warping_baseline/. This is the safety net that later cleanup
    %   phases are checked against.
    %
    %   Tolerances are grounded in measurement: on the reference machine
    %   (MATLAB R2025b, Apple Silicon, Intel .osx binaries under Rosetta 2) the
    %   transform, sensors, and mesh all reproduce EXACTLY across runs (delta 0.0),
    %   and the transform matches the historical 2023 baseline to 5.7e-14. The
    %   tolerances below therefore only absorb potential cross-platform /
    %   MATLAB-version floating-point drift, not same-platform variation. Caveat:
    %   the mesh tolerance additionally rests on procmesh (a compiled binary run
    %   mid-pipeline) being cross-platform deterministic, which is NOT yet measured
    %   -- re-validate it before trusting this test off the reference machine.
    %
    %   Skips cleanly (assumeTrue) when the NFT_test fixtures, EEGLAB, the binaries,
    %   or the frozen baseline are unavailable (e.g. a bare CI runner) so it never
    %   hard-fails on a machine that simply lacks the inputs.
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
        out        % fresh warping outputs (computed once in class setup)
        ref        % frozen baseline reference
    end

    methods (TestClassSetup)
        function runWarpOnce(tc)
            env = nft_test_env();
            tc.assumeTrue(env.hasFixtures, ...
                sprintf('NFT_test fixtures not at %s; skipping warping smoke test.', env.nftTest));
            tc.assumeTrue(env.hasEeglab, ...
                'EEGLAB (readlocs) not available; skipping warping smoke test.');
            tc.assumeTrue(nft_binaries_present(), ...
                'Warping binaries not available; skipping warping smoke test.');
            refFile = fullfile(env.repoRoot, 'tests', 'fixtures', 'warping_baseline', 'reference.mat');
            tc.assumeTrue(exist(refFile, 'file') == 2, ...
                'Baseline fixture missing; run tests/baseline/make_warping_baseline.m first.');
            tc.ref = load(refFile);

            scratchOf = fullfile(tempdir, sprintf('nft_warp_smoke_%d', feature('getpid')));
            if exist(scratchOf, 'dir') == 7
                rmdir(scratchOf, 's');
            end
            tc.addTeardown(@() rmIfExists(scratchOf));
            tc.out = run_warping(env, scratchOf);
        end
    end

    methods (Test)
        function transformMatchesBaseline(tc)
            v  = warp_flatten(tc.out.warping_param);
            v0 = warp_flatten(tc.ref.warping_param);
            tc.verifyEqual(numel(v), numel(v0), 'Warp transform element count changed.');
            % NaN/Inf must fail loudly: max() silently drops NaN, so a regression
            % that produced a NaN would otherwise slip through the tolerance check.
            tc.verifyTrue(all(isfinite(v)), 'Warp transform contains NaN/Inf.');
            if numel(v) == numel(v0)
                relerr = max(abs(v - v0)) / max(1, max(abs(v0)));
                tc.verifyLessThan(relerr, 1e-9, ...
                    sprintf('Warp transform diverged from baseline (rel err %.3e).', relerr));
            end
        end

        function warpedSensorsMatchBaseline(tc)
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            tc.verifyEqual(size(tc.out.sens_pnt), size(tc.ref.sens_pnt), ...
                'Warped sensor array shape changed.');
            if isequal(size(tc.out.sens_pnt), size(tc.ref.sens_pnt))
                tc.verifyThat(tc.out.sens_pnt, ...
                    IsEqualTo(tc.ref.sens_pnt, 'Within', AbsoluteTolerance(1e-3)), ...
                    'Warped electrode positions diverged from baseline.');
            end
        end

        function meshStructureMatchesBaseline(tc)
            tc.verifyEqual(tc.out.bei, tc.ref.bei, ...
                'BEM mesh per-layer structure (bei) changed.');
            tc.verifyEqual(size(tc.out.bec_nodes), size(tc.ref.bec_nodes), ...
                'BEM mesh node count/shape changed.');
        end

        function meshCoordsMatchBaseline(tc)
            import matlab.unittest.constraints.IsEqualTo
            import matlab.unittest.constraints.AbsoluteTolerance
            % IsEqualTo fails (not skips) on a size mismatch, so no separate guard
            % is needed here; meshStructureMatchesBaseline reports the size cause.
            tc.verifyThat(double(tc.out.bec_nodes), ...
                IsEqualTo(double(tc.ref.bec_nodes), 'Within', AbsoluteTolerance(1e-2)), ...
                'Warped BEM mesh node coordinates diverged from baseline.');
        end

        function outputsAreFinite(tc)
            tc.verifyTrue(all(isfinite(tc.out.sens_pnt(:))), ...
                'Warped sensor positions contain NaN/Inf.');
            tc.verifyTrue(all(isfinite(double(tc.out.bec_nodes(:)))), ...
                'BEM mesh node coordinates contain NaN/Inf.');
        end
    end
end

function rmIfExists(d)
  if exist(d, 'dir') == 7
      rmdir(d, 's');
  end
end
