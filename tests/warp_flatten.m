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
