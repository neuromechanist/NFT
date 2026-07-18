# asc

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

This README.md is NFT's own documentation of the vendored ASC source, which
carries its own upstream Tien-Tsin Wong / CUHK BSD-3-Clause copyright and is
unmodified except for the documented portability fixes.
-->

Adaptive Skeleton Climbing (ASC) isosurface extractor, from Tien-Tsin Wong's
ASC v2.01a package (The Chinese University of Hong Kong). Invoked as a
separate process by NFT's mesh-generation step
(`Mesh_generation.m:247` / `nft_mesh_generation.m:142`) to build scalp/skull/
brain surface meshes from segmented MRI volumes:
`asc1 -t 10 -dr1 <in.raw> K L M -f <out.asc> -ot`. Full license/provenance
record: `provenance/binaries.yaml` (entries `asc1`, `asc2`, `asc4`, `asc8`)
and `THIRD_PARTY_LICENSES/README.md`. Build instructions and per-platform
notes are in `CMakeLists.txt`.

## Status: rebuild reproduces the shipped binary's behaviour

`asc1` -- the only variant NFT actually invokes (`conf.asc = asc1` in
`nft_get_config.m`) -- rebuilds **byte-identical** to the shipped `asc1.osx`
on a real, full-size test case. `asc2`/`asc4`/`asc8` (built alongside it for
completeness, since they cost nothing extra and were shipped alongside
`asc1`) rebuild geometrically equivalent with a small, well-understood,
quantified divergence -- see below.

### What was verified (measured, not inferred)

1. **License.** Fetched `asc-201a.zip` fresh from the CUHK URL
   (`https://www.cse.cuhk.edu.hk/~ttwong/software/asc/asc-201a.zip`, sha256
   `d7f8c2f54accf5fc4a25c078c73ea7bfa3ae072dc10ec016e4a665423dcfc0ae`) and
   diffed its `LICENSE` file against the already-staged
   `THIRD_PARTY_LICENSES/ASC-TienTsinWong.txt` -- **byte-identical**, no
   correction needed this pass. (An earlier internal-archive-based survey had
   characterized ASC as academic/non-commercial-only; that was true of a
   stale 2004-vintage copy, not of this official v2.01a release, and had
   already been corrected in `provenance/binaries.yaml` before this import.)

2. **Build.** Native arm64 on Apple clang 21 (no Rosetta) -- a real platform
   win, since no arm64 `asc` build existed before this import; the shipped
   `asc1.osx` is x86_64-only. 4 documented, behavior-preserving portability
   fixes were required (see `CMakeLists.txt`'s "Portability fixes applied"):
   `void main` -> `int main` (asc.cpp), three dead/non-portable blind
   includes removed (vortex.h), and a `<values.h>`-vs-bundled-substitute
   `__has_include` guard fix (pcvalues.h, common.cpp, index.cpp) plus a
   redefinition-guard tightening surfaced by that fix. `otool -L` on all four
   built binaries shows only `libc++`/`libSystem` -- no GL/GLUT, confirming
   ASC's OpenGL dependency (`src/viewtri.cpp`, the package's separate mesh
   viewer) is genuinely unbuilt dead code for the tools NFT actually uses.

3. **Behavioural verification: rebuilt vs. shipped, real segmentation mask,
   identical output.** Loaded the real `Segm.scalpmask` (256x256x256
   `logical`) from `NFT_test/jc_segments.mat`, wrote it to `Scalp.raw` via
   the repo's own `Mesh_writeraw.m`, and ran both binaries with NFT's exact
   argument pattern:

   ```
   asc1 -t 10 -dr1 Scalp.raw 256 256 256 -f out.asc -ot
   ```

   shipped `asc1.osx` (run under Rosetta, `arch -x86_64`) vs. the rebuilt
   native-arm64 `asc1`, from the same input file, back to back:

   | variant | shipped triangles | rebuilt triangles | comparison |
   |---|---|---|---|
   | asc1 | 381040 | 381040 | **byte-identical** (`cmp`, matching sha256) |
   | asc2 | 95350  | 95350  | identical triangle multiset; some triangles' 3 vertices are emitted in a different order (winding-order permutation only -- zero coordinate differences) |
   | asc4 | 24986  | 24986  | same as asc2 |
   | asc8 | 9384   | 9384   | 9380/9384 (99.96%) identical; the remaining 4 triangles on each side reuse the exact same 6 vertex coordinates (bit-identical text) but pair them into a different local retriangulation of one ambiguous hexagonal patch |

   The asc2/asc4/asc8 divergences were quantified by parsing the TPoly-format
   (`-ot`) ASCII output into triangles, canonicalizing each triangle's 3
   vertex+normal lines into a sorted tuple, and comparing the resulting
   multisets -- not just a raw byte diff, which would have reported "differs"
   without distinguishing a real geometric divergence from an emission-order
   artifact. This is the well-known "ambiguous case" behavior of
   marching-cubes-family isosurface algorithms: when a local vertex
   configuration admits more than one valid manifold triangulation, the tie
   -break can depend on unordered-container iteration order, which is
   compiler/toolchain-sensitive, not an algorithmic bug. It appears only in
   `asc8` (the coarsest, most ambiguity-prone block size) and not at all in
   `asc1`/`asc2`/`asc4`, consistent with that explanation. NFT invokes only
   `asc1`, which is unaffected (byte-identical).

## Other notes

- `src/viewtri.cpp` (OpenGL/GLUT mesh viewer) and `src/trackball.cpp` (its
  mouse-rotation helper) are present in the tree but not compiled -- NFT
  never ships or calls a `viewtri` binary. See `CMakeLists.txt`'s "Files
  present but not compiled" section.
- `src/interface.cpp`/`src/interface.h` (a linkable-library calling
  convention) and `src/testlib.cpp` (its test driver) are present but not
  compiled either -- upstream's own Unix Makefile has no build rule for
  them (only the Windows `.dsp` project files reference them, which were not
  carried into this tree), and NFT calls the `asc1` CLI as a subprocess,
  never this library interface.
- `viewtri.cpp` is the *only* file in the entire package that references
  GL/GLUT (confirmed by grep across every `.cpp`/`.h` in the tree) -- so
  `asc1`/`asc2`/`asc4`/`asc8` have never had any OpenGL dependency, matching
  the shipped `asc1.osx`'s `otool -L`.
