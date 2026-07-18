# qslim -- QSlim quadric-based mesh simplification CLI
# ============================================================
#
# Upstream: SlimKit / QSlim / MixKit / libgfx, Copyright (C) 1998-2002
# Michael Garland. The CLI driver (tools/qslim/) is GPL-2.0-or-later (full
# text at THIRD_PARTY_LICENSES/GPL-2.0.txt, relative to the repo root); the
# MixKit library it links against is LGPL-2.0-or-later with an explicit
# static/dynamic linking exception (mixkit/COPYING.txt); libgfx (the
# vector/matrix support library MixKit itself is built on) is MIT-style.
# Full text of all three: THIRD_PARTY_LICENSES/qslim-GPL-LGPL-mixkit.txt and
# THIRD_PARTY_LICENSES/libgfx-MIT.txt. Full provenance record:
# provenance/binaries.yaml (entry name: qslim).
#
# qslim is a headless mesh-simplification tool invoked mid-pipeline by NFT's
# mesh generation step (Mesh_generation.m:320 / nft_mesh_generation.m:210)
# as `qslim -c 0.5 -m 5 -o <out.smf> -t <target_faces> <in.smf>` to reduce a
# BEM boundary mesh to a target triangle count.
#
# --------------------------------------------------------------------------
# Why this source tree does not look like upstream's
# --------------------------------------------------------------------------
# Upstream's own repository (https://github.com/alecjacobson/qslim, the
# only public copy found that includes the actual CLI driver source --
# tools/qslim/main.cxx and qslim.cxx were MISSING from the SCCN internal
# archive, which had only libgfx + mixkit with tools/qslim/ present as an
# empty shell) is a full graphics SDK: an interactive `qvis` GUI viewer
# (FLTK + OpenGL), a mesh-clustering tool, half a dozen SMF filter
# utilities, curvature/principal-frame fitting code, texture-mapped raster
# I/O against libtiff/libpng/libjpeg, IDE project files for four different
# decades-old toolchains, and so on. NFT ships and calls exactly one binary
# out of all of that: the `qslim` CLI. This import brings in only the
# source files that binary's link actually needs -- verified by building it
# and checking for undefined symbols, the same way bem_matrix (#39/#60) and
# procmesh (#39/#57-58) were verified -- not a mechanical copy of the
# upstream tree. Three source subtrees, mirroring upstream's own module
# boundaries:
#   src/qslim/   -- the CLI driver itself (tools/qslim/ upstream, minus the
#                    qvis.cxx GUI viewer -- see below)
#   src/mixkit/  -- the simplification library subset the CLI needs
#   src/libgfx/  -- the vector/matrix/raster support library mixkit needs
#
# --------------------------------------------------------------------------
# [CRITICAL] The non-commercial-code landmine -- how it was resolved
# --------------------------------------------------------------------------
# mixkit/COPYING.txt itself discloses that a handful of files under
# mixkit/src/ are carved out of the LGPL and are "free for non-commercial
# use only": MxMat3-jacobi.cxx / MxMat4-jacobi.cxx (adapted from VTK, which
# in turn adapted them from Numerical Recipes in C) and MxTriProject.cxx
# (Hugues Hoppe). Numerical-Recipes-derived code is well known to be
# GPL-incompatible -- shipping it in this repo at all, even uncompiled,
# would taint a GPL-2.0-or-later project with an added restriction the GPL
# forbids.
#
# Resolution: these files, and everything that exclusively exists to serve
# them, are simply not present in this import -- not "present but excluded
# from the build" (procmesh/bem_matrix's usual posture for genuinely dead
# code), but never copied into the repository in the first place, because
# unlike mouse.h or bem_solve.cpp these are files whose upstream license
# text is itself incompatible with the project's own license. Concretely,
# not imported:
#   - MxMat3-jacobi.cxx, MxMat4-jacobi.cxx, MxTriProject.cxx (the tainted
#     files themselves)
#   - MxFitFrame.cxx / MxFitFrame-2.cxx / MxFitFrame-vis.cxx / MxFitFrame.h
#     (principal-frame curvature fitting -- the ONLY caller of jacobi() /
#     fast_jacobi() anywhere in the upstream tree; grep-confirmed against
#     the full fetched upstream source, not just this subset)
#   - MxFaceTree.cxx / MxFaceTree-2.cxx / MxFaceTree.h, MxDualModel.*,
#     MxDualSlim.*, MxEdgeFilter.*, MxFeatureFilter.* (a face-clustering
#     cluster that derives MxFaceCluster from MxFitFrame, so it cannot link
#     without the tainted code -- and, independently, none of it is on the
#     qslim CLI's call graph either)
#
# PROOF the resulting binary is clean, not just an assertion:
#   1. Source-list proof: grep across every upstream .h/.cxx file actually
#      compiled into this target (see the add_executable() list below) for
#      "jacobi", "Jacobi", "TriProject", and "FitFrame" -- zero hits. None
#      of the tainted files, or their exclusive dependents, are inputs to
#      this build at all.
#   2. Symbol proof: `nm` on the built qslim binary contains no `jacobi`,
#      `fast_jacobi`, or `MxTriProject`-related symbol (mangled or
#      demangled) -- confirmed on the arm64 rebuild produced by this
#      CMakeLists.txt. This is a structural guarantee, not incidental: since
#      the source files are absent, the symbols cannot appear by
#      construction, and the check is there to catch a future accidental
#      re-introduction, not because the outcome was in doubt.
#   3. Behavioural proof: MxMat3.h/MxMat4.h still `extern`-declare
#      jacobi()/fast_jacobi() (upstream headers, kept as-is), but a
#      declaration alone creates no link dependency -- only a call does,
#      and the qslim CLI's actual decimation path (MxQSlim -> MxQMetric3,
#      the quadric error metric) computes its vertex placement via closed-
#      form linear algebra on the 4x4 quadric, never via eigendecomposition.
#      The full build (this CMakeLists.txt) links successfully with zero
#      undefined symbols with all four tainted-or-tainted-dependent file
#      groups completely absent, which is itself the proof that nothing on
#      the shipped CLI's path needed them -- no replacement eigensolver was
#      required (task option 1: exclude, not option 2: replace).
#
# --------------------------------------------------------------------------
# Other things present upstream and deliberately not imported (not a
# licensing problem, just out of scope for the one binary NFT ships)
# --------------------------------------------------------------------------
# - tools/qslim/qvis.cxx (+ qvis_obj.sh): the companion interactive GUI
#   viewer, sharing cmdline.cxx/main.cxx/output.cxx with qslim but requiring
#   FLTK + OpenGL. NFT never ships or calls a `qvis` binary (checked: no
#   such file, no such provenance/binaries.yaml entry, no NFT .m file
#   references it) -- same treatment as bem_matrix's bem_solve.cpp, except
#   here the sibling needs a real external GUI/GL dependency stack this
#   repo has no reason to acquire, so unlike bem_solve.cpp it is not kept
#   in the tree as an uncompiled file.
# - mixkit's GL_SRCS (MxCamera/MxQVis3/MxStdRender/MxGLDebug/MxGLUtils) and
#   GUI_SRCS (MxStdGUI): OpenGL/FLTK-only, exclusively for qvis.
# - libgfx's GUI_SRCS (gui/gltools/baseball/trackball/arcball.cxx) and
#   MISC_SRCS' script.cxx: OpenGL/FLTK-only or unused by anything on the
#   qslim CLI's include graph (confirmed: no compiled file here includes
#   gfx/script.h, gfx/gui.h, or gfx/gltools.h).
# - libgfx's quat.cxx / symmat3.cxx (VEC_SRCS entries): not referenced by
#   anything on the qslim CLI's include graph either (confirmed the same
#   way -- no compiled file here includes gfx/quat.h or gfx/symmat3.h).
# - mixkit's MxQMetric.cxx / MxPropSlim.cxx (a second, alternative
#   "property-preserving" simplification mode, MxMatrix.cxx and
#   MxVector.h's optional MxMatrix-based path): the qslim CLI's main.cxx
#   only ever instantiates MxEdgeQSlim/MxFaceQSlim (plain quadric-error
#   simplification, MxQSlim.h) -- MxPropSlim is a different, unused C++
#   class with no CLI flag that selects it.
#
# --------------------------------------------------------------------------
# config.h: authored here, not run through upstream's autoconf `configure`
# --------------------------------------------------------------------------
# libgfx/include/gfx/gfx.h does `#if defined(HAVE_CONFIG_H) #include
# "config.h"`. Upstream generates that file with a 2002-vintage autoconf
# `configure` script (X11/FLTK-oriented, and upstream's own fetched fork
# ships a real, already-`configure`d config.h with HAVE_LIBJPEG/HAVE_LIBTIFF
# baked in from whatever image libraries happened to be on the maintainer's
# machine). Neither is appropriate for a from-scratch CMake rebuild that
# should not silently pick up a contributor's local libjpeg/libtiff, so
# src/libgfx/include/gfx/config.h in this tree is authored directly (NFT
# GPL header, see the file itself) rather than copied from upstream or
# autoconf-generated. It deliberately leaves HAVE_LIBTIFF / HAVE_LIBPNG /
# HAVE_LIBJPEG / HAVE_FLTK / HAVE_OPENGL undefined: raster-{tiff,png,jpeg}.cxx
# already have upstream-authored `#else` stub bodies for exactly this case
# (return false / NULL when the library isn't available), so the qslim CLI
# builds and runs with zero image-codec library dependencies, matching what
# it actually needs (NFT's SMF meshes carry no textures).
#
# mixkit's own mixcfg.h.in template is NOT instantiated at all: grep across
# the entire fetched upstream tree (not just this subset) shows nothing
# ever `#include`s "mixcfg.h" -- it is dead autoconf scaffolding upstream
# itself does not use in the shipped headers.
#
# --------------------------------------------------------------------------
# Toolchain expectations
# --------------------------------------------------------------------------
# - CMake >= 3.16, a C++11-capable compiler -- same baseline as
#   bem_matrix/procmesh. The source is C++98/03-vintage SGI-STL-era code
#   (uses `bool`/`iostream`, nothing C++11-specific); built as C++11 for the
#   same reason as the other two imports: costs nothing, avoids a
#   toolchain's shifting default standard.
# - No external libraries: no FLTK, no OpenGL, no libjpeg/libpng/libtiff --
#   see "config.h" above for why the image-codec libraries in particular
#   are not needed despite libgfx's raster support having historically
#   linked against them.
#
# --------------------------------------------------------------------------
# Build
# --------------------------------------------------------------------------
#   cmake -S src/tools/qslim -B build/qslim -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/qslim
#   # binary at build/qslim/qslim (or a per-config subdirectory on a
#   # multi-config generator, e.g. build/qslim/Release/qslim.exe on Visual
#   # Studio)
#
# Optional install step (stages the binary under CMAKE_INSTALL_PREFIX/bin,
# e.g. for CI artifact collection -- NFT's own runtime dispatch is not wired
# to this build yet; that is Phase 7, issue #43):
#   cmake --install build/qslim --prefix build/qslim/stage
#
# --------------------------------------------------------------------------
# Per-platform notes
# --------------------------------------------------------------------------
# - Linux x86_64 / Mac arm64 (primary targets): build and run as-is with the
#   system compiler. Verified by this import on macOS/Apple clang (arm64) --
#   a real platform win, since no arm64 qslim existed before this rebuild
#   (the shipped qslim.osx is x86_64-only and needs Rosetta on Apple
#   Silicon). Not independently verified on Linux/g++ by this import; flag
#   if it breaks -- nothing in the source or this CMakeLists.txt is
#   macOS-specific, so no issue is expected.
# - Mac x86_64 (legacy, build while free): same as Mac arm64, no known
#   platform-specific issue; not independently verified on real x86_64
#   hardware by this import.
# - Windows (best-effort, never blocking): not built or tested on Windows as
#   part of this import. cmdline.cxx's getopt() call needs <unistd.h>'s
#   getopt (present on Linux/macOS); a Windows build would need a getopt
#   shim -- the first thing to check if this is ever targeted there.
#
# --------------------------------------------------------------------------
# Portability fixes applied
# --------------------------------------------------------------------------
# None. Every file in this import compiles unmodified on Apple clang (this
# import's verification toolchain) -- byte-identical to what was fetched
# from upstream, aside from the deliberate file-selection choices documented
# above. Same posture as bem_matrix (#39/#60): -Wall, not -Werror, since
# this is a rebuild of legacy code, not a rewrite. Pre-existing upstream
# -Wall diagnostics (not fixed, not behavior-affecting): ISO-C++11-forbidden
# string-literal-to-char* conversions (the code passes string literals into
# char* parameters throughout -- the same pattern procmesh/bem_matrix
# already noted), a handful of unused-variable/unused-private-field
# warnings, one non-virtual-destructor-with-virtual-functions warning in
# MxSMF.h's MxSMFReader, and one deprecated-vsprintf warning in mixmsg.cxx.
#
# --------------------------------------------------------------------------
# -ffp-contract=off: required for bit-for-bit parity with the shipped binary
# --------------------------------------------------------------------------
# Without this flag, the arm64 rebuild's SMF output diverges from the
# shipped qslim.osx (run under Rosetta) by a small but real amount -- a few
# vertices out of a few thousand shifted by up to ~1-4% of the mesh's
# bounding-box diagonal, and a proportionally small number of faces
# connected differently (all measured; see the PR description / commit
# message for the exact figures across four real NFT_test meshes). Root
# cause, isolated experimentally: Apple clang emits fused multiply-add
# (FMA) instructions by default on arm64 (its NEON FMA unit), silently
# changing the rounding of the quadric-error-metric arithmetic in
# MxQMetric3 relative to the shipped binary, which was built for x86_64
# hardware that (given its vintage) never had FMA in the first place. That
# tiny per-operation rounding difference is enough to occasionally flip
# which of two near-equal-cost edge contractions MxHeap pops first, and
# greedy decimation lets that one flipped tie cascade into a handful of
# genuinely different contraction choices over thousands of steps.
# Disabling FMA contraction removes the rounding difference at its source:
# with -ffp-contract=off, the rebuilt arm64 binary's output is BYTE-FOR-BYTE
# IDENTICAL to the shipped x86_64 binary's, verified on all four boundary
# meshes in NFT_test (Scalp/Skull/Csf/Brain) at NFT's real CLI invocation
# (`-c 0.5 -m 5 -t <target>`). This is the strongest verification result of
# the three binaries imported so far (bem_matrix and procmesh both settled
# for "floating-point round-off, not byte-identical"). Only meaningful for
# GCC/Clang (see the -ffp-contract=off target_compile_options() call below);
# MSVC has no equivalent flag and does not contract FP ops by default in the
# same way, so this is a non-issue there -- and Windows is best-effort/never
# blocking regardless (see "Per-platform notes" above).

