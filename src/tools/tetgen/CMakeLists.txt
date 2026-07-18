# Author: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026
#
# Copyright (C) 2026 Seyed Yahya Shirazi, SCCN, INC, UCSD, shirazi@ieee.org
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# This file is NFT's own build configuration for the vendored TetGen source
# below (src/tetgen.cxx, src/predicates.cxx, src/tetgen.h, src/LICENSE) --
# those files carry their own upstream WIAS/AGPL copyright and are
# unmodified; only this CMakeLists.txt is NFT-authored.
#
# tetgen -- TetGen tetrahedral mesh generator / 3-D Delaunay triangulator
# ============================================================
#
# Upstream: TetGen, Hang Si, Weierstrass Institute for Applied Analysis and
# Stochastics (WIAS Berlin) (https://tetgen.org,
# https://codeberg.org/TetGen/TetGen). Vendored version 1.6.0, tag `v1.6.0`,
# commit 535f9c41f44abc832a7bbf2c9c7af003d1c18f3c (2020-08-31), fetched via
# `git clone https://codeberg.org/TetGen/TetGen.git` + `git checkout v1.6.0`.
# AGPL-3.0-or-later (dual-licensed with a commercial WIAS license -- see
# src/LICENSE, the exact file TetGen ships, and
# THIRD_PARTY_LICENSES/TetGen-AGPLv3.txt, relative to the repo root, which is
# byte-identical to the canonical text at
# https://www.gnu.org/licenses/agpl-3.0.txt). Full provenance record:
# provenance/binaries.yaml (entry name: tetgen).
#
# tetgen is a headless tetrahedral mesh generator invoked as a separate
# process from NFT's FEM mesh pipeline (nft_warping_mesh.m:321,333, via
# tetgen2msh.sh: `tetgen -pq1.4a5A <input>.smesh`), reading a piecewise
# linear complex (PLC) in `.smesh`/`.poly` format and writing the
# tetrahedralization as `.node`/`.ele`/`.face`/`.edge`. Pure, portable C++
# against only libc/libstdc++/libm -- confirmed against the shipped
# tetgen.osx: `otool -L` shows only libc++/libSystem, and upstream's own
# makefile links with `-lm` only.
#
# NFT invokes tetgen as a SEPARATE PROCESS (system()/shell calls), which is
# mere aggregation under GPLv2 Section 2's "mere aggregation... on a volume
# of storage" clause, not a derivative work. Independently, NFT's own root
# LICENSE is GPL-2.0-or-later, so it can resolve as GPLv3, and GPLv3 Section
# 13 explicitly permits combining GPLv3 code with AGPLv3 code. Both facts are
# recorded as the working position, not a settled legal conclusion -- see
# provenance/binaries.yaml and LICENSING.md.
#
# --------------------------------------------------------------------------
# Toolchain expectations
# --------------------------------------------------------------------------
# - CMake >= 3.16 (Ubuntu 20.04's stock cmake; also satisfied by every
#   Homebrew/Xcode cmake and GitHub Actions ubuntu-latest/macos-latest image).
# - A C++11-capable compiler. The source itself is C++03-vintage (no C++11
#   language features used), but we build it as C++11 rather than pinning an
#   ancient standard or leaving the compiler default unset, matching the
#   procmesh/bem_matrix convention -- confirmed to compile cleanly (warnings
#   only, see below) under `-std=c++11` with both g++ and Apple clang.
# - No external libraries beyond libm (see "Per-platform notes").
#
# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
#   cmake -S src/tools/tetgen -B build/tetgen -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/tetgen
#   # binary at build/tetgen/tetgen (or a per-config subdirectory on a
#   # multi-config generator, e.g. build/tetgen/Release/tetgen.exe on Visual
#   # Studio)
#
# Optional install step (stages the binary under CMAKE_INSTALL_PREFIX/bin,
# e.g. for CI artifact collection -- NFT's own runtime dispatch is not wired
# to this build yet; that is Phase 7, issue #43):
#   cmake --install build/tetgen --prefix build/tetgen/stage
#
# This builds the `tetgen` CLI executable only (tetgen.cxx + predicates.cxx,
# without -DTETLIBRARY). Upstream's own CMakeLists.txt additionally offers a
# `tet` static-library target (tetgen.cxx compiled with -DTETLIBRARY, for
# embedding TetGen as a callable library rather than invoking the CLI); NFT
# only ever invokes tetgen as a CLI subprocess (tetgen2msh.sh), so that
# target is intentionally not reproduced here. Add one if TETLIBRARY linkage
# is ever needed.
#
# --------------------------------------------------------------------------
# Why predicates.cxx is compiled separately, at -O0
# --------------------------------------------------------------------------
# predicates.cxx implements Jonathan Shewchuk's adaptive-precision exact
# geometric predicates (orient3d, insphere, etc.), which rely on IEEE-754
# double-rounding behaving exactly as written -- no operation reordering, no
# fused multiply-add contraction, no extended-precision intermediate
# registers. Aggressive optimization (in particular -O2/-O3, and especially
# -ffast-math or FMA contraction) can silently break the error-bound
# arithmetic these routines depend on, corrupting robustness in ways that
# only show up as rare, hard-to-reproduce mesh failures. Upstream's own
# makefile compiles predicates.cxx at a fixed `-O0` (`PREDCXXFLAGS = -O0`)
# independent of the optimization level used for tetgen.cxx itself
# (`CXXFLAGS = -O3`) -- this CMakeLists.txt preserves that split exactly via
# a per-source-file COMPILE_OPTIONS override, so predicates.cxx stays at
# -O0 regardless of CMAKE_BUILD_TYPE.
#
# --------------------------------------------------------------------------
# Per-platform notes
# --------------------------------------------------------------------------
# - Linux x86_64 / Mac arm64 (primary targets): build and run as-is with the
#   system compiler (gcc/g++ on Linux, Apple clang on macOS). Verified by
#   this import on macOS/Apple clang 21 (arm64): builds clean (warnings
#   only, see below) with ZERO source changes.
# - Mac x86_64 (legacy, build while free): same as Mac arm64, no known
#   platform-specific issue; not independently verified on real x86_64
#   hardware by this import -- flag if it breaks.
# - Windows (best-effort, never blocking): not built or tested on Windows as
#   part of this import. Upstream's own CMakeLists.txt has historically
#   supported MSVC, so no issue is expected.
#
# --------------------------------------------------------------------------
# Portability fixes applied
# --------------------------------------------------------------------------
# None. This source compiles and links cleanly on Apple clang 21 with no
# source edits (only the pre-existing -Wall diagnostics below).
#
# Pre-existing upstream -Wall diagnostics (not fixed, not behavior-affecting):
# tetgen.cxx has a handful of unused-variable/unused-but-set-variable
# warnings (dead debug-only locals) and deprecated-sprintf-usage warnings
# (sprintf is used throughout for filename/message formatting, not a
# behavior-affecting issue at these buffer sizes); predicates.cxx has four
# unused-function warnings (fast_expansion_sum, scale_expansion, compress,
# orient2dfast -- alternate/unused implementations kept in the original
# source). Same posture as procmesh/bem_matrix: -Wall, not -Werror -- this
# is a rebuild of legacy code, not a rewrite.
#
# --------------------------------------------------------------------------
# Files present but not compiled (kept for historical completeness)
# --------------------------------------------------------------------------
# - src/LICENSE: TetGen's own license file (the AGPLv3 full text plus the
#   dual-license preamble pointing to WIAS's commercial license). Kept
#   alongside the vendored source as upstream ships it; the repo-level copy
#   used for NFT's own THIRD_PARTY_LICENSES index is
#   THIRD_PARTY_LICENSES/TetGen-AGPLv3.txt (verified byte-identical to
#   https://www.gnu.org/licenses/agpl-3.0.txt).

