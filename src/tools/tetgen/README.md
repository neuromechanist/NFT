# tetgen

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

This file documents the vendored TetGen source below (src/tetgen.cxx,
src/predicates.cxx, src/tetgen.h, src/LICENSE), which carries its own
upstream WIAS/AGPL copyright and is unmodified; only this README.md is
NFT-authored.
-->

TetGen, Hang Si's tetrahedral mesh generator / 3-D Delaunay triangulator
(WIAS Berlin). Invoked as a separate process by NFT's FEM mesh pipeline
(`nft_warping_mesh.m:321,333`, via `tetgen2msh.sh`: `tetgen -pq1.4a5A
<input>.smesh`), reading a piecewise linear complex (PLC) in `.smesh`/
`.poly` format and writing the tetrahedralization as
`.node`/`.ele`/`.face`/`.edge`, which `tetgen2msh.sh` then converts to NFT's
own `.msh` format with per-tissue conductivities. Full license/provenance
record: `provenance/binaries.yaml` (entry name: `tetgen`) and
`THIRD_PARTY_LICENSES/README.md`. Build instructions and per-platform notes
are in `CMakeLists.txt`.

## Status: rebuild is byte-identical to the shipped binary's output

This import fills the repo's most acute compliance gap: `tetgen`,
`tetgen.exe`, and `tetgen.osx` previously shipped with **no source and no
license text at all**. Both are now present, and the rebuild's output
matches the shipped `tetgen.osx` binary **exactly** (modulo one banner line
that echoes `argv[0]`) on a real, full-size test case.

### Source

- Upstream: TetGen, Hang Si / WIAS Berlin
  (`https://tetgen.org`, `https://codeberg.org/TetGen/TetGen`).
- Vendored version: **1.6.0**, tag `v1.6.0`, commit
  `535f9c41f44abc832a7bbf2c9c7af003d1c18f3c` (2020-08-31), fetched via
  `git clone https://codeberg.org/TetGen/TetGen.git` then
  `git checkout v1.6.0`.
- Version banner confirmed: `tetgen.h`/`tetgen.cxx` headers read "Version
  1.6.0 / August 31, 2020 / Copyright (C) 2002--2020"; the CLI's own
  `-h`/version output prints "Version 1.6" and "Copyright (C) 2002 - 2020",
  matching the shipped `tetgen.osx`/`tetgen.exe` banners recorded in
  `provenance/binaries.yaml` exactly.
- sha256 of the vendored sources (as fetched, before any local change --
  none were needed):
  - `tetgen.cxx`: `a10f5e74c3ec45ffda3d9609b1cb6e864f1a628b4c2e3e61cabd49ddfccc36bc`
  - `predicates.cxx`: `5a050a2391e8dea44f6aba176372ba790667d553b98c7eea4bb351eabc81c050`
  - `tetgen.h`: `69b012da7c0b01e6327f5f281ac2d10fc3fb42503d22366c7bd0bc9181bd833b`
  - `LICENSE`: `f15e3301d0f40116aa2e3567963c3dcc8dd45453337dedf592caa73a5390549f`

### Why v1.6.0, not the shipped Linux `tetgen`'s v1.4.3

Three different tetgen binaries ship in this repo, two of which
(`tetgen.osx`, `tetgen.exe`) are already v1.6 (August 2020); only the Linux
`tetgen` binary is the older v1.4.3 (2009), which also predates TetGen's
switch to AGPLv3 at v1.5.0. A single modern version (1.6.0) covers all three
platforms and matches what two of the three shipped binaries already are;
the archived Linux v1.4.3 binary is superseded by a v1.6.0 rebuild here
rather than reproduced as-is. This unifies the project on one TetGen version
going forward instead of perpetuating a three-way version split.

### License

TetGen v1.5+ is dual-licensed: AGPL-3.0-or-later, or a commercial WIAS
license. `src/LICENSE` is upstream's own license file (AGPLv3 full text plus
the dual-license preamble); the repo-level copy at
`THIRD_PARTY_LICENSES/TetGen-AGPLv3.txt` was diffed byte-for-byte against
`https://www.gnu.org/licenses/agpl-3.0.txt` and is **identical**.

