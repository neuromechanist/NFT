function N=findNeigNodes(Coord,Elem,n);
% find the neighbour nodes of the nth node of the mesh

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

nop=size(Elem,2);
% find the neighbouring elements
if nop==4
    E=[];
    for i=1:length(n)
        E2=find(Elem(:,2)==n(i) | Elem(:,3)==n(i) | Elem(:,4)==n(i));
        E = union(E,E2);
    end

    f=Elem(E,2:4);
    N=unique(f(:));

elseif nop==7
    E=[];
    for i=1:length(n)
        E2=find(Elem(:,2)==n(i) | Elem(:,3)==n(i) | Elem(:,4)==n(i) | Elem(:,5)==n(i) | Elem(:,6)==n(i) | Elem(:,7)==n(i));
        E = union(E,E2);
    end

    f=Elem(E,2:7);
    N=unique(f(:));
end
