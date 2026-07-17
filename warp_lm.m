function [rw]=warp_lm(r,A,W,p)
% performs warp transformation with linear 3D RFB see Ermer's Thesis

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

  rw = r * A(1:3,1:3) + repmat(A(4,:), size(r,1), 1);
  for i = 1 : size(p,1)
    U = sqrt(sum((r - repmat(p(i,:), size(r,1),1)).^2, 2));
    rw = rw + U * W(i,:);
  end
