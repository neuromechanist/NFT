function d = dsl_digest(sourceJ, topK)
%DSL_DIGEST Compact, comparison-ready signature of a distributed source estimate.
%
%   d = DSL_DIGEST(sourceJ, topK) reduces an [n_voxel x n_comp] source estimate to
%   a per-component struct array that is small enough to freeze in-tree yet
%   sensitive to any real change in the solver output. For each component it
%   records the dominant-voxel location and magnitude, the global scale, the
%   number of significant voxels, and the top-K voxels (indices + values), which
%   together pin the spatial pattern without storing the full dense field.
%
%     d(k).peakId  - index of the maximum-magnitude voxel
%     d(k).peakVal - signed value at that voxel
%     d(k).norm2   - Euclidean norm of the component (global scale)
%     d(k).nnz5    - number of voxels above 5% of the peak magnitude
%     d(k).topIdx  - indices of the topK largest-magnitude voxels (descending)
%     d(k).topVal  - signed values at topIdx
%
%   Default topK = 200. Comparison of two digests is done by dsl_digest_compare.
%
% Author: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026
%
% Copyright (C) 2026 Seyed Yahya Shirazi, SCCN, INC, UCSD, shirazi@ieee.org
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

  if nargin < 2 || isempty(topK)
      topK = 200;
  end
  nComp = size(sourceJ, 2);
  d = repmat(struct('peakId', 0, 'peakVal', 0, 'norm2', 0, 'nnz5', 0, ...
      'topIdx', [], 'topVal', []), nComp, 1);
  for k = 1:nComp
      v = sourceJ(:, k);
      a = abs(v);
      [mx, pid] = max(a);
      [~, ord] = sort(a, 'descend');
      ti = ord(1:min(topK, numel(ord)));
      d(k).peakId  = pid;
      d(k).peakVal = v(pid);
      d(k).norm2   = norm(v);
      if mx > 0
          d(k).nnz5 = sum(a > 0.05 * mx);
      else
          d(k).nnz5 = 0;
      end
      d(k).topIdx = ti(:);
      d(k).topVal = v(ti);
  end
end
