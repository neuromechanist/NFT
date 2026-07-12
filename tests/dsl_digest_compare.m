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
%     topCorr      - per-comp: corr(recomputed(topIdx), reference topVal)
%     topRelErr    - per-comp: max abs error on topVal, relative to peak magnitude
%     allFinite    - true when sourceJ has no NaN/Inf
%
%   A size mismatch short-circuits: the per-comp arrays are returned empty so the
%   caller reports the shape cause rather than indexing past the array.

  nComp = numel(refDigest);
  c = struct('nComp', nComp, 'sizeMatch', size(sourceJ, 2) == nComp, ...
      'peakMatch', [], 'normRelErr', [], 'topCorr', [], 'topRelErr', [], ...
      'allFinite', all(isfinite(sourceJ(:))));
  if ~c.sizeMatch
      return
  end

  c.peakMatch  = false(1, nComp);
  c.normRelErr = zeros(1, nComp);
  c.topCorr    = zeros(1, nComp);
  c.topRelErr  = zeros(1, nComp);
  for k = 1:nComp
      v  = sourceJ(:, k);
      a  = abs(v);
      [~, pid] = max(a);
      ti = refDigest(k).topIdx;
      rv = refDigest(k).topVal;
      nv = v(ti);
      peakMag = max(abs(rv));
      if peakMag == 0
          peakMag = 1;
      end
      c.peakMatch(k)  = (pid == refDigest(k).peakId);
      c.normRelErr(k) = abs(norm(v) - refDigest(k).norm2) / max(1, refDigest(k).norm2);
      if std(nv) > 0 && std(rv) > 0
          c.topCorr(k) = corr(nv, rv);
      else
          c.topCorr(k) = double(isequal(nv, rv));
      end
      c.topRelErr(k) = max(abs(nv - rv)) / peakMag;
  end
end