NFT invokes `tetgen` as a **separate process** (`system()`/shell calls from
`nft_warping_mesh.m` via `tetgen2msh.sh`), which is mere aggregation under
GPLv2 Section 2's "mere aggregation... on a volume of storage" clause, not a
derivative work. Independently, NFT's own root `LICENSE` is
GPL-2.0-or-later, so it can resolve as GPLv3, and GPLv3 Section 13 expressly
permits combining GPLv3 code with AGPLv3 code under those terms. Both facts
are recorded here as the **working position**, not a settled legal
conclusion -- resolving it definitively is the owner's/SCCN's call, tracked
in `LICENSING.md` and `provenance/binaries.yaml`.

### Build

`tetgen.cxx` + `predicates.cxx`, zero external dependencies beyond libm.
Built native arm64 with CMake 4.4.0 / Apple clang 21. The CLI target does
**not** define `TETLIBRARY` (that's only needed for upstream's separate
static-library target, which NFT never uses -- see `CMakeLists.txt`).

`predicates.cxx` implements Shewchuk's exact floating-point geometric
predicates, which are only correct if compiled without aggressive
optimization/reordering. Upstream's own makefile fixes this at the source:
`predicates.cxx` is always compiled at `-O0` (`PREDCXXFLAGS`), independent
of the `-O3` used for `tetgen.cxx` (`CXXFLAGS`). This `CMakeLists.txt`
preserves that split exactly, via a per-source-file `COMPILE_OPTIONS`
override that pins `predicates.cxx` to `-O0` regardless of
`CMAKE_BUILD_TYPE`.

```
cmake -S src/tools/tetgen -B build/tetgen -DCMAKE_BUILD_TYPE=Release
cmake --build build/tetgen
```

Both `tetgen.cxx` and `predicates.cxx` compile cleanly on Apple clang 21
under `-Wall -std=c++11` with warnings only (deprecated `sprintf` usage and
a handful of unused debug-only locals/functions in the original source) --
no errors, no source changes required. `otool -L` on the resulting binary
shows only `libc++`/`libSystem`, matching the shipped `tetgen.osx`.

### Verification (measured, not inferred)

Ran the actual CMake-built binary (`build/tetgen/tetgen`) and the shipped
`tetgen.osx` (already arm64 v1.6, the cleanest of the three shipped
binaries to compare against) on the **same real input**,
`../NFT_test/jc.smesh`, with the exact CLI arguments NFT itself issues
(`nft_warping_mesh.m` / `tetgen2msh.sh`):

```
./tetgen.osx -pq1.4a5A jc.smesh     # shipped
./tetgen     -pq1.4a5A jc.smesh     # rebuilt
```

Both runs exit 3 (the mesh has 46 self-intersecting input triangles;
TetGen reports them and stops after writing partial output -- expected,
identical behavior on both binaries, not a rebuild defect). Compared the
resulting `jc.1.node`/`jc.1.ele`/`jc.1.face`/`jc.1.edge`:

- Every line is **identical** except one trailing comment line per file
  (`# Generated by <argv[0]> ...`), which simply echoes the invoked binary's
  own name/path -- not a computational difference.
- With that one line stripped, `sha256sum` on all four output files matches
  **exactly** between shipped and rebuilt:
  - `jc.1.node`: `6e076fe6ae4c9400e1878ffae66c883c13c8cabb7f95de55ddee2b0230114bf5`
  - `jc.1.ele`: `2d73ad0f9bea4f01351122953a4d3181c9d7f5cb44b8505605f39c4b7905676e`
  - `jc.1.face`: `ff252e994943f224726d26f13322c032c2128408d647547aa1edba14d9176d22`
  - `jc.1.edge`: `fa04af4aa4ef81324adb1c1d9103becd97865e3dc04f13aa3a3d849cb71d6929`
- stdout is identical line-for-line (modulo the same binary-name echo and
  three wall-clock timing lines, which naturally vary run to run).

**`source_verified: behaviour`** -- this is the strongest form of result the
provenance methodology defines: not merely floating-point-round-off
agreement (as with `bem_matrix`/`procmesh`, which used different compilers
across platforms), but exact, byte-identical numeric and connectivity
output from the same-version source, same architecture (arm64), same
compiler family (clang) as the binary it replaces.

## Other notes

- Upstream's own copyright/license headers in `src/tetgen.cxx`,
  `src/predicates.cxx`, `src/tetgen.h`, and `src/LICENSE` are preserved
  unmodified -- only `CMakeLists.txt` and this `README.md` are NFT-authored
  files for this import.
- Upstream's CMakeLists.txt additionally defines a `tet` static-library
  target (`-DTETLIBRARY`) for embedding TetGen as a linkable library; NFT
  only invokes the `tetgen` CLI as a subprocess, so that target is not
  reproduced here.
