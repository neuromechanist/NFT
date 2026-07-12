function [mut, mu,dmu,k,gamma,fval] = sparse_learning_ss(Phi,T,lambda,iters,flag1,flag2,flag3, nofig)
% *************************************************************************
%
% *** PURPOSE ***
% Implements generalized versions of SBL and FOCUSS for learning sparse
% representations from possibly overcomplete dictionaries.
%
%
% *** USAGE ***
% [mu,dmu,k,gamma] = sparse_learning(Phi,T,lambda,iters,flag1,flag2,flag3);
%
%
% *** INPUTS ***
% Phi       = N X M dictionary
% T         = N X L data matrix
% lambda    = scalar trade-off parameter (balances sparsity and data fit)
% iters     = maximum number of iterations
%
% flag1     = 0: fast Mackay-based SBL update rules
% flag1     = 1: fast EM-based SBL update rule
% flag1     = 2: traditional (slow but sometimes better) EM-based SBL update rule
% flag1     = [3 p]: FOCUSS algorithm using the p-valued quasi-norm
%
% flag2     = 0: regular initialization (equivalent to min. norm solution)
% flag2     = gamma0: initialize with gamma = gamma0, (M X 1) vector
%
% flag3     = display flag; 1 = show output, 0 = supress output
%
% *** OUTPUTS ***
% mu        = M X L matrix of weight estimates
% dmu       = delta-mu at convergence
% k         = number of iterations used
% gamma     = M X 1 vector of hyperparameter values
%
%
% *************************************************************************
% Written by:  David Wipf, david.wipf@mrsc.ucsf.edu
% *************************************************************************

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


% *** Control parameters ***
MIN_GAMMA       = 1e-16;  % 1e-4
MIN_DMU         = 1e-12;
MAX_ITERS       = iters;
DISPLAY_FLAG    = flag3;     % Set to zero for no runtime screen printouts


% *** Initializations ***
[N M] = size(Phi);
[N L] = size(T);

if (~flag2)         gamma = ones(M,1);
else                gamma = flag2;  end;

keep_list = [1:M]';
m = length(keep_list);
mu = zeros(M,L);
dmu = -1;
k = 0;

iter=0; % zeynep
fig = 0;
if nargin < 8
   figure
else
    fig=1;
end

% *** Learning loop ***
while (1)
iter=iter+1; % zeynep

    % *** Prune things as hyperparameters go to zero ***
    if (min(gamma) < MIN_GAMMA )
        index = find(gamma > MIN_GAMMA);
        gamma = gamma(index);
        Phi = Phi(:,index);
        keep_list = keep_list(index);
        m = length(gamma);

        if (m == 0)   break;  end;
    end;


    % *** Compute new weights ***
    G = repmat(sqrt(gamma)',N,1);
    PhiG = Phi.*G;
    [U,S,V] = svd(PhiG,'econ');

    [d1,d2] = size(S);
    if (d1 > 1)     diag_S = diag(S);
    else            diag_S = S(1);      end;

    U_scaled = U(:,1:min(N,m)).*repmat((diag_S./(diag_S.^2 + lambda + 1e-16))',N,1);
    Xi = G'.*(V*U_scaled');

    mu_old = mu;
    mu = Xi*T;

    temp = zeros(M,L);
    if (m > 0) temp(keep_list,:) = mu;  end;
    mut(iter,:,:) = temp; % zeynep
    di = ceil(sqrt(iters));
    if fig==0
        subplot(di,di,iter); plot(mu); % zeynep
    end

    pot = Phi * mu;
    diff = T - pot;
    err = sum(diff(:).^2) / sum(T(:).^2);
    fval(iter) = err;

    % *** Update hyperparameters ***
    gamma_old = gamma;
    mu2_bar = sum(abs(mu).^2,2);

    if (flag1(1) == 0)
        % MacKay fixed-point SBL
        R_diag = real( (sum(Xi.'.*Phi)).' );
        te = L*R_diag;
        if min(te) < MIN_GAMMA  % zeynep
            ind_te = find(te<MIN_GAMMA);
            te(ind_te) = MIN_GAMMA;
        end
        gamma = mu2_bar./te;

    elseif (flag1(1) == 1)
        % Fast EM SBL
        R_diag = real( (sum(Xi.'.*Phi)).' );
        gamma = sqrt( gamma.*real(mu2_bar./(L*R_diag)) );

    elseif (flag1(1) == 2)
        % Traditional EM SBL
        PhiGsqr = PhiG.*G;
        Sigma_w_diag = real( gamma - ( sum(Xi.'.*PhiGsqr) ).' );
        gamma = mu2_bar/L + Sigma_w_diag;

    else
        % FOCUSS
        p = flag1(2);
        gamma = (mu2_bar/L).^(1-p/2);
    end;



    % *** Check stopping conditions, etc. ***
    k = k+1;
    if (DISPLAY_FLAG) disp(['iters: ',num2str(k),'   num coeffs: ',num2str(m), ...
            '   gamma change: ',num2str(max(abs(gamma - gamma_old))), ...
            '   fval: ',num2str(err)]); end;

    if (k >= MAX_ITERS) break;  end;

    % zeynep
    if iter>5
    if (abs(fval(iter-1)-fval(iter)) < 0.0001) break; end; % zeynep 6/11/15
    end
    %

    if (size(mu) == size(mu_old))
        dmu = max(max(abs(mu_old - mu)));
        if (dmu < MIN_DMU)  break;  end;
    end;

end;


% *** Expand weights, hyperparameters ***
temp = zeros(M,1);
if (m > 0) temp(keep_list,1) = gamma;  end;
gamma = temp;

temp = zeros(M,L);
if (m > 0) temp(keep_list,:) = mu;  end;
mu = temp;

return;
