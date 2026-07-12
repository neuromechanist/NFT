This is a modification of geodesic implementation by Danil Kirsanov to
make it compile as a MATLAB MEX file rather than a shared object. The
toolbox .m files are modified to call the mex file.

The original C++ source code is available at
https://code.google.com/archive/p/geodesic/ and the Matlab toolbox can
be downloaded from MathWorks File Exchange.

Compilation Instructions:

  Run the reproducible build helper from MATLAB (compiles for the current
  platform and places the MEX next to the .m wrappers in geodesic/):

    >> build_geodesic

  It wraps the underlying command:

    $ mex -R2018a geodesic.cpp strlcpy.c

  The MEX entry point (geodesic.cpp) uses only the C++ standard library
  (std::shared_ptr); boost is NOT required. (The separate geodesic_matlab_api.cpp
  still includes <boost/shared_ptr.hpp>, but it is not part of the MEX build.)

  Apple Silicon (maca64): the modern Apple linker (Xcode >= 15 / macOS 26 SDK)
  fails to link the classic mexFunction against MATLAB's C++ MEX API export map
  ("Undefined symbols: _mexFunctionAdapter, ..."). build_geodesic passes
  '-Wl,-ld_classic' to select Apple's classic linker on maca64, which links
  cleanly. See build_geodesic.m for details.

Zeynep Akalin Acar, April 2021 (arm64 build + reproducible helper added 2026)
