function [tf, missing] = nft_binaries_present()
%NFT_BINARIES_PRESENT True when the BEM/warping-pipeline binaries are usable.
%
%   [tf, missing] = NFT_BINARIES_PRESENT() asks nft_get_config for the binary
%   paths the BEM/warping pipeline uses and checks that each resolves to an
%   existing, executable file. Returns tf=true when all are present, and a
%   cellstr of "field (path)" for any that are not. Used both as a canary and to
%   gate the warping smoke test (conservatively: a superset of what any single
%   test exercises, so it errs toward skipping rather than a false pass).
%
%   What is verified, by platform:
%     - macOS / Windows: nft_get_config points each field straight at the platform
%       binary (e.g. asc1.osx), so existence + executable bit fully covers it.
%     - Linux: the fields point at wrapper scripts that dispatch on uname to
%       <name>.64 / <name>.32. This function checks only the wrapper itself, which
%       is sufficient on x86_64/i686 (the only cases the wrappers handle) but
%       NOT on an unhandled arch (e.g. arm64), where the wrapper exists and is
%       executable yet silently no-ops at runtime. Detecting that requires native
%       arm64 binaries and is deferred to Phase C (see issue #4).
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

  conf = nft_get_config();
  fields = {'asc', 'qslim', 'showmesh', 'bem_matrix_program', 'showmesh3', 'tetgen'};
  missing = {};
  for i = 1:numel(fields)
      p = conf.(fields{i});
      if ~local_is_executable(p)
          missing{end+1} = sprintf('%s (%s)', fields{i}, p); %#ok<AGROW>
      end
  end
  tf = isempty(missing);
end

function tf = local_is_executable(p)
  tf = false;
  if isempty(p) || exist(p, 'file') ~= 2
      return;
  end
  [ok, info] = fileattrib(p);
  if ~ok
      return;
  end
  if ispc
      tf = true;   % Windows has no POSIX executable bit; existence suffices
  else
      tf = isfield(info, 'UserExecute') && info.UserExecute == 1;
  end
end
