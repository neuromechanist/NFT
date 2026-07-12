function [N, M] = element_normals(Coord, Elem)

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

if size(Elem,2)==7

n1 = Coord(Elem(:,2),2:4);
n2 = Coord(Elem(:,4),2:4);
n3 = Coord(Elem(:,6),2:4);
elseif size(Elem,2)==4
n1 = Coord(Elem(:,2),2:4);
n2 = Coord(Elem(:,3),2:4);
n3 = Coord(Elem(:,4),2:4);
end

M = (n1 + n2 + n3) / 3;

n1 = n1 - n3;
n2 = n2 - n3;

N = cross(n1, n2);


for i=1:size(Elem,1)
    N(i,:)=N(i,:)/norm(N(i,:));
end
