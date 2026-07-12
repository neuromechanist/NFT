classdef DslInverseRegressionTest < matlab.unittest.TestCase
    %DSLINVERSEREGRESSIONTEST Regression anchor for the SCS/SBL inverse solvers.
    %
    %   Re-runs the distributed-source-localization inverse solver on the cortical
    %   demo fixture (env var NFT_DSL_DIR) and compares a compact digest of the SCS
    %   and SBL source estimates against the frozen baseline in
    %   tests/fixtures/dsl_baseline/. This locks the reproducible behavior of the
    %   surviving SCS variant (patchz2) and of the SBL path (after the undefined-`ss`
    %   fix) so later cleanup phases (e.g. de-duplicating the GUI/headless copies)
    %   are verifiable.
    %
    %   The baseline is a re-baseline to current deterministic output, not the lost
    %   2023 compact-variant reference -- see tests/fixtures/dsl_baseline/PROVENANCE.md.
    %
    %   The solver writes cortex_source_*.mat into its output directory, so the run
    %   happens in a per-test temp dir with the (large, read-only) inputs symlinked
    %   in; teardown removes the temp dir. Skips cleanly (assumeTrue) when the
    %   fixture or the frozen baseline are absent, so it never hard-fails on a
    %   machine that simply lacks the ~230 MB dataset.
    %
    %   Tagged SlowTest+Regression: the full 11-component SCS+SBL run is minutes,
    %   so it is meant for a provisioned regression run, not every quick check.

    properties
        scs        % fresh SCS output (all components)
        sbl        % fresh SBL output (all components)
        scsDet     % fresh SCS output for component 1 (determinism rerun)
        ref        % frozen baseline reference (scs, sbl, meta)
        env        % test environment
    end

    methods (TestClassSetup)
        function runDslOnce(tc)
            env = nft_test_env();
            tc.assumeTrue(env.hasDsl, ...
                sprintf('DSL fixture not found (set NFT_DSL_DIR); skipping DSL regression.'));
            refFile = fullfile(env.repoRoot, 'tests', 'fixtures', 'dsl_baseline', 'reference.mat');
            tc.assumeTrue(exist(refFile, 'file') == 2, ...
                'DSL baseline missing; run tests/baseline/make_dsl_baseline.m first.');
            tc.ref = load(refFile);
            tc.env = env;

            root = fullfile(tempdir, sprintf('nft_dsl_reg_%d', feature('getpid')));
            if exist(root, 'dir') == 7
                rmdir(root, 's');
            end
            tc.addTeardown(@() rmIfExists(root));

            comps = tc.ref.meta.comps;
            tc.scs    = run_dsl(env, fullfile(root, 'scs'),  3, comps);
            tc.scsDet = run_dsl(env, fullfile(root, 'scsd'), 3, comps(1));
            tc.sbl    = run_dsl(env, fullfile(root, 'sbl'),  2, comps);
        end
    end

    methods (Test, TestTags = {'Regression', 'SlowTest'})
        function scsMatchesBaseline(tc)
            verifyDigest(tc, tc.ref.scs, tc.scs.sourceJ, 'SCS');
        end

        function sblMatchesBaseline(tc)
            verifyDigest(tc, tc.ref.sbl, tc.sbl.sourceJ, 'SBL');
        end

        function scsIsDeterministic(tc)
            % The regression compare only means something if the solver is
            % reproducible; a rerun of component 1 must be bit-identical.
            delta = max(abs(tc.scs.sourceJ(:, 1) - tc.scsDet.sourceJ(:, 1)));
            tc.verifyEqual(delta, 0, ...
                sprintf('SCS solver is not bit-reproducible (max|delta| = %.3g).', delta));
        end
    end
end

function verifyDigest(tc, refDigest, sourceJ, name)
    c = dsl_digest_compare(refDigest, sourceJ);
    tc.verifyTrue(c.sizeMatch, ...
        sprintf('%s: component count changed (expected %d).', name, c.nComp));
    tc.verifyTrue(c.allFinite, sprintf('%s: source contains NaN/Inf.', name));
    if ~c.sizeMatch
        return
    end
    % Same-platform deterministic reproduction; tolerances leave headroom only for
    % cross-platform / MATLAB-version floating-point drift, not algorithm change.
    tc.verifyLessThan(max(c.normRelErr), 1e-3, ...
        sprintf('%s: component norm diverged from baseline (max rel err %.3e).', name, max(c.normRelErr)));
    tc.verifyGreaterThan(min(c.topCorr), 0.9999, ...
        sprintf('%s: top-support pattern diverged (min corr %.5f).', name, min(c.topCorr)));
    tc.verifyLessThan(max(c.topRelErr), 1e-2, ...
        sprintf('%s: top-support values diverged (max rel err %.3e).', name, max(c.topRelErr)));
    tc.verifyTrue(all(c.peakMatch), ...
        sprintf('%s: peak voxel moved for component(s) %s.', name, mat2str(find(~c.peakMatch))));
end

function rmIfExists(d)
    if exist(d, 'dir') == 7
        rmdir(d, 's');
    end
end
