function [J_esmtime, Jt, fval]  = source_loc_SBL_gaus_function(p,ss_MNI_3_gaus,ss_MNI_6_gaus,ss_MNI_10_gaus,LFM_MNI_sourcespaceNn,max_inter,nsr_lv, flag1)
% SOURCE_LOC_SBL_GAUS_FUNCTION
%   Sparse Bayesian Learning (SBL) cortical current estimate for one scalp map.
%
%   [J, Jt, fval] = source_loc_SBL_gaus_function(p, ss_MNI_3_gaus, ss_MNI_6_gaus, ...
%                       ss_MNI_10_gaus, LFM, max_inter, nsr_lv, flag1)
%
%   Estimates the cortical current for scalp map p by sparse Bayesian learning
%   (gamma-MAP / automatic relevance determination; Wipf & Rao) over a
%   MULTI-RESOLUTION Gaussian patch dictionary. Each of the 3, 6 and 10 mm patch
%   matrices is row-normalized and used to map the lead field into its patch basis
%   (New_lfm = LFM * ss_spnorm); the three patch lead fields are concatenated
%   (lfm3 = [10mm 6mm 3mm]) so the solver can place activity at whichever cortical
%   scale best explains the data. sparse_learning_ss learns a sparse set of active
%   patch weights, which are mapped back to per-voxel current by J = ssx * weights.
%   Contrast with the SCS solver above, which uses a single-scale kernel and a
%   correlation-variance prior; SBL here is multi-scale with a diagonal (ARD) prior.
%
%   Inputs
%     p                    observed scalp potential for one map.
%     ss_MNI_3/6/10_gaus   Gaussian cortical-patch matrices at 3 / 6 / 10 mm radius.
%     LFM_MNI_sourcespaceNn lead-field matrix (already restricted to used electrodes).
%     max_inter            max SBL iterations.
%     nsr_lv               noise-to-signal level (noise-variance prior).
%     flag1                0 -> fast MacKay, 1 -> fast EM, 2 -> traditional EM update
%                          rules (see sparse_learning_ss). The caller passes 0, so
%                          this path runs the fast MacKay update, not EM.
%
%   Outputs
%     J_esmtime            estimated cortical current [n_voxel x 1] (final iteration).
%     Jt                   current at each SBL iteration.
%     fval                 solver objective trace.

% Copyright (C) Zeynep Akalin Acar, SCCN, zeynep@sccn.ucsd.edu
% Contributor: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026 (extracted into a
%   shared function from the DSL inverse solver; algorithm unchanged)
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

% flag1 = 0 -> fast MacKay, 1 -> fast EM, 2 -> traditional EM (see sparse_learning_ss)

if nargin < 8
    flag1 = 0; % EM
end


LFM = LFM_MNI_sourcespaceNn;
%nsr_lv=0.0001;

ss_10 = sum(ss_MNI_10_gaus,2);
ss_6 = sum(ss_MNI_6_gaus,2);
ss_3 = sum(ss_MNI_3_gaus,2);
ss_10_spnorm = ss_MNI_10_gaus';
ss_6_spnorm = ss_MNI_6_gaus';
ss_3_spnorm = ss_MNI_3_gaus';
ii = length(ss_10);
for i = 1:ii;
    ss_10_spnorm(:,i) = ss_10_spnorm(:,i) / ss_10(i);
    ss_6_spnorm(:,i) = ss_6_spnorm(:,i) / ss_6(i);
    ss_3_spnorm(:,i) = ss_3_spnorm(:,i) / ss_3(i);
end
ss_10_spnorm = ss_10_spnorm';
ss_6_spnorm = ss_6_spnorm';
ss_3_spnorm = ss_3_spnorm';

New_lfm_10n = LFM * ss_10_spnorm;
New_lfm_6n = LFM * ss_6_spnorm;
New_lfm_3n = LFM * ss_3_spnorm;

%lfm2 = [New_lfm_10 New_lfm_6 New_lfm_3];
lfm3 = [New_lfm_10n New_lfm_6n New_lfm_3n];
ssx = [ss_10_spnorm' ss_6_spnorm' ss_3_spnorm'];

clear New_lfm_* ss_* LFM


[mut3,mu,dmu,kk,gamma,fval] = sparse_learning_ss(lfm3, p, nsr_lv, max_inter, flag1, 0, 0, 1); % EM

itern = size(mut3,1);
vn = mut3(itern,:);
J_esmtime = ssx * vn';
Jt = ssx * mut3';
