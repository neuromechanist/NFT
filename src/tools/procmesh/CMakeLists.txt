# procmesh -- EMSI Tools Package mesh processing utility
# ============================================================
#
# Upstream: EMSI Tools Package, Brain Research Laboratory, Middle East
# Technical University (METU). Copyright (C) 2008 Zeynep Akalin Acar,
# Can Erkin Acar, Nevzat G. Gencer. GPL-2.0-or-later (full text at
# THIRD_PARTY_LICENSES/GPL-2.0.txt, relative to the repo root) with one
# separately-licensed file, src/strlcpy.c (OpenBSD/ISC, Todd C. Miller
# 1998; see THIRD_PARTY_LICENSES/strlcpy-OpenBSD.txt). Full provenance
# record: provenance/binaries.yaml (entry name: procmesh).
#
# procmesh is a headless mesh-processing tool (self-intersection repair,
# vertex merging, edge splitting/flipping, etc.) invoked mid-pipeline by
# NFT's warping and DSL steps via `procmesh -c <script>`. It is pure,
# portable C++ against only libc/libstdc++ -- no OpenGL/GLUT despite an
# unused mouse.h header (see the "Files present but not compiled" note
# below), no other third-party library. Confirmed against the shipped
# procmesh.osx binary: `otool -L` shows only libstdc++/libSystem.
#
# --------------------------------------------------------------------------
# Toolchain expectations
# --------------------------------------------------------------------------
# - CMake >= 3.16 (Ubuntu 20.04's stock cmake; also satisfied by every
#   Homebrew/Xcode cmake and GitHub Actions ubuntu-latest/macos-latest image).
# - A C++11-capable compiler. The source itself is C++03-vintage (no C++11
#   language features used), but we build it as C++11 rather than pinning
#   an ancient standard or leaving the compiler default unset: it costs
#   nothing here (nothing in the source forbids it) and avoids surprises
#   from a toolchain's shifting default standard.
# - No external libraries. On a clean checkout, configuring this directory
#   needs nothing beyond a C/C++ compiler -- no zlib, no PETSc, no GL, no
#   Boost.
#
# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
#   cmake -S src/tools/procmesh -B build/procmesh -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/procmesh
#   # binary at build/procmesh/procmesh (or a per-config subdirectory on a
#   # multi-config generator, e.g. build/procmesh/Release/procmesh.exe on
#   # Visual Studio)
#
# Optional install step (stages the binary under CMAKE_INSTALL_PREFIX/bin,
# e.g. for CI artifact collection -- NFT's own runtime dispatch is not wired
# to this build yet; that is Phase 7, issue #43):
#   cmake --install build/procmesh --prefix build/procmesh/stage
#
# --------------------------------------------------------------------------
# Files present but not compiled (kept for historical completeness)
# --------------------------------------------------------------------------
# - src/mouse.h: a GLUT mouse-interaction helper, only ever active when the
#   including file #defines __GLUTMOUSE__ before including it. No compiled
#   source in this tree does that (confirmed: neither __GLUTMOUSE__ nor a
#   #include "mouse.h" appears anywhere outside mouse.h itself), which is
#   why the shipped procmesh.osx has no OpenGL linkage at all. Upstream's
#   own Makefile already had its `-lglut -lGL -lGLU` LIBS line commented
#   out for the same reason. Kept in the tree and excluded from the build
#   so the historical source is complete rather than silently pruned.
# - src/sstore.h: a small spatial-store header with no includer anywhere in
#   the upstream tree (confirmed by grep across the archive) -- dead/
#   orphaned even in the original source, not something this import broke.
#   Kept for the same reason as mouse.h.
#
# --------------------------------------------------------------------------
# Per-platform notes
# --------------------------------------------------------------------------
# - Linux x86_64 / Mac arm64 (primary targets): build and run as-is with the
#   system compiler (gcc/g++ on Linux, Apple clang on macOS).
# - Mac x86_64 (legacy, build while free): same as Mac arm64, no known
#   platform-specific issue; not independently verified on real x86_64
#   hardware by this import -- flag if it breaks.
# - Windows (best-effort, never blocking): not built or tested on Windows as
#   part of this import. printf's %zu format (used for one fix below) is
#   supported by MSVC's UCRT (VS2015+) but NOT by the legacy pre-2015 MSVC
#   CRT -- if an old MSVC toolchain is ever targeted, that is the first
#   thing to check.
#
# --------------------------------------------------------------------------
# Portability fixes applied (all behavior-preserving; see git history for
# the exact diffs and commit messages)
# --------------------------------------------------------------------------
# - src/mesh.cxx: one printf format-specifier fix, %d -> %zu for a
#   TriMeshLin::elist_t::size() (size_t) argument -- undefined behavior on
#   LP64 platforms per the C standard, though harmless in practice at the
#   mesh sizes this tool handles. See the inline comment at the fix site.

cmake_minimum_required(VERSION 3.16)
project(procmesh CXX C)

# Target name matches upstream's own historical CMakeLists.txt so any
# existing reference to "the procmesh target" keeps working.
add_executable(procmesh
  src/command.cxx
  src/main.cxx
  src/mesh.cxx
  src/meshbase.cxx
  src/meshproc.cxx
  src/point3.cxx
  src/procmesh.cxx
  src/scache.cxx
  src/strlcpy.c
)

# rect3.h / sphere3.h / point3.h / mesh.h / meshbase.h / meshproc.h /
# procmesh.h / command.h / scache.h are header-only and pulled in
# transitively by the .cxx files above (e.g. scache.h -> sphere3.h ->
# rect3.h) -- no separate compilation unit needed for any of them.

set_target_properties(procmesh PROPERTIES
  CXX_STANDARD 11
  CXX_STANDARD_REQUIRED ON
  CXX_EXTENSIONS OFF
)

# Upstream's own Makefile built with -Wall; keep that as a baseline warning
# level here too (not treated as errors -- this is a rebuild of legacy code,
# not a rewrite, and -Werror could force non-behavior-preserving changes
# just to silence an incidental warning in 2010-vintage source).
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(procmesh PRIVATE -Wall)
elseif(MSVC)
  target_compile_options(procmesh PRIVATE /W3)
endif()

install(TARGETS procmesh RUNTIME DESTINATION bin)
