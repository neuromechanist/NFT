function [pos, Fd] = initial_registration(elo, F, Cscalp, Fm)

% Author: Zeynep Akalin Acar, SCCN
% Contributor: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026 (extracted into a
%   shared function from the GUI/headless copies; algorithm unchanged)
%
% Copyright (C) Zeynep Akalin Acar, SCCN, zeynep@sccn.ucsd.edu
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

  ne = size(elo,1);
  [P1e, P2e] = find_new_points_for_reg(elo, F);
  [P1m, P2m] = find_new_points_for_reg(Cscalp(:,2:4), Fm);

  % find coarse scaling (x) using F2-F3
  sx = (F(2,:)-F(3,:))/(Fm(2,:)-Fm(3,:)); sx2=abs(1-sx);
  % find coarse scaling (y) using P1-F1
  sy = (P1e-F(1,:))/(P1m-Fm(1,:)); sy2=abs(1-sy);
  % find coarse scaling (z) using P1-P2
  sz = (P1e-P2e)/(P1m-P2m); sz2=abs(1-sz);
  % find the one closest to 1, smallest scaling factor
  [k,l] = min([sx2 sy2 sz2]);
  a = [sx sy sz]; min_sc=a(l);
  % after scaling
  elo2 = elo;
  elo2(:,1) = elo2(:,1) / min_sc;
  elo2(:,2) = elo2(:,2) / min_sc;
  elo2(:,3) = elo2(:,3) / min_sc;
  F2 = elo2(1:3,:);

  [P1e2, P2e2] = find_new_points_for_reg(elo2, F2);

  % find coarse translation using P1e, P1m
  tr = P1e2 - P1m;
  %tr = P2e2 - P2m;
  elo3 = elo2 - ones(length(elo2),1) * tr;
  F3 = F2 - ones(3,1)*tr;

  [P1e3, P2e3] = find_new_points_for_reg(elo3, F3);

  % find the rotation using fiducials and P2
  options = optimset('MaxFunEvals', 100000, 'MaxIter', 100000, 'TolFun',1e-6);
  Xo = [0 0 0];
  X = fminsearch(@(X) funrstPP_rot(X, [F3; P2e3], [Fm;P2m]), Xo, options);
  X2=[0 0 0 X];
  % find the rotated digitizer locations
  [d, elo4] = warping_distafterwarping(X2, elo3, elo3);

  [P1x, P2x] = find_new_points_for_reg(elo4, elo4(1:3,:));
  %pos = elo4(4:ne,:); % don't take fiducials
  pos = elo4; % save with fiducials
  Fd = elo4(1:3,:);
