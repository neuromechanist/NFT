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
