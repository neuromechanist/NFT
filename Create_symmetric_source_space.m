function [so, ss] = Create_symmetric_source_space(Coord, Elem, spacing, thr);

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

ma = max(Coord(:,2:4));
mi = min(Coord(:,2:4));
md = round((ma - mi)/spacing);

n=0;
for i=1:md(1)+1
    a(i) = mi(1)+spacing*(i-1)-spacing/2;
    for j=1:md(2)+1
        b(j) = mi(2)+spacing*(j-1)-spacing/2;
        for k=1:md(3)+1
            c(k) = mi(3)+spacing*(k-1)-spacing/2;
            n=n+1;
            ss(n,1:3)=[a(i) b(j) c(k)];
        end
    end
end

% symmetry according to y axis
smy = (max(Coord(:,3))+min(Coord(:,3)))/2;

ksmy = find(ss(:,2) > smy);
ss1 = ss(ksmy,:);
ss2 = ss1;
ss2(:,2) = -ss2(:,2);
ss2(:,2) = ss2(:,2)+smy*2;

[dim1, inm1] = utilmesh_check_source_space(ss1, Coord, Elem);
[dim2, inm2] = utilmesh_check_source_space(ss2, Coord, Elem);


k = find(inm1 == 1);   % dipoles inside the mesh
l = find(dim1 < thr);  % dipoles closer to the mesh less than thr
m1 = setdiff(k, l);    % dipoles inside the mesh, closer to the mesh less than thr

k = find(inm2 == 1);   % dipoles inside the mesh
l = find(dim2 < thr);  % dipoles closer to the mesh less than thr
m2 = setdiff(k, l);    % dipoles inside the mesh, closer to the mesh less than thr

mi = intersect(m1,m2);

ss1 = ss1(mi,:);
ss2 = ss2(mi,:);

% first Ns y directed dipoles
Ns = size(ss1, 1);
so1 = zeros(3*Ns, 6);
so1(1:Ns, 1:3) = ss1;
so1(1:Ns, 4) = 1;
so1(1+Ns:2*Ns, 1:3) = ss1;
so1(1+Ns:2*Ns, 5) = 1;
so1(1+Ns*2:3*Ns, 1:3) = ss1;
so1(1+Ns*2:3*Ns, 6) = 1;

% second Ns dipoes are the symmetric ones
so2 = zeros(3*Ns, 6);
so2(1:Ns, 1:3) = ss2;
so2(1:Ns, 4) = 1;
so2(1+Ns:2*Ns, 1:3) = ss2;
so2(1+Ns:2*Ns, 5) = -1;
so2(1+Ns*2:3*Ns, 1:3) = ss2;
so2(1+Ns*2:3*Ns, 6) = 1;

so = [so1;so2];
