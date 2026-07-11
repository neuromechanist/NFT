function v = warp_flatten(s)
%WARP_FLATTEN Flatten a (possibly nested) scalar struct to a numeric column vector.
%
%   v = WARP_FLATTEN(s) concatenates every numeric/logical leaf value of scalar
%   struct s into a single double column vector, recursing into nested scalar
%   structs. Field order is deterministic for a given code path, so two outputs
%   of the same computation flatten to comparable vectors -- used for tolerance
%   comparison of the warp transform without hard-coding its exact field layout.
%
%   Fails loudly on anything it cannot flatten (a struct array, or a leaf that is
%   a cell/char/handle/etc.) rather than silently dropping it: a later refactor
%   that changes a field's type or shape must surface in the comparison, not
%   vanish from it.

  if ~isstruct(s) || ~isscalar(s)
      error('NFT:test:warpFlatten', 'warp_flatten expects a scalar struct, got %s.', class(s));
  end

  v = zeros(0, 1);
  fn = fieldnames(s);
  for i = 1:numel(fn)
      x = s.(fn{i});
      if isstruct(x)
          if ~isscalar(x)
              error('NFT:test:warpFlatten', ...
                  'Field "%s" is a %d-element struct array (expected scalar).', fn{i}, numel(x));
          end
          v = [v; warp_flatten(x)];   %#ok<AGROW>
      elseif isnumeric(x) || islogical(x)
          v = [v; double(x(:))];      %#ok<AGROW>
      else
          error('NFT:test:warpFlatten', ...
              'Field "%s" has unsupported type %s.', fn{i}, class(x));
      end
  end
end