cmake_minimum_required(VERSION 3.16)
project(qslim CXX)

# Target name matches upstream's own historical Makefile target so any
# existing reference to "the qslim target" keeps working.
add_executable(qslim
  src/qslim/cmdline.cxx
  src/qslim/main.cxx
  src/qslim/output.cxx
  src/qslim/qslim.cxx
  src/mixkit/mixmsg.cxx
  src/mixkit/MxAsp.cxx
  src/mixkit/MxBlockModel.cxx
  src/mixkit/MxCmdParser.cxx
  src/mixkit/MxGeom3D.cxx
  src/mixkit/MxHeap.cxx
  src/mixkit/MxQMetric3.cxx
  src/mixkit/MxQSlim.cxx
  src/mixkit/MxSMF.cxx
  src/mixkit/MxStdModel.cxx
  src/mixkit/MxStdSlim.cxx
  src/libgfx/src/geom3d.cxx
  src/libgfx/src/mat2.cxx
  src/libgfx/src/mat3.cxx
  src/libgfx/src/mat4.cxx
  src/libgfx/src/raster.cxx
  src/libgfx/src/raster-jpeg.cxx
  src/libgfx/src/raster-png.cxx
  src/libgfx/src/raster-pnm.cxx
  src/libgfx/src/raster-tiff.cxx
  src/libgfx/src/time.cxx
)

