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
    %   MATLAB-version floating-point drift, not same-platform variation.
    %
    %   Skips cleanly (assumeTrue) when the NFT_test fixtures, the binaries, or the
    %   frozen baseline are unavailable (e.g. a bare CI runner) so it never
    %   false-fails on a machine that simply lacks the inputs.

    properties
        out        % fresh warping outputs (computed once in class setup)
        ref        % frozen baseline reference
    end

    methods (TestClassSetup)
        function runWarpOnce(tc)
            env = nft_test_env();
            tc.assumeTrue(env.hasFixtures, ...
                sprintf('NFT_test fixtures not at %s; skipping warping smoke test.', env.nftTest));
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
            if numel(v) == numel(v0)
                relerr = max(abs(v - v0)) / max(1, max(abs(v0)));
                tc.verifyLessThan(relerr, 1e-6, ...
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
            if isequal(size(tc.out.bec_nodes), size(tc.ref.bec_nodes))
                tc.verifyThat(double(tc.out.bec_nodes), ...
                    IsEqualTo(double(tc.ref.bec_nodes), 'Within', AbsoluteTolerance(1e-2)), ...
                    'Warped BEM mesh node coordinates diverged from baseline.');
            else
                tc.assumeFail('Mesh node count differs; see meshStructureMatchesBaseline.');
            end
        end
    end
end

function rmIfExists(d)
  if exist(d, 'dir') == 7
      rmdir(d, 's');
  end
end
