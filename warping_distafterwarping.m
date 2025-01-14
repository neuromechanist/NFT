% warping_distafterwarping() - Finds the distance between two point sets after
%                 rotation and translation
%
%
% Usage:
%   >> [d, Pnew] = warping_distafterwarping(X, F, Fe);
%
% Inputs:
%   F  - first point set
%   Fe - second point set
%   X  - translation and rotations
%
% Outputs:
%   d    - total distance
%   Pnew - point set after translation and rotation of F
%
%
% Author: Zeynep Akalin Acar, SCCN, 2008

% Copyright (C) 2007 Zeynep Akalin Acar, SCCN, zeynep@sccn.ucsd.edu
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

function [d, Pnew] = warping_distafterwarping(X, F, Fe);
% F is the point set of the digitizer
% d is the distance between translated and rotated F and Fe
% X is the vector of translation and rotation parameters

tx = X(1);
ty = X(2);
tz = X(3);
alpx = X(4) * pi / 180;
alpy = X(5) * pi / 180;
alpz = X(6) * pi / 180;

x = F(:,1);
y = F(:,2);
z = F(:,3);

% rotation around x-axis
x1 = x;
y1 = y*cos(alpx) - z * sin(alpx);
z1 = y*sin(alpx) + z * cos(alpx);

% rotation around y-axis
x2 = z1 * sin(alpy) + x1 * cos(alpy);
y2 = y1;
z2 = z1 * cos(alpy) - x1 * sin(alpy);

% rotation around z-axis
x3 = x2 * cos(alpz) - y2 * sin(alpz);
y3 = x2 * sin(alpz) + y2 * cos(alpz);
z3 = z2;

% translation
x4 = x3 + tx;
y4 = y3 + ty;
z4 = z3 + tz;

Pnew = [x4 y4 z4];

N = size(Fe,1);

Ma = Fe - [x4 y4 z4];
d = sqrt(sum(Ma.*Ma,2));