# qslim.h / MxAsp.h / MxBlock.h / MxBlockModel.h / MxCmdParser.h /
# MxDynBlock.h / MxGeom3D.h / MxGeoPrims.h / MxHeap.h / MxMat2.h / MxMat3.h /
# MxMat4.h / MxMath.h / MxQMetric3.h / MxQSlim.h / MxRaster.h / MxSMF.h /
# MxStack.h / MxStdModel.h / MxStdSlim.h / MxTimer.h / MxVec3.h / MxVec4.h /
# MxVector.h / mixio.h / mixmsg.h / mixvops.h / stdmix.h and every gfx/*.h
# are header-only or pulled in transitively by the .cxx files above -- no
# separate compilation unit needed for any of them. This exact header set
# is not a guess: it is the verified `-MM` dependency closure of the
# add_executable() list above (every header actually reached while
# compiling this target, and nothing else).
target_include_directories(qslim PRIVATE
  src/qslim
  src/mixkit
  src/libgfx/include
)

# HAVE_CONFIG_H: makes libgfx/include/gfx/gfx.h pull in our authored
# src/libgfx/include/gfx/config.h (see the long comment above).
target_compile_definitions(qslim PRIVATE HAVE_CONFIG_H)

set_target_properties(qslim PROPERTIES
  CXX_STANDARD 11
  CXX_STANDARD_REQUIRED ON
  CXX_EXTENSIONS OFF
)

# Upstream's own Makefiles built with -Wall; keep that as a baseline warning
# level here too (not treated as errors -- see "Portability fixes applied"
# above for why -Werror is deliberately not used). -ffp-contract=off is not
# a warning-level flag; it is required for bit-for-bit parity with the
# shipped binary -- see "-ffp-contract=off" above for why.
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(qslim PRIVATE -Wall -ffp-contract=off)
elseif(MSVC)
  target_compile_options(qslim PRIVATE /W3)
endif()

# libm: required explicitly on Linux (glibc splits math functions out of
# libc), folded into libSystem already on macOS, and not a separate library
# under MSVC -- so only add it for the platforms that actually need it.
if(UNIX AND NOT APPLE)
  target_link_libraries(qslim PRIVATE m)
endif()

install(TARGETS qslim RUNTIME DESTINATION bin)
