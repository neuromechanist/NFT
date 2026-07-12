function [J,Jit, fval,stdd_log_a,J_s,dispact_s,prob_ts] = inverse_cov_sparse_average_noise_whole18_sparse_patchz2(F,P,ss_MNI_gaussion,max_it,flag)

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

% INVERSE_COV_SPARSE_AVERAGE_NOISE_WHOLE18_SPARSE_PATCHZ2
%   Sparse, Compact and Smooth (SCS) cortical current estimate for one scalp map.
%
%   [J, Jit, fval] = inverse_cov_sparse_average_noise_whole18_sparse_patchz2( ...
%                        F, P, ss_MNI_gaussion, max_it, flag)
%
%   Solves the underdetermined EEG inverse problem P = F*J + n for the cortical
%   current J using the correlation-variance gamma-MAP model of Cao, Akalin Acar,
%   Kreutz-Delgado & Makeig, "A physiologically motivated sparse, compact, and
%   smooth (SCS) approach to EEG source localization" (2012 IEEE EMBC; bib key
%   Cao2012APM in docs/references/nft-references.bib). Equation numbers below refer
%   to that paper.
%
%   Model. The source covariance is factored (Eq. 9) as
%       Sigma_d = V^(1/2) R V^(1/2),   V = diag(sigma_i^2),
%   where R = H*H' is a FIXED cortical correlation/smoothing matrix encoding the
%   "compact and smooth" prior (paper Section III), and the per-source variances
%   sigma_i encode sparsity and are learned from the data. Here ss_MNI_gaussion
%   plays the role of the square-root factor H: R is never formed explicitly; the
%   code builds M = F*diag(sigma)*ss*ss'*diag(sigma)*F' = F*Sigma_d*F'. NOTE that
%   ss_MNI_gaussion is built (ss_cortex_gaus.m) as a truncated Gaussian of GEODESIC
%   cortical distance -- a different parameterization than the paper's logistic H
%   (Eq. 11-12), but the same compact/smooth prior. The scalp-data covariance is
%       Sigma_p = F Sigma_d F' + Sigma_n                                   (Eq. 6).
%   The log-variances are learned by hyperparameter-MAP, minimizing
%       L = log|Sigma_p| + m*log(P' inv(Sigma_p) P)                        (Eq. 18)
%   by steepest descent with an adaptive two-point (Barzilai-Borwein) step size:
%   the log-domain reparametrization and hyperplane projection are Eq. 19-26, and
%   the two-point step itself is Eq. 27-28. Given the current variances, the
%   current is the MAP estimate d_hat = Sigma_d F' inv(Sigma_p) P          (Eq. 7),
%   recomputed and stored at every iteration.
%
%   Inputs
%     F               lead-field (gain) matrix, [n_electrode x n_voxel]. Internally
%                     average-referenced (mean removed, last row dropped) and its
%                     columns normalized.
%     P               observed scalp potential for one map, [n_electrode x 1].
%     ss_MNI_gaussion square Gaussian cortical-patch matrix (the H factor above),
%                     [n_voxel x n_voxel] (e.g. the 6 or 10 mm ss_g* dictionary).
%     max_it          number of gradient iterations.
%     flag            1 also records the per-iteration current in J_s (diagnostic);
%                     0 skips it (the value used by the SCS caller).
%
%   Outputs
%     J               final MAP current estimate, [n_voxel x 1].
%     Jit             current at each iteration, [n_voxel x (max_it+1)]. Column 1 is
%                     an unwritten zero placeholder (n_it is incremented before the
%                     store), so iterations populate columns 2..max_it+1; the SCS
%                     caller selects the most spatially compact of these.
%     fval            per-iteration normalized data residual, computed in the
%                     function's internal (average-referenced, unit-column-norm) F/P
%                     space on J before its final rescale -- not the raw inputs.
%
%   Code <-> paper. exp(stdd_log_a) = sigma (source std; phi = log sigma);
%   exp(nsr_level) = noise level (eta); M = Sigma_p; prob = P' inv(M) P;
%   prob_t = the cost L plus a small hyperparameter-control penalty (n_control_para
%   term) not in the paper; g_k = the gradient (reassigned/projected mid-loop for the
%   Eq. 24-26 hyperplane constraint); step_size = the two-point step.
%
%   --- Original development notes (Cheng Cao, 2011-2012), preserved verbatim: ---
%   %J=inverse_cov_sparse_average(F,P,voxel_position)
%   %F is the lead fied matrix, P is the observed scalp potential and
%   % ss_MNI_gaussion for 6mm or 10mm; max_it = 30, 20; flag = 1
%   %voxel_position is the locatoin of the dipoles; Edited by Cheng Cao 2011
%   % A compact function is added; the covariance matrix is updated
%   %Parallel computation is used; modified based on version 7, keep hidden elements
%   %dealt with the noise issue, considering the DC shift of the noise
%   %Using two-point stepsize gradient; Use log(std) to achieve better performance
%   %form version 10; set the initial nsr_level according to the eigen value of M
%   %Under development; Add smooth matrix Mar21,2012 smooth_control; pinv->inv Mar 22

% initialize
[rt,ty] = size(F);
fval = zeros(1,max_it+1);
Jit = zeros(ty,max_it+1);

stop = 1;
step_size = 0.01; %0.01;
minium_nsr = 0.1; %0.1
n_control_para = 0.00001;
p_std_cof = 0;
nsr_coefi = 0.00005; %0.001;%0.01
%nsr_coefi = 0.1; %0.001;%0.01

[number_electrode,number_voxel] = size(F);
smooth_control = 0.1;
J_s = [];
dispact_s = [];
J = ones(number_voxel,1);
prob_ts = [];
MIN_GAMMA = 1e-16;

P = P - mean(P);
P = P(1:number_electrode-1);
P_norm = norm(P);
P = P / P_norm;

F = F - ones(number_electrode,1) * mean(F);
F = F(1:number_electrode-1,:);
F_norms_sqr = (sum(F.^2))';

for i = 1:number_voxel
    F(:,i) = F(:,i)*((F_norms_sqr(i)).^-0.5);
end

F_e = zeros(number_electrode-1,number_electrode-1);
F_e = F_e-1 / number_electrode;


for i = 1:number_electrode-1
    F_e(i,i) = F_e(i,i)+1;
end

F_e = F_e / norm(F_e(:,1));

M = zeros(number_electrode-1,number_electrode-1);
N = zeros(number_voxel,1);
cov_column = zeros(number_voxel,1);
voxel_position_a = zeros(number_voxel,1);
pre_decompact = inf;

stdd_log_a = zeros(number_voxel,1);
nsr_level = zeros(number_electrode-1,1);
stdd_log_a = stdd_log_a+p_std_cof*log(F_norms_sqr)-0.1*log(min(F_norms_sqr));
n_it = 1;
err = zeros(1,number_electrode-1);

g_k = zeros(number_voxel+number_electrode-1,1);
g_k_old = g_k;
stdd_log_old = stdd_log_a;
nsr_level_old = nsr_level;
prob = 0;

J_index = 1:number_voxel;
number_a_voxel = number_voxel;
F_a = F;
n_itt = 1;

ss_matrix = ss_MNI_gaussion;
for i=1:number_voxel
    ss_MNI_gaussion(:,i) = ss_matrix(:,i) / sqrt(sum(ss_matrix(:,i).^2));
end
ss_MNI_gaussion = ss_MNI_gaussion';


while stop && n_it <= max_it

    row_temp = zeros(number_electrode-1,number_voxel);
    ss_diag_diag = sparse(1:number_voxel,1:number_voxel,exp(stdd_log_a));

    row_temp = F_a * ss_diag_diag * ss_MNI_gaussion;
    M = row_temp * row_temp';
    a1 = isnan(M);
    if sum(sum(a1))>1
        break
    end
    [~,D_m] = eig(M);
    if n_it == 1
        lam_max = max(diag(D_m));
        nsr_level_init = nsr_coefi*mean(diag(D_m));%Changed on Mar 19 2012
        scale = minium_nsr/nsr_level_init;

        M = scale * M;
        row_temp = row_temp*sqrt(scale);
        stdd_log_a = stdd_log_a+0.5*log(scale);
        nsr_level = zeros(number_electrode-1,1)+log(minium_nsr)/2;
    end
    snr = mean(diag(D_m)) / exp(2*mean(nsr_level));
    M = M + F_e * diag(exp(2*nsr_level)) * F_e';
    [~,D_m]=eig(M);
    c_M = cond(M);
    min_eigv = min(diag(D_m));
    prob = P' * inv(M) * P;
    prob_t = (number_electrode-1) * log(P'*inv(M)*P) - log(det(inv(M))) - n_control_para * (mean(stdd_log_a) + mean(nsr_level));%%add the noise control;
    prob_ts = [prob_ts,prob_t];
    inv_M = inv(M);

    ss_diag_diag=sparse(1:number_voxel,1:number_voxel,exp(stdd_log_a));

    %%%%%%%%%%%%% calculate the current %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if flag == 1
        N = F_a' * inv(M) * P;
        J_tmp = zeros(number_voxel,1);
        J_tmp = (ss_diag_diag*ss_MNI_gaussion)' * N;
        J = ss_diag_diag * ss_MNI_gaussion * J_tmp;
        rv = std(F*J-P)
        J = P_norm*J./sqrt(F_norms_sqr);

        if n_it > 1
            trange_J = norm(J-J_s(:,end)) / norm(J)
        end
        J_s = [J_s, J];
    end

    %%%%%%%%%%% starts to calcualte the gradient %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    g_k = [];
    trace_inM = diag(inv_M);
    cov_init = (ss_MNI_gaussion);
    temp_PM=P'*inv_M;

    temp_PM_F=temp_PM*F;
    temp_cov_rowtemp_temp_PM=cov_init*row_temp'*temp_PM';
    g_1=-(number_electrode-1)*(2*temp_PM_F'.*temp_cov_rowtemp_temp_PM.*exp(stdd_log_a))/(prob);

    %temp_cov_rowtemp=cov_init*row_temp';
    temp_cov_rowtemp=row_temp*cov_init';
    g_2=sum(inv_M*F.*temp_cov_rowtemp);

    g_3=sum(inv_M*temp_cov_rowtemp.*F);
    g_k=[g_k;g_1+(g_3+g_2)'.*exp(stdd_log_a)];
    g_k=g_k+n_control_para/(number_voxel);

    for i=number_a_voxel+1:number_a_voxel+number_electrode-1
        ro_temp=zeros(1,number_electrode-1);
        ro_temp(i-number_a_voxel)=1;
        g_k(i)=-2*(number_electrode-1)*P'*inv_M*F_e*diag(ro_temp)*F_e'*inv_M*P*(exp(2*nsr_level(i-number_a_voxel)))/(prob)+2*trace(inv_M*F_e*diag(ro_temp)*F_e')*(exp(2*nsr_level(i-number_a_voxel)))-n_control_para/(number_electrode);
    end

    %fprintf('finished the calucation of the gradient\n');
    %%%%%%%%%%%%%%%%% transfer the gradient %%%%%%%%%%%%%%%%%%%%%%%%
    g_k_t=[];
    cov_init=ss_MNI_gaussion;
    g_k_t=[g_k_t;cov_init*g_k(1:number_voxel)];
    g_k_t=[g_k_t;g_k(number_a_voxel+1:end)];
    norm(g_k_t);
    surface_norm = ones(number_voxel,1);
    surface_norm = surface_norm/norm(surface_norm);

    g_k_t = g_k_t-mean(g_k_t);
    g_k = g_k'*g_k_t*g_k_t / (norm(g_k_t))^2;

    if n_itt >= 3
        step_size = min(0.5*sqrt(((stdd_log_a-stdd_log_old)'*(stdd_log_a-stdd_log_old)+(norm(nsr_level-nsr_level_old))^2)/((g_k-g_k_old)'*(g_k-g_k_old))),1000);
    end

    stdd_log_old = stdd_log_a;
    nsr_level_old = nsr_level;

    stdd_log_a = stdd_log_a-step_size*g_k(1:number_voxel);
    nsr_level = nsr_level-step_size*g_k(number_voxel+1:end);

    M = zeros(number_electrode,number_electrode);

    g_k_old = g_k;
    n_it = n_it+1;
    n_itt = n_itt+1;
    %fprintf('%d iter  %d voxels used snr_level= %d current gradient',n_it-1,number_a_voxel,max(exp(nsr_level)),norm(g_k));
    std_max = max([stdd_log_a;nsr_level]);
    if std_max> 5
        nsr_level = nsr_level-std_max+1;
        stdd_log_a = stdd_log_a-std_max+1;
        stdd_log_old = stdd_log_old-std_max+1;
        nsr_level_old = nsr_level_old-std_max+1;
        %fprintf('sum of std changed\n');
    end
    if norm(g_k) < 0.5   %||isinf(abs(prob_t))
        %stop = 0;
    end

   if norm(g_k) > 1000  % zeynep singular matrix oluyor
        stop = 0;
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    ss_diag_diag = sparse(1:number_voxel,1:number_voxel,exp(stdd_log_a));
    row_temp = zeros(number_electrode-1,number_voxel);

    cov_init = ss_MNI_gaussion;
    cov_init = ss_diag_diag*cov_init;

    row_temp = F_a * cov_init;
    M = row_temp * row_temp';
    M = M + F_e * diag(exp(2*nsr_level)) * F_e';
    N = F_a' * inv(M) * P;

    J_tmp = zeros(number_voxel,1);
    J_tmp = cov_init' * N;
    J = cov_init*J_tmp;

    err = F*J - P;
    fval(n_it) = sum(err(:).^2) / sum(P(:).^2);
    J = P_norm*J./sqrt(F_norms_sqr);
    Jit(:,n_it) = J;

end
J_s = [J_s,J];
