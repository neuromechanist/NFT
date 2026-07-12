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

  here   = fileparts(mfilename('fullpath'));      % .../geodesic
  srcDir = fullfile(here, 'src');
  args   = {'-R2018a', 'geodesic.cpp', 'strlcpy.c'};

  old = cd(srcDir);
  restoreDir = onCleanup(@() cd(old));

  useClassicLd = strcmp(computer('arch'), 'maca64');
  built = tryBuild(args, useClassicLd);
  if ~built && ~useClassicLd
      % Default link failed on a platform we did not pre-empt; retry with the
      % classic-linker workaround before giving up.
      warning('geodesic:build:retryClassicLd', ...
          'Default mex link failed; retrying with -Wl,-ld_classic.');
      built = tryBuild(args, true);
  end
  if ~built
      error('geodesic:build:failed', 'geodesic MEX build failed; see the mex output above.');
  end

  mexName = ['geodesic.' mexext];
  outPath = fullfile(here, mexName);
  movefile(fullfile(srcDir, mexName), outPath, 'f');   % place next to the .m wrappers
  fprintf('Built %s\n', outPath);
  out = outPath;
end

function ok = tryBuild(args, classicLd)
  if classicLd
      args = [args, {'LDFLAGS=$LDFLAGS -Wl,-ld_classic'}];
  end
  ok = true;
  try
      mex(args{:});
  catch err
      fprintf(2, '%s\n', err.message);
      ok = false;
  end
  ok = ok && exist(['geodesic.' mexext], 'file') == 3;
end
