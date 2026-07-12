function out = build_geodesic()
%BUILD_GEODESIC Compile the geodesic MEX for the current platform (reproducible).
%
%   out = BUILD_GEODESIC() compiles geodesic/src/geodesic.cpp (+ strlcpy.c) into a
%   platform MEX file and places it next to the toolbox .m wrappers in geodesic/.
%   Returns the path of the built MEX. Run it from anywhere:
%       matlab -batch "run('geodesic/build_geodesic.m')"   % or: build_geodesic
%
%   Source: Danil Kirsanov's exact-geodesic library (google code / File Exchange),
%   adapted to a MEX by Zeynep Akalin Acar (see readme_sccn.txt). The C++ uses only
%   std:: (no boost); geodesic.cpp is the classic C-API mexFunction entry point.
%
%   Apple Silicon note. On macOS the modern Apple linker (ld-prime, Xcode >= 15 /
%   the macOS 26 SDK) rejects the per-symbol "undefined allowed" flags MATLAB's mex
%   emits for the C++ MEX API export map, failing to link a classic mexFunction with
%   "Undefined symbols: _mexFunctionAdapter, _mexCreateMexFunction,
%   _mexDestroyMexFunction". Passing '-Wl,-ld_classic' selects Apple's classic
%   linker, which links cleanly. This is applied on maca64 (and as a fallback if the
%   default link fails). If a future Xcode removes -ld_classic, the real fix is for
%   mex to stop adding the C++ MEX API export map to a classic C-API build.

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

  here    = fileparts(mfilename('fullpath'));      % .../geodesic
  srcDir  = fullfile(here, 'src');
  mexName = ['geodesic.' mexext];
  srcMex  = fullfile(srcDir, mexName);
  args    = {'-R2018a', 'geodesic.cpp', 'strlcpy.c'};

  old = cd(srcDir);
  restoreDir = onCleanup(@() cd(old));  %#ok<NASGU> restores cwd on any exit

  % Clear any artifact left in src by a prior/interrupted run BEFORE building, so
  % the success check can only be satisfied by a file THIS invocation writes (and
  % so a stale binary can never be moved out as if freshly built).
  if isfile(srcMex)
      delete(srcMex);
  end

  useClassicLd = strcmp(computer('arch'), 'maca64');   % new Apple linker needs it
  [built, buildErr] = tryBuild(args, useClassicLd, srcMex);
  if ~built && ~useClassicLd && ismac
      % An Intel Mac on a newer Xcode can hit the same linker issue; retry with the
      % classic-linker workaround. (-ld_classic is Apple-only, so it is never tried
      % on Linux/Windows, where GNU ld would misparse it.)
      warning('geodesic:build:retryClassicLd', ...
          'Default mex link failed; retrying with -Wl,-ld_classic.');
      [built, buildErr] = tryBuild(args, true, srcMex);
  end
  if ~built
      baseErr = MException('geodesic:build:failed', 'geodesic MEX build failed.');
      if ~isempty(buildErr)
          baseErr = addCause(baseErr, buildErr);   % preserve the real mex diagnostic
      end
      throw(baseErr);
  end

  outPath = fullfile(here, mexName);
  movefile(srcMex, outPath, 'f');   % place next to the .m wrappers
  fprintf('Built %s\n', outPath);
  out = outPath;
end

function [ok, lastErr] = tryBuild(args, classicLd, srcMex)
  if classicLd
      args = [args, {'LDFLAGS=$LDFLAGS -Wl,-ld_classic'}];
  end
  lastErr = [];
  try
      mex(args{:});
  catch err
      fprintf(2, '%s\n', err.message);
      lastErr = err;
  end
  % Success = THIS run wrote the artifact into srcDir. Use isfile on the FULL path
  % (not a bare-name exist(), which would path-search and could resolve a
  % pre-committed geodesic.<mexext> shipped in geodesic/, on the MATLAB path).
  ok = isempty(lastErr) && isfile(srcMex);
end
