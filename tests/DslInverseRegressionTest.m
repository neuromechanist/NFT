classdef DslInverseRegressionTest < matlab.unittest.TestCase
    %DSLINVERSEREGRESSIONTEST Regression anchor for the SCS/SBL inverse solvers.
    %
    %   Re-runs the distributed-source-localization inverse solver on the cortical
    %   demo fixture (env var NFT_DSL_DIR) and compares a compact digest of the SCS
    %   and SBL source estimates against the frozen baseline in
    %   tests/fixtures/dsl_baseline/. This locks the reproducible behavior of the
    %   surviving SCS variant (patchz2) and of the SBL path (after the undefined-`ss`
    %   fix) so later cleanup phases (e.g. de-duplicating the GUI/headless copies)
    %   are verifiable. It exercises the headless solver
    %   (nft_dsl_inverse_problem_solution); the GUI copy in
    %   Distributed_Source_Localization.m is a verified byte-identical duplicate of
    %   the same core, so this covers both until that duplicate is removed (A2).
    %
    %   The baseline is a re-baseline to current deterministic output, not the lost
    %   2023 compact-variant reference -- see tests/fixtures/dsl_baseline/PROVENANCE.md,
    %   which also flags that SCS's final source is a discrete argmax over per-iterate
    %   compactness (bit-reproducible same-platform; a near-tie could flip across
    %   platforms, which would surface as a peakMatch failure rather than a solver bug).
    %
    %   The solvers write cortex_source_*.mat into their output directory, so the run
    %   happens once (in TestClassSetup) in a shared per-class temp dir with the
    %   (large, read-only) inputs symlinked in; a class-level teardown removes the
    %   temp dir after all tests finish. Skips cleanly (assumeTrue) when the fixture
    %   or the frozen baseline are absent, so it never hard-fails on a machine that
    %   simply lacks the ~325 MB dataset (SCS ~234 MB + SBL kernels + the .set).
    %
    %   Tagged SlowTest+Regression: the full 11-component SCS+SBL run is minutes,
    %   so it is meant for a provisioned regression run, not every quick check.
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
        scs        % fresh SCS output (all components)
        sbl        % fresh SBL output (all components)
        scsDet     % fresh SCS output for component 1 (determinism rerun)
        sblDet     % fresh SBL output for component 1 (determinism rerun)
        ref        % frozen baseline reference (scs, sbl, meta)
    end

    methods (TestClassSetup)
        function runDslOnce(tc)
            e = nft_test_env();
            tc.assumeTrue(e.hasDsl, ...
                'DSL fixture not found (set NFT_DSL_DIR); skipping DSL regression.');
            refFile = fullfile(e.repoRoot, 'tests', 'fixtures', 'dsl_baseline', 'reference.mat');
            tc.assumeTrue(exist(refFile, 'file') == 2, ...
                'DSL baseline missing; run tests/baseline/make_dsl_baseline.m first.');
            tc.ref = load(refFile);

            root = fullfile(tempdir, sprintf('nft_dsl_reg_%d', feature('getpid')));
            if exist(root, 'dir') == 7
                rmdir(root, 's');
            end
            tc.addTeardown(@() rmIfExists(root));

            comps = tc.ref.meta.comps;
            tc.scs    = run_dsl(e, fullfile(root, 'scs'),  3, comps);
            tc.scsDet = run_dsl(e, fullfile(root, 'scsd'), 3, comps(1));
            tc.sbl    = run_dsl(e, fullfile(root, 'sbl'),  2, comps);
            tc.sblDet = run_dsl(e, fullfile(root, 'sbld'), 2, comps(1));
        end
    end

    methods (Test, TestTags = {'Regression', 'SlowTest'})
        function scsMatchesBaseline(tc)
            verifyDigest(tc, tc.ref.scs, tc.ref.meta.nVoxel, tc.scs, tc.ref.meta.scsFval, 'SCS');
        end

        function sblMatchesBaseline(tc)
            verifyDigest(tc, tc.ref.sbl, tc.ref.meta.nVoxel, tc.sbl, tc.ref.meta.sblFval, 'SBL');
        end

        function scsIsDeterministic(tc)
            delta = max(abs(tc.scs.sourceJ(:, 1) - tc.scsDet.sourceJ(:, 1)));
            tc.verifyEqual(delta, 0, ...
                sprintf('SCS solver is not bit-reproducible (max|delta| = %.3g).', delta));
        end

        function sblIsDeterministic(tc)
            % sblMatchesBaseline's tight tolerances only mean something if SBL is
            % reproducible, so assert it directly (was previously only assumed).
            delta = max(abs(tc.sbl.sourceJ(:, 1) - tc.sblDet.sourceJ(:, 1)));
            tc.verifyEqual(delta, 0, ...
                sprintf('SBL solver is not bit-reproducible (max|delta| = %.3g).', delta));
        end
    end
end

function verifyDigest(tc, refDigest, nVoxel, out, refFval, name)
    sourceJ = out.sourceJ;
    % Guard the voxel (row) count before dsl_digest_compare indexes topIdx into it;
    % a source-space size change must fail cleanly, not index past / silently wrong.
    tc.verifyEqual(size(sourceJ, 1), nVoxel, ...
        sprintf('%s: voxel count changed (expected %d, got %d).', name, nVoxel, size(sourceJ, 1)));
    if size(sourceJ, 1) ~= nVoxel
        return
    end

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
    tc.verifyLessThan(max(c.nnz5RelErr), 0.05, ...
        sprintf('%s: sparsity (nnz>5%%) diverged (max rel err %.3e).', name, max(c.nnz5RelErr)));
    tc.verifyTrue(all(c.peakMatch), ...
        sprintf('%s: peak voxel moved for component(s) %s.', name, mat2str(find(~c.peakMatch))));

    % fvalJ (normalized residual variance) is an independent axis from sourceJ: a
    % bug in the residual/Vdata handling could leave sourceJ intact, so check it.
    fvalRelErr = abs(out.fvalJ(:) - refFval(:)) ./ max(1e-12, abs(refFval(:)));
    tc.verifyLessThan(max(fvalRelErr), 1e-3, ...
        sprintf('%s: residual variance (fval) diverged (max rel err %.3e).', name, max(fvalRelErr)));
end

function rmIfExists(d)
    if exist(d, 'dir') == 7
        rmdir(d, 's');
    end
end
