% segm_outer_skull() - Performs outer skull segmentation
%
% Usage:
%   >> [Sk_out, X_dark] = Segm_Outer_skull(b, Sca, Bra, sli_eyes);
%
% Inputs:
%   b - imput image (filtered MR image)
%   Sca - Scalp mask
%   Bra - Brain mask
%   sli_eyes - slice of the eyes
%
% Outputs:
%   Sk_out - outer skull mask
%   X_dark - dark regions of b
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

function [Sk_out, X_dark,thr] = Segm_Outer_skull(b, Sca, Bra, sli_eyes, eyes);

% outer skull extraction
%
% Inputs:
%   b        - filtered volume
%   Sca      - scalp mask
%   Bra      - brain mask
%   sli_eyes - coronal slice index on which the eyes are marked
%   eyes     - OPTIONAL 2x2 [x1 y1; x2 y2] eye seed points on slice
%              sli_eyes. When omitted or empty, the eyes are marked
%              interactively with ginput, exactly as before. Supplying them
%              makes this function runnable headlessly (no display), which is
%              what lets the whole segmentation pipeline run from a script,
%              in CI, or on a cluster.
%
% Outputs:
%   Sk_out   - outer skull mask
%   X_dark   - dark-voxel mask used for the eye region growing
%   thr      - threshold used to form X_dark
 %save segmsk b Sca Bra sli_eyes
% structuring elements
C1 = ones(3,3,3);
R1 = zeros(3,3,3); R1(2,2,:) = 1; R1(1,2,2) = 1; R1(2,1,2) = 1; R1(3,2,2) = 1; R1(2,3,2) = 1;
O2 = ones(5,5,5); O2(1,5,:) = 0; O2(1,1,:) = 0; O2(5,5,:) = 0; O2(5,1,:) = 0;
                  O2(1,:,5) = 0; O2(1,:,1) = 0; O2(5,:,5) = 0; O2(5,:,1) = 0;
                  O2(:,1,5) = 0; O2(:,1,1) = 0; O2(:,5,5) = 0; O2(:,5,1) = 0;
N = 8;
ON = ones(N,N,N); ON(1,N,:) = 0; ON(1,1,:) = 0; ON(N,N,:) = 0; ON(N,1,:) = 0;
                  ON(1,:,N) = 0; ON(1,:,1) = 0; ON(N,:,N) = 0; ON(N,:,1) = 0;
                  ON(:,1,N) = 0; ON(:,1,1) = 0; ON(:,N,N) = 0; ON(:,N,1) = 0;

N = 10;
ON10 = ones(N,N,N); ON(1,N,:) = 0; ON(1,1,:) = 0; ON(N,N,:) = 0; ON(N,1,:) = 0;
                  ON(1,:,N) = 0; ON(1,:,1) = 0; ON(N,:,N) = 0; ON(N,:,1) = 0;
                  ON(:,1,N) = 0; ON(:,1,1) = 0; ON(:,N,N) = 0; ON(:,N,1) = 0;

% brain and scalp masks are Bra and Sca

[K, L, M] = size(b);

% Validate 'eyes' up front, before any of the expensive work below, so a bad
% seed point fails immediately rather than after the thresholding and
% morphology have already run.
if nargin >= 5 && ~isempty(eyes)
    if ~isnumeric(eyes) || ~isequal(size(eyes), [2 2])
        error('NFT:segm_outer_skull:eyes', ...
            ['eyes must be a 2x2 numeric array [x1 y1; x2 y2] giving the two ' ...
             'eye seed points on slice sli_eyes; got a %s of size %s.'], ...
            class(eyes), mat2str(size(eyes)));
    end
    if ~all(isfinite(eyes(:)))
        error('NFT:segm_outer_skull:eyes', 'eyes must be finite; got %s.', mat2str(eyes));
    end
    % xp indexes the 1st dimension of the K-by-M slice and yp the 2nd, matching
    % what ginput returns on imagesc(reshape(X_dark(:,sli_eyes,:),K,M)) and how
    % utilsegm_regiongrow is called below.
    if any(round(eyes(:,1)) < 1 | round(eyes(:,1)) > K) || ...
       any(round(eyes(:,2)) < 1 | round(eyes(:,2)) > M)
        error('NFT:segm_outer_skull:eyes', ...
            ['eye seed points fall outside the %dx%d slice: got x=%s, y=%s. ' ...
             'Expected x in [1 %d] and y in [1 %d].'], ...
            K, M, mat2str(round(eyes(:,1))'), mat2str(round(eyes(:,2))'), K, M);
    end
end

[k1max, k2max, h] = utilsegm_thresh(b, 2);
thr = (k1max-max(max(max(b)))*0.01)
%thr = 70 % child
%thr = 40
X_dark = b < thr;

X_dark = logical(X_dark);

% select eyes -- interactively by default, or from the caller when supplied.
% The interactive path is unchanged; it is still what runs when 'eyes' is
% omitted, so the GUI behaves exactly as before.
if nargin < 5 || isempty(eyes)
    h = figure; imagesc(reshape(X_dark(:,sli_eyes,:),K,M)); colormap gray;
    [xp,yp] = ginput(2); xp = round(xp); yp=round(yp);
    close(h); pause(1);
else
    % already validated above, before the expensive work
    xp = round(eyes(:,1)); yp = round(eyes(:,2));
end

Se1 = imdilate3D(imerode3D(Sca,ones(25,25,25)),ones(25,25,25));
Se2 = imerode3D(Se1, ones(7,7,7));
%clear Se1

%B_dm = imdilate3D(imdilate3D(Bra, C1),C1);
B_dm = imdilate3D(Bra, ON);
X_u_out = X_dark | B_dm;
X_i_out = X_u_out & Se2;

% mask the lower part of the skull
sli = 50;
X_i_out(:,1:sli,:) = 0;

A = X_dark & Sca; % to delete the connection between scalp and eyes
G1 = utilsegm_regiongrow(A,xp(1),sli_eyes, yp(1),8);
G2 = utilsegm_regiongrow(A,xp(2),sli_eyes, yp(2),8);

% discard eyes
X_lc = X_i_out;
X_lc = X_lc & not(G1);
X_lc = X_lc & not(G2);

Xc = imdilate3D(imdilate3D(X_lc, O2), O2);
Xc = imerode3D(imerode3D(Xc, O2), O2);
Xc = imfill(Xc,'holes');  % Feb 23 2015
Sk_out = Xc & Se2;

Sk_out = logical(Sk_out);
Sk_out = imopen3D(Sk_out, ON10);
Sk_out = imclose3D(Sk_out, ON10); % 6/11/2011
