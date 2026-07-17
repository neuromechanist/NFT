function [P1, P2] = find_new_points_for_reg(elo,F)
  % elo is the digitizer location (ne x 3)
  % F is the fiducials (3 x 3)
  %     1st row nasion
  %     2nd row LPA
  %     3rd row RPA
  % P1 is the mean for the ear fiducials
  % P2 is the upper point of the line that is perpendicular to the F1-F2-F3 plane
  %       that intersects the digitizer locations

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

  ne = length(elo); % number of electrodes

  F1 = F(1,:); % nasion
  F2 = F(2,:); % LPA
  F3 = F(3,:); % RPA


  % P1 is the mean point of ear fiducials
  P1 = (F2 + F3) / 2;

  % plane equation for F1-F2-F3
  AB = F2 - F1;
  AC = F3 - F1;
  n = cross(AB,AC); nz=n(3);
  % find the line equation perperdicular to F1-F2-F3 plane r(t)
  max_d = max(elo(:,3))/nz*2;
  min_d = min(elo(:,3))/nz;
  incr = (max(elo(:,3))-min(elo(:,3)))/nz/100;
  t = min_d:incr:max_d;
  r = ones(length(t),1)*P1 + t'*n; %in terms of t

  % find the closest electrode point to r
  for i=1:ne
    p1 = elo(i,:);
    M = r - ones(length(t),1)*p1;
    M = sqrt(sum(M.*M,2));
    [k,l] = min(M);
    dis(i,1) = k; % minimum distance
    dis(i,2) = l; % index of r
  end

  [k,l] = min(dis(:,1));

  rm = dis(l,2); %the index of closest point on r
  P2 = r(rm,:);
