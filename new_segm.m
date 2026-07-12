function Segm = new_segm(Segm,Vfs);

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
Vbr0 = Segm.brainmask;
Vc0 = Segm.innerskullmask;
Vsk0 = Segm.outerskullmask;
Vsc0 = Segm.scalpmask;

s(1,:) = size(Vfs);
s(2,:) = size(Vbr0);
sz = max(s);

Vfs0 = zeros(sz, 'int8');
Vfs0(1:s(1,1), 1:s(1,2), 1:s(1,3)) = Vfs;

se1 = strel('ball',3, 3);
se = strel('ball', 3, 3, 0);
%se = strel('ball', 3, 3);

% new brain volume not intersecting with FS brain
Vfs2 = imclose3D(Vfs0, se1);
Vfs2 = imdilate3D(int8(Vfs2), se);
Vfs2 = Vfs2 - min(min(min(Vfs2)));
Vbr2 = Vfs2 | Vbr0;
clear Vfs2

% new csf volume not intersecting with brain
Vbr3 = imdilate3D(int8(Vbr2), se);
Vbr3 = Vbr3 - min(min(min(Vbr3)));
Vc2 = Vc0 | Vbr3;
clear Vbr3

% new skull volume not intersecting with csf
Vc3 = imdilate3D(int8(Vc2), se);
Vc3 = Vc3 - min(min(min(Vc3)));
Vsk2 = Vsk0 | Vc3;
clear Vc3

% new skull volume not intersecting with csf
Vsk3 = imdilate3D(int8(Vsk2), se);
Vsk3 = Vsk3 - min(min(min(Vsk3)));
Vsc2 = Vsc0 | Vsk3;
clear Vsk3

% farklara bak
A = int8(Vbr0) - int8(Vbr2);
clear Vbr0
fbr = sum(sum(sum(abs(A))));
A = int8(Vc0) - int8(Vc2);
clear Vc0
fc = sum(sum(sum(abs(A))));
A = int8(Vsk0) - int8(Vsk2);
clear Vsk0
fsk = sum(sum(sum(abs(A))));
A = int8(Vsc0) - int8(Vsc2);
clear Vsc0
fsc = sum(sum(sum(abs(A))));
[fbr fc fsk fsc]
% set the new volumes in Segm structure
Segm.innerskullmask = Vc2;
Segm.outerskullmask = Vsk2;
Segm.brainmask = Vbr2;
Segm.scalpmask = Vsc2;
clear Vsc2 Vbr2 Vsk2 Vc2
% Vfs = mesh2vol2(v5, E1(:,2:4)); % freesurfer brain surface
