function [tf, missing] = nft_binaries_present()
%NFT_BINARIES_PRESENT True when the warping BEM-path binaries are usable.
%
%   [tf, missing] = NFT_BINARIES_PRESENT() asks nft_get_config for the binary
%   paths on the warping (boundary element) path and checks that each resolves
%   to an existing, executable file for the current platform. Returns tf=true
%   when all are present, and a cellstr of "field (path)" for any that are not.
%
%   Note: on macOS/Windows nft_get_config points these fields straight at the
%   platform binary (e.g. asc1.osx), so an existence + executable check is
%   sufficient. On Linux the fields point at wrapper scripts that dispatch on
%   uname; those wrappers exit 0 on an unmatched architecture, so a plain exit
%   code would be misleading -- existence of the dispatched file is what matters.

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
