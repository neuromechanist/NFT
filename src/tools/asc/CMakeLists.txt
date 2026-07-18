# asc -- Adaptive Skeleton Climbing (ASC) isosurface extractor
# ============================================================
#
# Upstream: ASC v2.01a (2 June 2009), Tien-Tsin Wong, Department of Computer
# Science and Engineering, The Chinese University of Hong Kong (CUHK), based
# on Poston/Wong/Heng, "Multiresolution Isosurface Extraction with Adaptive
# Skeleton Climbing", Computer Graphics Forum 17(3), 1998. Copyright (c)
# 1997-2009, The Chinese University of Hong Kong. BSD-3-Clause (full text at
# THIRD_PARTY_LICENSES/ASC-TienTsinWong.txt, relative to the repo root; this
# is the CORRECT current license -- an earlier internal survey mischaracterized
# ASC as academic/non-commercial-only, which was true of a stale 2004-vintage
# copy but not of the official upstream v2.01a release fetched fresh for this
# import). Full provenance record: provenance/binaries.yaml (entries asc1,
# asc2, asc4, asc8).
#
# asc is a headless isosurface-extraction tool: given a binary volume mask,
# it produces a triangulated surface mesh. NFT calls it as a separate process
# from its mesh-generation step (Mesh_generation.m:247 / nft_mesh_generation.m
# :142) to build the scalp/skull/brain surface meshes from segmented MRI
# volumes: `asc1 -t 10 -dr1 <in.raw> K L M -f <out.asc> -ot`. Only the
# block-size-1 variant (`asc1`, finest triangulation) is invoked by NFT
# (`conf.asc = asc1` in nft_get_config.m); asc2/asc4/asc8 (coarser block
# sizes, same source) are built here too for completeness, since they cost
# nothing extra and were shipped alongside asc1. Pure, portable C++ against
# only libc/libstdc++ -- confirmed against the shipped asc1.osx: `otool -L`
# shows only libSystem/libc++, no OpenGL/GLUT (see "Files present but not
# compiled" below).
#
# --------------------------------------------------------------------------
# Toolchain expectations
# --------------------------------------------------------------------------
# - CMake >= 3.16 (Ubuntu 20.04's stock cmake; also satisfied by every
#   Homebrew/Xcode cmake and GitHub Actions ubuntu-latest/macos-latest image).
# - A C++11-capable compiler. The source itself is C++98/03-vintage (register
#   storage class, pre-standard idioms), but we build it as C++11 rather than
#   pinning an ancient standard or leaving the compiler default unset, matching
#   the bem_matrix/procmesh CMakeLists.txt convention.
# - No external libraries once the portability fixes below are applied: no
#   zlib, no PETSc, no GL, no Boost. `<values.h>` (an obsolete SVR4 header,
#   still present on some Linux/glibc systems but never on macOS) is used
#   opportunistically when available and a bundled substitute is used when
#   it is not -- see "Portability fixes applied".
#
# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
#   cmake -S src/tools/asc -B build/asc -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/asc
#   # binaries at build/asc/asc1, build/asc/asc2, build/asc/asc4, build/asc/asc8
#   # (or a per-config subdirectory on a multi-config generator, e.g.
#   # build/asc/Release/asc1.exe on Visual Studio)
#
# Optional install step (stages the binaries under CMAKE_INSTALL_PREFIX/bin,
# e.g. for CI artifact collection -- NFT's own runtime dispatch is not wired
# to this build yet; that is Phase 7, issue #43):
#   cmake --install build/asc --prefix build/asc/stage
#
# --------------------------------------------------------------------------
# Why four executables from one source tree
# --------------------------------------------------------------------------
# asc1/asc2/asc4/asc8 are NOT four different programs -- they are the same
# source compiled four times with a different block-size macro
# (-DASCHEADER2/-DASCHEADER4/-DASCHEADER8; asc1 is upstream's own "no macro
# defined" default, see src/asc.h's #else branch), exactly mirroring
# upstream's own src/Makefile (`asc2: ... $(CPP) -DASCHEADER2 -c dikelign.cpp
# ... asc.cpp`). The macro only changes 4 integer constants in src/asc.h
# (NLEVEL/N/SIZE/DSIZE, the block-processing grid size) and is read only by
# 7 of the ~15 compiled source files (the "variant" sources: block.cpp,
# dikelign.cpp, farm.cpp, highrice.cpp, padi.cpp, slab.cpp, strip.cpp, plus
# asc.cpp itself, which needs no macro-specific behavior but is cheap to
# recompile per variant). The remaining 8 sources (common.cpp, data.cpp,
# doublist.cpp, index.cpp, initdata.cpp, kdtree.cpp, misc.cpp, vecmath.cpp)
# do not include asc.h and do not reference these constants (confirmed by
# grep across every one of them) -- upstream's Makefile builds this set only
# once and reuses the same .o files across all four link steps, and this
# CMakeLists.txt does the same via the `asc_common` OBJECT library below,
# rather than needlessly recompiling 8 identical files four times.
#
# --------------------------------------------------------------------------
# Files present but not compiled (kept for historical completeness)
# --------------------------------------------------------------------------
# - src/viewtri.cpp: the OpenGL/GLUT mesh viewer from the same upstream
#   release. This is the ONLY file in the entire package that references GL
#   (confirmed: `grep -rl glut\|GL/gl src/*.cpp src/*.h` matches nothing else)
#   -- so asc1/asc2/asc4/asc8 have always been GL-free, dead-code-free of any
#   OpenGL dependency, matching the shipped asc1.osx's `otool -L` (libSystem/
#   libc++ only). NFT never ships or calls a `viewtri` binary. Kept in the
#   tree, excluded from the build, so the historical upstream source
#   directory is complete rather than silently pruned; add a second
#   add_executable() here (it additionally needs trackball.cpp and a real
#   GLUT) if a viewer is ever wanted.
# - src/interface.cpp / src/testlib.cpp: upstream's "linkable library"
#   interface (asc1()/asc2()/asc4()/asc8() callable from C++ rather than a
#   CLI) and its test driver. Upstream's own Unix Makefile has no build rule
#   for either (only the Windows .dsp project files reference them, which are
#   themselves not carried into this tree -- see the top-level note in
#   src/tools/asc/README.md). NFT calls the asc1 CLI as a subprocess, never
#   this library interface. Kept for historical completeness.
# - src/trackball.cpp: viewtri's mouse-rotation helper, needed only by
#   viewtri.cpp above.
#
# --------------------------------------------------------------------------
# Per-platform notes
# --------------------------------------------------------------------------
# - Linux x86_64 / Mac arm64 (primary targets): build and run as-is with the
#   system compiler (gcc/g++ on Linux, Apple clang on macOS) once the
#   portability fixes below are applied. Verified by this import: builds
#   clean and runs natively (no Rosetta) on macOS arm64 -- a real platform
#   win, arm64 asc did not exist before this import (the shipped asc1.osx is
#   x86_64-only).
# - Mac x86_64 (legacy, build while free): same as Mac arm64, no known
#   platform-specific issue; not independently verified on real x86_64
#   hardware by this import -- flag if it breaks.
# - Windows (best-effort, never blocking): not built or tested on Windows as
#   part of this import. The source's own `#ifdef WIN32` branches (e.g.
#   src/pcvalues.h, src/common.cpp) should make this buildable under MSVC
#   without the Unix-side portability fixes below, but that is untested here.
#
# --------------------------------------------------------------------------
# Portability fixes applied (all behavior-preserving; see git history for
# the exact diffs and commit messages)
# --------------------------------------------------------------------------
# - src/asc.cpp: `void main(...)` -> `int main(...)` with an explicit
#   `return 0;` at the fall-through end of the function. Pre-standard `void
#   main` is rejected outright by every compiler targeted here (GCC, Clang,
#   MSVC all require `main` to return `int`); this is the same fix already
#   applied, per provenance/binaries.yaml's license_evidence note, to a
#   separately modified copy of this source found in the SCCN internal
#   archive -- independently rediscovered here against the clean public
#   upstream release, not copied from that archive.
# - src/vortex.h: removed three unused, non-portable blind includes --
#   `<varargs.h>` (pre-standard, superseded by `<stdarg.h>`; Apple's SDK
#   `#error`s on inclusion outright), `<iostream.h>` (pre-standard C++,
#   removed from every modern C++ library; no file in this tree uses
#   `cout`/`cin`/`cerr`, confirmed by grep), and `<malloc.h>` (not present on
#   macOS; `<stdlib.h>`, already included two lines above, is sufficient for
#   the `malloc`/`free`/`calloc` calls actually used -- no `alloca` or other
#   malloc.h-specific symbol appears anywhere in this tree). None of the
#   three was reachable from any code path that is actually compiled into
#   asc1/asc2/asc4/asc8.
# - src/pcvalues.h, src/common.cpp, src/index.cpp: `<values.h>` is an
#   obsolete SVR4 header providing `MAXFLOAT`/`MINFLOAT`/etc that upstream's
#   own src/pcvalues.h already documents as "created to substitute the header
#   file values.h" -- but upstream only activates that substitute `#ifdef
#   WIN32`, i.e. it assumed every non-Windows target has a real `<values.h>`.
#   That assumption held on 2009-era Linux/Solaris but not on macOS, which
#   has never shipped `<values.h>`. Changed the three `#ifdef WIN32` /
#   `#else #include <values.h> #endif` guards to `#if defined(WIN32) ||
#   !__has_include(<values.h>)`, so the real `<values.h>` is still used
#   wherever it exists (unchanged behavior on Linux) and upstream's own
#   drop-in substitute (unchanged values: `MAXFLOAT`/`MINFLOAT` from
#   `<float.h>`'s `FLT_MAX`/`FLT_MIN`) is used wherever it does not (macOS).
#   `__has_include` is a standard preprocessor feature in every compiler
#   targeted here (GCC >= 5, Clang, MSVC >= 2017).
# - src/pcvalues.h: additionally wrapped its (upstream-unconditional)
#   `MAXFLOAT`/`MINFLOAT`/`MAXSHORT`/`MINSHORT` `#define`s in `#ifndef`
#   guards, matching the `#ifndef`-guarded style upstream already uses two
#   lines above for `M_PI`/`M_2_PI`/`M_PI_2`/`M_E` in this same file. Needed
#   because activating this substitute header on macOS (previous fix, above)
#   surfaced a latent upstream issue: several files (src/block.cpp,
#   src/asc.cpp, src/initdata.cpp, src/interface.cpp) unconditionally
#   `#include <math.h>` *and* `"pcvalues.h"`, and macOS's own `<math.h>`
#   already `#define`s `MAXFLOAT` (a BSD extension) -- so without this guard,
#   pcvalues.h's unconditional `#else` branch (upstream's own `#ifdef
#   FLT_MAX` check does not help here, since `<float.h>` was never included)
#   redefined it, a harmless but noisy `-Wmacro-redefined` warning to the
#   same numeric value (`FLT_MAX`) either way.
#
# Pre-existing upstream -Wall diagnostics (not fixed, not behavior-affecting):
# `register` storage-class specifiers (deprecated but not removed until
# C++17; harmless under the C++11 standard used here), a few
# dangling-else and empty-for-body warnings from 2001-vintage formatting.
# Same posture as bem_matrix/procmesh: -Wall, not -Werror -- this is a
# rebuild of legacy code, not a rewrite.

