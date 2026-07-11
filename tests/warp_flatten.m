function v = warp_flatten(s)
%WARP_FLATTEN Flatten a (possibly nested) struct to a numeric column vector.
%
%   v = WARP_FLATTEN(s) concatenates every numeric leaf value of struct s into a
%   single double column vector, recursing into nested structs. Field order is
%   deterministic for a given code path, so two outputs of the same computation
%   flatten to comparable vectors -- used for tolerance comparison of the warp
%   transform, whose exact field layout should not have to be hard-coded here.

  v = zeros(0, 1);
  fn = fieldnames(s);
  for i = 1:numel(fn)
      x = s.(fn{i});
      if isstruct(x)
          v = [v; warp_flatten(x)];   %#ok<AGROW>
      elseif isnumeric(x) || islogical(x)
          v = [v; double(x(:))];      %#ok<AGROW>
      end
  end
end
