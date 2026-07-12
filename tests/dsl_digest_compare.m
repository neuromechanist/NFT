function c = dsl_digest_compare(refDigest, sourceJ)
%DSL_DIGEST_COMPARE Compare a fresh source estimate against a frozen digest.
%
%   c = DSL_DIGEST_COMPARE(refDigest, sourceJ) evaluates how closely a
%   freshly-computed [n_voxel x n_comp] estimate reproduces the frozen reference
%   produced by dsl_digest. It compares on the reference's own top-K support (the
%   voxels that define each component's pattern), so it is robust to the vast
%   near-zero tail while still failing on any real change in the dominant sources.
%
%   Returned struct (all arrays are 1 x n_comp):
%     nComp        - number of components compared
%     sizeMatch    - true when sourceJ has one column per reference component
%     peakMatch    - per-comp: recomputed argmax voxel equals the reference peak
%     normRelErr   - per-comp: relative error of the component norm
%     topCorr      - per-comp: Pearson corr(recomputed(topIdx), reference topVal)
%     topRelErr    - per-comp: max abs error on topVal, relative to peak magnitude
%     nnz5RelErr   - per-comp: relative error of the count of voxels above 5% of
%                    the peak magnitude (the SCS sparsity/compactness signal)
%     allFinite    - true when sourceJ has no NaN/Inf
%
%   Only the component (column) count is guarded here; the caller also checks the
%   voxel (row) count against the frozen meta before trusting topIdx indexing.
%   A size mismatch short-circuits: the per-comp arrays are returned empty so the
%   caller reports the shape cause rather than indexing past the array.

  nComp = numel(refDigest);
  c = struct('nComp', nComp, 'sizeMatch', size(sourceJ, 2) == nComp, ...
      'peakMatch', [], 'normRelErr', [], 'topCorr', [], 'topRelErr', [], ...
      'nnz5RelErr', [], 'allFinite', all(isfinite(sourceJ(:))));
  if ~c.sizeMatch
      return
  end

  c.peakMatch  = false(1, nComp);
  c.normRelErr = zeros(1, nComp);
  c.topCorr    = zeros(1, nComp);
  c.topRelErr  = zeros(1, nComp);
  c.nnz5RelErr = zeros(1, nComp);
  for k = 1:nComp
      v  = sourceJ(:, k);
      a  = abs(v);
      [mx, pid] = max(a);
      ti = refDigest(k).topIdx;
      rv = refDigest(k).topVal;
      nv = v(ti);
      peakMag = max(abs(rv));
      if peakMag == 0
          peakMag = 1;
      end
      c.peakMatch(k)  = (pid == refDigest(k).peakId);
      % norm floor of 1 is safe here: solver output norms are O(10^2-10^4) (see
      % PROVENANCE), so it never turns this into an absolute check for real data;
      % revisit if the solver's output units/scale change.
      c.normRelErr(k) = abs(norm(v) - refDigest(k).norm2) / max(1, refDigest(k).norm2);
      if std(nv) > 0 && std(rv) > 0
          cc = corrcoef(nv, rv);       % base MATLAB (no Statistics Toolbox)
          c.topCorr(k) = cc(1, 2);
      else
          c.topCorr(k) = double(isequal(nv, rv));
      end
      c.topRelErr(k) = max(abs(nv - rv)) / peakMag;
      if mx > 0
          nnz5 = sum(a > 0.05 * mx);
      else
          nnz5 = 0;
      end
      c.nnz5RelErr(k) = abs(nnz5 - refDigest(k).nnz5) / max(1, refDigest(k).nnz5);
  end
end
