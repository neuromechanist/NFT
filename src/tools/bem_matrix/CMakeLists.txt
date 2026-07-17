# bem_matrix -- METU-FP BEM toolkit coefficient-matrix generator
# ============================================================
#
# Upstream: METU-FP Toolkit / EMSI Tools Package, Brain Research Laboratory,
# Middle East Technical University (METU). Copyright (C) 2008 Zeynep Akalin
# Acar, Can Erkin Acar, Nevzat G. Gencer. GPL-2.0-or-later (full text at
# THIRD_PARTY_LICENSES/GPL-2.0.txt, relative to the repo root), EXCEPT one
# routine inside src/solvemat.cpp (the BiCGSTAB solver) whose own header
# comment says it is adapted from the netlib "Templates" reference code and
# "appears to be under the BSD license" -- no formal license header was
# found in the public netlib source either, so no BSD text is reproduced
# here; this ambiguity is recorded honestly in provenance/binaries.yaml and
# THIRD_PARTY_LICENSES/README.md rather than guessed at. Full provenance
# record: provenance/binaries.yaml (entry name: bem_matrix).
#
# bem_matrix is a headless BEM (Boundary Element Method) coefficient-matrix
# generator, invoked as a separate process from NFT's BEM forward pipeline
# (bem_generate_eeg_matrices.m -> `bem_matrix -f <name> -o <mod> <mesh>
# <boundary>=<conductivity> ...`). It reads a mesh in the .bec/.bee/.bei
# triplet format and writes dense coefficient matrices (.cmt / .dmt / .imt).
# Pure, portable C++ against only libc/libm/libstdc++ -- confirmed against
# the shipped bem_matrix.osx: `otool -L` shows only libstdc++/libSystem, and
# the upstream Makefile itself declares `LIBS=-lm` only (no lapack, no BLAS
# -- the linear solve in src/solvemat.cpp is a hand-rolled, unpreconditioned
# except for a Jacobi/diagonal preconditioner, BiCGSTAB iterative solver).
#
# --------------------------------------------------------------------------
# Toolchain expectations
# --------------------------------------------------------------------------
# - CMake >= 3.16 (Ubuntu 20.04's stock cmake; also satisfied by every
#   Homebrew/Xcode cmake and GitHub Actions ubuntu-latest/macos-latest image).
# - A C++11-capable compiler. The source itself is C++98/03-vintage (no
#   C++11 language features used), but we build it as C++11 rather than
#   pinning an ancient standard or leaving the compiler default unset: it
#   costs nothing here and avoids surprises from a toolchain's shifting
#   default standard. Matches the procmesh CMakeLists.txt convention.
# - libm on platforms that ship math functions in a separate library (Linux
#   glibc). Not needed as an explicit link target on macOS (libm is folded
#   into libSystem) or MSVC (the CRT provides these symbols directly).
# - No other external libraries. On a clean checkout, configuring this
#   directory needs nothing beyond a C/C++ compiler.
#
# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
#   cmake -S src/tools/bem_matrix -B build/bem_matrix -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/bem_matrix
#   # binary at build/bem_matrix/bem_matrix (or a per-config subdirectory on
#   # a multi-config generator, e.g. build/bem_matrix/Release/bem_matrix.exe
#   # on Visual Studio)
#
# Optional install step (stages the binary under CMAKE_INSTALL_PREFIX/bin,
# e.g. for CI artifact collection -- NFT's own runtime dispatch is not wired
# to this build yet; that is Phase 7, issue #43):
#   cmake --install build/bem_matrix --prefix build/bem_matrix/stage
#
# --------------------------------------------------------------------------
# Files present but not compiled (kept for historical completeness)
# --------------------------------------------------------------------------
# - src/bem_solve.cpp: a second CLI front-end (`bem_solve`, IPA/inverse
#   dipole-fitting driver) that upstream's own Makefile builds as a sibling
#   binary from the SAME object files as bem_matrix, sharing everything
#   except its own main(). NFT never ships or calls a `bem_solve` binary
#   (checked: no such file, no such provenance/binaries.yaml entry, and no
#   NFT .m file references it) -- only bem_matrix is in scope for this
#   import (issue #39). Kept in the tree, excluded from the build, so the
#   historical upstream source directory is complete rather than silently
#   pruned; add a second add_executable() here if bem_solve is ever needed.
#
# --------------------------------------------------------------------------
# Per-platform notes
# --------------------------------------------------------------------------
# - Linux x86_64 / Mac arm64 (primary targets): build and run as-is with the
#   system compiler (gcc/g++ on Linux, Apple clang on macOS). Verified by
#   this import: builds clean (warnings only, see below) on both Ubuntu
#   24.04/g++ 13 and macOS/Apple clang, with ZERO source changes required --
#   unlike procmesh (#57/#58), this source needed no portability fixes at
#   all on either primary toolchain.
# - Mac x86_64 (legacy, build while free): same as Mac arm64, no known
#   platform-specific issue; not independently verified on real x86_64
#   hardware by this import -- flag if it breaks.
# - Windows (best-effort, never blocking): not built or tested on Windows as
#   part of this import.
#
# --------------------------------------------------------------------------
# Portability fixes applied
# --------------------------------------------------------------------------
# None. This source compiles and links cleanly on both primary toolchains
# with no source edits (only the pre-existing -Wall diagnostics below).
# src/dvector.cpp:27 has a `#ifdef _WIN32_`-guarded `#include <mem.h>` (same
# pattern as procmesh's dead _WIN32_ branches) that is simply never active
# on Linux/Mac and needs no fix. src/hptimer.h and src/hptimer.cpp have a
# working POSIX (`#ifndef _WIN32_`) gettimeofday()-based branch that is the
# one actually compiled here.
#
# Pre-existing upstream -Wall diagnostics (not fixed, not behavior-affecting):
# ISO-C++11-forbidden string-literal-to-char* conversions (the code passes
# string literals into char* parameters throughout, e.g. openFile(name,
# "bec")) and one ignored fgets() return value in src/matrow.cpp. Same
# posture as procmesh: -Wall, not -Werror -- this is a rebuild of legacy
# code, not a rewrite, and -Werror would force non-behavior-preserving
# changes just to silence incidental 2008-vintage warnings.

