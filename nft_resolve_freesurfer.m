function reconall = nft_resolve_freesurfer()
%NFT_RESOLVE_FREESURFER Resolve and validate the FreeSurfer recon-all command.
%
%   reconall = NFT_RESOLVE_FREESURFER() returns the recon-all command to invoke for
%   the cortical distributed-source path, taken from nft_get_config (from
%   FREESURFER_HOME/bin if that environment variable is set, else 'recon-all' on
%   PATH). It first confirms recon-all is actually runnable and errors with an
%   actionable message if it is not, so callers fail clearly here rather than with
%   an opaque shell error deep inside recon-all. Single source of truth shared by
%   the headless (nft_dsl_forward_model_generation) and GUI dashboard call sites.
%
%   FreeSurfer is an external, Unix-only dependency (not shipped with NFT). The
%   'command -v' probe accepts both a bare name and a full path and, per POSIX,
%   only succeeds for an executable; on Windows it returns non-zero (fail-safe),
%   which is moot since recon-all cannot run under cmd.exe anyway.

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

  conf = nft_get_config;
  reconall = conf.freesurfer;
  [status, ~] = system(sprintf('command -v %s', reconall));
  if status ~= 0
      error('NFT:freesurfer:missing', ...
          ['FreeSurfer recon-all not found (%s). The cortical distributed-source ' ...
           'path requires a working FreeSurfer install: set FREESURFER_HOME or put ' ...
           'recon-all on PATH.'], reconall);
  end
end