cmake_minimum_required(VERSION 3.16)
project(tetgen CXX)

# Target name matches upstream's own historical CMakeLists.txt/makefile so
# any existing reference to "the tetgen target" (or the CLI invocation NFT
# already issues, `tetgen -pq1.4a5A <input>`) keeps working.
add_executable(tetgen
  src/tetgen.cxx
  src/predicates.cxx
)

# tetgen.h is header-only and pulled in transitively by both .cxx files
# above -- no separate compilation unit needed for it.

set_target_properties(tetgen PROPERTIES
  CXX_STANDARD 11
  CXX_STANDARD_REQUIRED ON
  CXX_EXTENSIONS OFF
)

# Upstream's own Makefile builds at -O3 for tetgen.cxx; CMAKE_BUILD_TYPE
# Release already supplies an equivalent optimization level via CMake's
# default flags, so no explicit override is added here for the main
# translation unit. predicates.cxx is pinned to -O0 below regardless of
# CMAKE_BUILD_TYPE -- see "Why predicates.cxx is compiled separately" above.
if(MSVC)
  set_source_files_properties(src/predicates.cxx PROPERTIES COMPILE_OPTIONS "/Od")
else()
  set_source_files_properties(src/predicates.cxx PROPERTIES COMPILE_OPTIONS "-O0")
endif()

# Baseline warning level, matching the procmesh/bem_matrix convention (not
# treated as errors -- see "Portability fixes applied" above for why
# -Werror is deliberately not used).
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(tetgen PRIVATE -Wall)
elseif(MSVC)
  target_compile_options(tetgen PRIVATE /W3)
endif()

# libm: required explicitly on Linux (glibc splits math functions out of
# libc), folded into libSystem already on macOS, and not a separate library
# under MSVC -- so only add it for the platforms that actually need it.
if(UNIX AND NOT APPLE)
  target_link_libraries(tetgen PRIVATE m)
endif()

install(TARGETS tetgen RUNTIME DESTINATION bin)