cmake_minimum_required(VERSION 3.16)
project(asc CXX)

# Block-size-independent object files, shared by all four variants -- see
# "Why four executables from one source tree" above for why this is safe.
add_library(asc_common OBJECT
  src/common.cpp
  src/data.cpp
  src/doublist.cpp
  src/index.cpp
  src/initdata.cpp
  src/kdtree.cpp
  src/misc.cpp
  src/vecmath.cpp
)
set_target_properties(asc_common PROPERTIES
  CXX_STANDARD 11
  CXX_STANDARD_REQUIRED ON
  CXX_EXTENSIONS OFF
)
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(asc_common PRIVATE -Wall)
elseif(MSVC)
  target_compile_options(asc_common PRIVATE /W3)
endif()

# One executable per block-size variant. Each recompiles the 7 block-size-
# dependent sources (plus asc.cpp) with its own ASCHEADERn macro and links
# against the shared asc_common objects above -- mirrors upstream's own
# Makefile targets (asc1/asc2/asc4/asc8) exactly, including which macro maps
# to which target (asc1 = no macro, upstream's own default).
function(nft_add_asc_variant name)
  cmake_parse_arguments(ARG "" "DEFINE" "" ${ARGN})
  add_executable(${name}
    src/asc.cpp
    src/block.cpp
    src/dikelign.cpp
    src/farm.cpp
    src/highrice.cpp
    src/padi.cpp
    src/slab.cpp
    src/strip.cpp
    $<TARGET_OBJECTS:asc_common>
  )
  if(ARG_DEFINE)
    target_compile_definitions(${name} PRIVATE ${ARG_DEFINE})
  endif()
  set_target_properties(${name} PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
  )
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(${name} PRIVATE -Wall)
  elseif(MSVC)
    target_compile_options(${name} PRIVATE /W3)
  endif()
  # libm: required explicitly on Linux (glibc splits math functions out of
  # libc), folded into libSystem already on macOS, and not a separate
  # library under MSVC -- so only add it for the platforms that actually
  # need it. Matches bem_matrix/procmesh's convention.
  if(UNIX AND NOT APPLE)
    target_link_libraries(${name} PRIVATE m)
  endif()
  install(TARGETS ${name} RUNTIME DESTINATION bin)
endfunction()

nft_add_asc_variant(asc1)
nft_add_asc_variant(asc2 DEFINE ASCHEADER2)
nft_add_asc_variant(asc4 DEFINE ASCHEADER4)
nft_add_asc_variant(asc8 DEFINE ASCHEADER8)