cmake_minimum_required(VERSION 3.16)
project(bem_matrix CXX)

# Target name matches upstream's own historical Makefile target so any
# existing reference to "the bem_matrix target" keeps working.
add_executable(bem_matrix
  src/bem_engine.cpp
  src/bem_matrix.cpp
  src/bemmesh.cpp
  src/dvector.cpp
  src/hptimer.cpp
  src/magnetic.cpp
  src/matrow.cpp
  src/meshutil.cpp
  src/shape.cpp
  src/solvemat.cpp
)

# bem_engine.h / bemmesh.h / define.h / dvector.h / hptimer.h / magnetic.h /
# matrow.h / meshutil.h are header-only and pulled in transitively by the
# .cpp files above -- no separate compilation unit needed for any of them.
# src/solvemat.cpp has no matching header; its one externally-used symbol
# (solveMatrix) is declared directly in bem_engine.h, matching upstream.

set_target_properties(bem_matrix PROPERTIES
  CXX_STANDARD 11
  CXX_STANDARD_REQUIRED ON
  CXX_EXTENSIONS OFF
)

# Upstream's own Makefile built with -Wall; keep that as a baseline warning
# level here too (not treated as errors -- see "Portability fixes applied"
# above for why -Werror is deliberately not used).
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(bem_matrix PRIVATE -Wall)
elseif(MSVC)
  target_compile_options(bem_matrix PRIVATE /W3)
endif()

# libm: required explicitly on Linux (glibc splits math functions out of
# libc), folded into libSystem already on macOS, and not a separate library
# under MSVC -- so only add it for the platforms that actually need it.
if(UNIX AND NOT APPLE)
  target_link_libraries(bem_matrix PRIVATE m)
endif()

install(TARGETS bem_matrix RUNTIME DESTINATION bin)
