classdef BinaryCanaryTest < matlab.unittest.TestCase
    %BINARYCANARYTEST Guard that the compiled BEM/warping binaries exist & run.
    %
    %   Asserts the BEM/warping-pipeline binaries reported by nft_get_config
    %   resolve to real, executable files on the current platform. This catches a
    %   binary going missing or losing its executable bit -- a common silent
    %   breakage when checking out/repacking the repo. The checked set is a
    %   superset of what any single test exercises (e.g. asc/qslim/tetgen are used
    %   by mesh generation and bem_matrix by the forward step, not by the
    %   femmesh=0 warp itself); guarding all of them is the safe direction.
    %
    %   It does NOT invoke the binaries: several require input files, and on Linux
    %   the paths are wrapper scripts that exit 0 on an unmatched architecture, so
    %   an exit code would be misleading. The end-to-end WarpingSmokeTest exercises
    %   the binaries for real.

    methods (TestClassSetup)
        function addRepoToPath(tc)
            % nft_get_config and the shipped binaries live in the repo root, one
            % level up from this tests/ folder. Put it on the path so the check
            % resolves regardless of the current folder or how the suite is run.
            % (Inside a function, calls resolve via the path, not the cwd.)
            repoRoot = fileparts(fileparts(which(class(tc))));
            addpath(repoRoot);
        end
    end

    methods (Test)
        function warpingPathBinariesPresent(tc)
            [ok, missing] = nft_binaries_present();
            tc.verifyTrue(ok, ...
                sprintf('Missing/inexecutable warping binaries: %s', strjoin(missing, ', ')));
        end

        function femBinariesLinuxOnly(tc)
            % quadmesh / lin2quad / forward ship Linux-only in the repo today;
            % macOS/Windows FEM builds are Phase B4 (issue #3). Elsewhere they are
            % known-missing: report, do not fail.
            conf = nft_get_config();
            femFields = {'metufem', 'quad', 'lin2quad'};
            for i = 1:numel(femFields)
                p = conf.(femFields{i});
                present = exist(p, 'file') == 2;
                if isunix && ~ismac
                    tc.verifyTrue(present, ...
                        sprintf('Missing FEM binary conf.%s: %s', femFields{i}, p));
                elseif ~present
                    tc.log(1, sprintf('Known-missing (issue #3, Phase B4) conf.%s: %s', femFields{i}, p));
                end
            end
        end
    end
end
