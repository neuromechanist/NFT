% nft_dsl_inverse_problem_solution() - Distributed source localization
% (dsl) forward model generation
%
% Usage:
%   >> nft_dsl_inverse_problem_solution(subject_name, session_name, of)
%
% Inputs:
%   subject_name - subject name as entered in NFT main window
%   session_name - session name as entered in NFT main window
%   of - output folder where all the outputs are saved
%
% Optional keywords:
%
%   cond : conductivity vector (default = [0.33 0.0132 1.79 0.33])
%   mesh_name : mesh name that will be loaded (default: [subject_name '.1.msh'])
%   sensor_name:  sensor name (default: [subject_name '_' session_name '.sensors'])
%   ss_name : sourcespace name (default: [subject_name '_sourcespace.dip'])
%   LFM_name :  LFM name (default: session_name_LFM)
%
% Author: Zeynep Akalin Acar, SCCN, 2021
% Contributor: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026

% Copyright (C) 2007 Zeynep Akalin Acar, SCCN, zeynep@sccn.ucsd.edu
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

function nft_dsl_inverse_problem_solution(subject_name, session_name, of, EEG, comp_index, selection, sensor_file)

% selection = 2 -> SBL
% selection = 3 -> SCS


% start source localization
curr_dir = pwd;
cd(of)


Phi_EEG = EEG.icawinv(:,comp_index);
ndip = length(comp_index);

% Solve distributed source loc for all models
sens = load(sensor_file, '-mat');
[ind_fp, ind_eeg] = find_indexes(EEG, sens.ind, sens.eloc);
Phi_EEG = Phi_EEG(ind_eeg,:);

LFM_name = [session_name '_LFM'];
% Explicit struct-field loads (not dynamic `load X`) so the parfor loops below
% recognize these as variables rather than functions on the path.
lfmS  = load(LFM_name);
LFM2  = lfmS.LFM(ind_fp,:);
ss10S = load('ss_g10');    ss_g10 = ss10S.ss_g10;
fsS   = load('FSss_cor');  Css    = fsS.Css;      % source space
naS   = load('Node_area'); An     = naS.An;
max_scs_iter = 25;

% Preallocate outputs (required for the parfor sliced assignment below) and start a
% parallel pool of up to 8 workers when the Parallel Computing Toolbox is available.
% Each component's solve is fully independent, so a parfor over components saturates
% cores with no change to the (order-independent) result; parfor degrades to a plain
% serial loop when no pool/toolbox is present, so behavior is identical either way.
nComp   = size(Phi_EEG, 2);
sourceJ = zeros(size(LFM2, 2), nComp);
fvalJ   = zeros(1, nComp);
if nComp > 1 && ~isempty(ver('parallel')) && isempty(gcp('nocreate'))
    try
        parpool(min(8, feature('numcores')));
    catch poolErr
        warning('NFT:dsl:noPool', 'Parallel pool unavailable (%s); running serially.', poolErr.message);
    end
end

if selection == 2
    % SBL
    ss6S = load('ss_g6'); ss_g6 = ss6S.ss_g6;   % explicit (parfor-visible)
    ss3S = load('ss_g3'); ss_g3 = ss3S.ss_g3;
    disp('SBL source localization started...')
    parfor ij = 1:nComp
        Vdata = Phi_EEG(:,ij);
        Vdata = Vdata - mean(Vdata);

        Jb = source_loc_SBL_gaus_function(Vdata, ss_g3, ss_g6, ss_g10, LFM2, 4, 0.001, 0);
        sourceJ(:,ij) = Jb;

        pot = LFM2 * Jb; pot = pot - mean(pot);
        diff = Vdata - pot;
        fvalJ(ij) = sum(diff(:).^2) / sum(Vdata(:).^2);

    end
    save cortex_source_sbl sourceJ fvalJ comp_index
    disp('SBL source localization finished...')

elseif selection == 3
    % SCS: for each independent component's scalp map, run the SCS solver (which
    % emits a sequence of increasingly sparse current estimates), then keep the
    % single most spatially COMPACT iterate as that component's cortical source.
    disp('SCS source localization started...')
    parfor ij = 1:nComp
        Vdata = Phi_EEG(:,ij);
        Vdata = Vdata - mean(Vdata);
        [Js1, Jit, fvx] = inverse_cov_sparse_average_noise_whole18_sparse_patchz2(LFM2, Vdata, ss_g10, max_scs_iter, 0);

        % Score each iterate's spatial compactness (calc_compactness, Zunic method)
        % and select the most compact. Jit(:,1) is an unwritten zero placeholder and
        % iterates 2-4 are early/diffuse, so the search starts at index 5; the +4
        % restores the true index.
        compact0iter = zeros(1, max_scs_iter+1);   % per-iteration temporary (parfor)
        for comi = 1:max_scs_iter+1
            pot = Jit(:,comi); pot = pot';
            compact0iter(comi) = calc_compactness(pot, An, Css(:,2:4), 1);
        end
        [maxcom, maxcomi] = max(compact0iter(5:max_scs_iter+1));
        maxcomiter = maxcomi + 4;

        sourceJ(:,ij) = Jit(:,maxcomiter);

        pot = LFM2 * Js1; pot = pot - mean(pot);
        diff = Vdata - pot;
        fvalJ(ij) = sum(diff(:).^2) / sum(Vdata(:).^2);
    end
    save cortex_source_scs sourceJ fvalJ comp_index
    disp('SCS source localization finished...')
end

cd(curr_dir)

