# qslim

<!--
Author: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026

Copyright (C) 2026 Seyed Yahya Shirazi, SCCN, INC, UCSD, shirazi@ieee.org

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

This README.md is NFT's own documentation of the vendored QSlim / MixKit /
libgfx source, which carries its own upstream Michael Garland copyright and
GPL/LGPL/MIT headers and is unmodified.
-->

Headless quadric-based surface mesh simplification (QSlim, Michael Garland)
used during NFT's mesh generation step to reduce a BEM boundary mesh to a
target triangle count. Invoked as a separate process
(`Mesh_generation.m:320` / `nft_mesh_generation.m:210`):

```
qslim -c 0.5 -m 5 -o <out.smf> -t <target_faces> <in.smf>
```

reading/writing meshes in the SMF (Simple Model Format) triangle-mesh
format. Full license/provenance record: `provenance/binaries.yaml` (entry
name: `qslim`) and `THIRD_PARTY_LICENSES/README.md`. Build instructions,
scope rationale, and the non-commercial-code exclusion are all documented
in `CMakeLists.txt` -- not repeated here.

## Status: rebuild is byte-for-bit identical to the shipped binary

This is the strongest verification result of the three binaries imported so
far under Epic 1 (bem_matrix and procmesh both settled for "floating-point
round-off, not byte-identical" -- see their own READMEs).

### What was verified (measured, not inferred)

1. **CLI driver source recovery.** The SCCN internal archive had `libgfx` +
   `mixkit` source but `tools/qslim/` (the actual CLI driver:
   `main.cxx`/`qslim.cxx`/`cmdline.cxx`/`output.cxx`) was an empty shell.
   This import fetched the complete missing source from
   <https://github.com/alecjacobson/qslim>, the only public copy found that
   includes it, confirmed the license texts staged in
   `THIRD_PARTY_LICENSES/qslim-GPL-LGPL-mixkit.txt` and
   `THIRD_PARTY_LICENSES/libgfx-MIT.txt` match what was actually fetched
   (byte-for-byte diff against `COPYING.txt`/`mixkit/COPYING.txt`/
   `libgfx/doc/license.html` in the fetched tree), and imported only the
   ~45 files (of several hundred in the full upstream SDK) the qslim CLI's
   link actually needs -- see `CMakeLists.txt` for the full scope rationale
   and the non-commercial-code (Numerical Recipes derived) exclusion this
   import had to navigate.

2. **Zero source changes.** Every file in this import compiles unmodified
   (only `src/libgfx/include/gfx/config.h` is authored here rather than
   copied from upstream -- see `CMakeLists.txt`). Same posture as
   bem_matrix (#39/#60): -Wall, not -Werror; a handful of pre-existing
   upstream warnings (string-literal-to-char*, a few unused variables) are
   left as-is, not behavior-affecting.

3. **Behavioural verification: rebuilt vs. shipped, real meshes, exact
   NFT CLI invocation, byte-identical output.** Built this source with a
   fresh CMake configuration (Apple clang, arm64, this `CMakeLists.txt`)
   and ran it against all four real BEM boundary meshes in `../NFT_test`
   (`Scalp.smf`, `Skull.smf`, `Csf.smf`, `Brain.smf`), once with the
   rebuilt binary and once with the shipped `qslim.osx` (run under Rosetta,
   since it is x86_64-only), using NFT's actual argument contract:

   ```
   qslim -c 0.5 -m 5 -o out.smf -t <target> in.smf
   ```

   Initial/final vertex and face counts matched exactly in every case
   (e.g. Scalp: 4621v/9238f -> 2502v/5000f on both binaries). The first
   build (default compiler flags) was NOT byte-identical: a small number
   of vertices/faces diverged (worst case, the most aggressive decimation
   tested -- Csf.smf, 28492->4000 faces -- showed 54/4000 faces connected
   differently, vertices shifted by up to ~4% of the mesh's bounding-box
   diagonal). Root-caused to Apple clang's default FMA (fused
   multiply-add) instruction contraction on arm64 changing the rounding of
   quadric-error-metric arithmetic relative to the shipped binary (built
   for FMA-less-vintage x86_64 hardware), which occasionally flips a
   near-tied edge-contraction order in the decimation heap and cascades
   into a handful of genuinely different contraction choices. Building
   with `-ffp-contract=off` (now baked into `CMakeLists.txt`) removes the
   rounding difference at its source: **`cmp` reports zero differences
   between the rebuilt and shipped SMF output on all four test meshes.**
   Both binaries are also independently deterministic (each reproduces its
   own output exactly across repeated runs), confirming the divergence
   before the fix was a genuine toolchain/architecture floating-point
   effect, not non-determinism in either binary.

4. **Non-commercial-code landmine: resolved by exclusion, proven clean.**
   `nm` on the built `qslim` binary contains no `jacobi`, `fast_jacobi`, or
   `MxTriProject` symbol (mangled or demangled); grepping the actual
   compiled-input file list in `CMakeLists.txt`'s `add_executable()` finds
   no `jacobi`/`Jacobi`/`TriProject`/`FitFrame` text at all -- the tainted
   files (Numerical-Recipes-derived `MxMat3-jacobi.cxx` /
   `MxMat4-jacobi.cxx`, Hugues-Hoppe `MxTriProject.cxx`) and everything
   that exclusively depends on them (`MxFitFrame*`, `MxFaceTree*`,
   `MxDualModel*`, `MxDualSlim*`, `MxEdgeFilter*`, `MxFeatureFilter*`)
   were never copied into this repository at all -- not merely excluded
   from the CMake build. `MxMat3.h`/`MxMat4.h` still `extern`-declare
   `jacobi()`/`fast_jacobi()` (kept as-is, upstream headers), but nothing
   in the qslim CLI's actual call graph (verified: the full build links
   with zero undefined symbols with the tainted cluster completely absent)
   calls them -- QSlim's quadric-error vertex placement is closed-form
   linear algebra on the 4x4 quadric, not an eigendecomposition. No
   replacement eigensolver was needed. Full reasoning: `CMakeLists.txt`'s
   "[CRITICAL] The non-commercial-code landmine" section.

### Why this is a stronger result than bem_matrix's or procmesh's

bem_matrix's rebuild agreed with the shipped binary "to within
floating-point round-off of a different compiler/toolchain, not necessarily
byte-identical." procmesh's shipped binary had an outright source/binary
divergence (a CLI command the archived source didn't have). qslim's rebuild
started with the same kind of small floating-point divergence bem_matrix
settled for, but this import went one step further, isolated the exact
compiler behavior responsible (arm64 FMA contraction), and eliminated it --
landing on an exact match rather than an accepted tolerance.

## Other notes

- The rebuilt `qslim` is a genuine platform win independent of the
  byte-identical result: it is the first **native arm64** qslim. The
  shipped `qslim.osx` is x86_64-only and requires Rosetta on Apple Silicon.
- `qvis` (the upstream companion interactive GUI viewer, FLTK + OpenGL) and
  a large amount of the rest of the upstream SDK (mesh clustering, SMF
  filter utilities, curvature/principal-frame fitting, IDE project files)
  are not imported -- NFT never ships or calls anything but the `qslim`
  CLI. See `CMakeLists.txt`'s "Other things ... deliberately not imported"
  section.
