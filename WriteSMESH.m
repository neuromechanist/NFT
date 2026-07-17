function WriteSMESH(name,Coord,Elem,Regions)
  % Saves the mesh in .SMESH format for use with Tetgen
  % The format is described in:
  % http://tetgen.berlios.de/fformats.html
  % The .smesh format is slightly simpler than more general .poly
  % The Regions parameter must specify a point inside each region
  % TetGen will mark output tetrahedra using these region markers

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

  nnp=size(Coord,1);
  nel=size(Elem,1);
  if ~isempty(Regions)
    nreg = size(Regions,1);
    Reg = zeros(nreg, 6);
    Reg(:,2:4) = Regions;
    Reg(:,1) = 1:nreg;
    Reg(:,5) = 1:nreg;
    Reg(:,6) = -1;
  else
    nreg = 0;
    Reg = [];
  end

  % make sure Node indices are correct
  Coord(:,1) = 1:nnp;

  fid=fopen(name, 'w');

  fprintf(fid, '# Part 1 - node list\n');
  fprintf(fid, '# node count, 3 dim, no attr, no boundary \n');
  fprintf(fid, '%d 3 0 0\n', nnp);
  fprintf(fid, '# Node index, node coordinates\n');
  fprintf(fid, '%f %f %f %f\n',Coord');

  fprintf(fid, '# Part 2 - facet list\n');
  fprintf(fid, '# facet count, no boundary marker\n');
  fprintf(fid, '%d\n',nel);
  fprintf(fid, '# facets\n');
  fprintf(fid, '3 %d %d %d\n', Elem(:,2:4)');

  fprintf(fid, '# Part 3 - hole list\n');
  fprintf(fid, '0            # no hole\n');

  fprintf(fid, '# Part 4 - region list\n');
  fprintf(fid, '%d\n', nreg);

  if nreg > 0
    fprintf(fid, '%d %f %f %f %d %d\n', Reg');
  end

  fclose(fid);
