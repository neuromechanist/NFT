# Third-party licenses

Verbatim license texts for the third-party components bundled with NFT's
precompiled binaries. This directory exists so that redistributing those
binaries comes with an honest, complete license text alongside them -- not
because NFT's own code (GPL-2.0-or-later, see the root `LICENSE`) requires it.

For the authoritative per-binary record (which artifact, which sha256, which
license, and why), see `../provenance/binaries.yaml`. This README is the
license-file index; that manifest is the binary-file index. For the
user-facing summary of what all this means in practice, see `../LICENSING.md`.

| Component | Covers these shipped binaries | License file(s) |
|---|---|---|
| ASC (Adaptive Skeleton Climbing) | `asc1`/`asc1.32/.64/.exe/.osx`, `asc2.*`, `asc4.*`, `asc8.*` | `ASC-TienTsinWong.txt` |
| METU-FP BEM toolkit | `bem_matrix.*` | `GPL-2.0.txt` (netlib BiCGSTAB fragment inside `solvemat.cpp`: no license text located, see note below) |
| EMSI ProcMesh | `procmesh.*` | `GPL-2.0.txt` + `strlcpy-OpenBSD.txt` |
| QSlim CLI driver (SlimKit) | `qslim.*` | `qslim-GPL-LGPL-mixkit.txt` (GPL-2.0-or-later) |
| MixKit (QSlim's simplification library) | `qslim.*` (statically linked in) | `qslim-GPL-LGPL-mixkit.txt` (LGPL-2.0-or-later + linking exception; **see non-commercial-fragment caveat inside that file**) |
| libgfx (QSlim's graphics support library) | `qslim.*` (statically linked in) | `libgfx-MIT.txt` |
| quadmesh | `quadmesh` | none -- not a third-party component, see note below |
| lin2quad | `lin2quad` | `GPL-2.0.txt` (shared-library portion, genuinely third-party/METU; `lin2quad.cc`/`meshutil.*` themselves are NFT's own code, not third-party, see note below) |
| Showmesh | `Showmesh.64`, `Showmesh.exe`, `Showmesh.osx` | `Showmesh-GPL-2.0.txt` |
| gl2ps (bundled inside Showmesh) | `Showmesh.*` | `gl2ps-LGPL.txt` |
| strlcpy (OpenBSD, bundled inside Showmesh and geodesic) | `Showmesh.*`; also `geodesic/geodesic.mex*` | `strlcpy-OpenBSD.txt` |
| TetGen | `tetgen`, `tetgen.exe`, `tetgen.osx` | `TetGen-AGPLv3.txt` (applies to `tetgen.exe`/`tetgen.osx`, both v1.6; the Linux `tetgen` binary is v1.4.3, pre-AGPL -- see `provenance/binaries.yaml` for the version-split detail) |
| METU-FEM `forward` solver | `forward` | `GPL-2.0.txt` |
| METU-FEM MATLAB bindings | `metufem.mexa64`, `metufem.mexmaci64`, `metufem.mexw64` | `GPL-2.0.txt` (wrapper; solver core reported BSD-style, text not independently located) |
| geodesic library | `geodesic/geodesic.mex*` | `geodesic-MIT.txt` |
| ITK 3.2.0 (as actually shipped) | `ITKCommon.dll`, `matitk.dll`, `matitk.mex*` | `ITK-ModifiedBSD-3.2.txt` |
| ITK (forward-looking, for `mexitk`) | not yet shipped -- future dependency | `ITK-Apache-2.0.txt` |
| Cygwin | `cygwin1.dll` | `Cygwin-LGPLv3-exception.txt` (current upstream text; **the shipped binary predates this license by several years, see caveat inside the file**) |
| MATITK | `matitk.dll`, `matitk.mex*` | none -- no license text exists for this component, see note below |
| Microsoft Visual C++ 7.1 runtime | `msvcr71.dll`, `msvcp71.dll` | none -- proprietary, see note below |

## Components that are NFT's own code, not third-party (and why no file here)

- **quadmesh** -- the archived source has no LICENSE file and no copyright
  header anywhere; that fact is unchanged. But per an explicit owner
  declaration (SCCN, 2026-07-16, see `../LICENSING.md`'s "Unattributed
  NFT-owned code" section), this component is NFT's own code, not third-party
  code NFT bundles, and is therefore GPL-2.0-or-later under NFT's own root
  `LICENSE` -- the same file that already covers every other NFT-authored
  source file in this repository. There is nothing third-party to reproduce
  here. See `../provenance/binaries.yaml` for the full evidence trail, which
  states plainly that this is a declaration, not a discovered header.
- **`lin2quad.cc` / `meshutil.*` specifically** (as opposed to the shared
  library files they link against, which carry a genuine METU copyright
  header, ARE third-party, and remain covered by `GPL-2.0.txt`) -- same
  situation as quadmesh: no header of their own, and licensed
  GPL-2.0-or-later as NFT's own code by the same 2026-07-16 owner
  declaration, not because a header was found.

## Components with no license file in this directory (and why)

Per the owner's stance that "unknown" is a valid, honest recorded value: these
components have NO file here because no usable license text could be located,
not because the check was skipped. Unlike the two components above, these ARE
genuinely third-party -- NFT does not own them and cannot relicense them.

- **The netlib "Templates" BiCGSTAB fragment inside `bem_matrix`'s
  `solvemat.cpp`** -- the public netlib source
  (https://netlib.org/templates/cpp/bicgstab.h) carries only an algorithm
  description comment, no formal license header. A prior survey guessed "BSD"
  but hedged ("appears to be"); this pass could not confirm that with a
  primary source, so no license text is reproduced for this specific fragment.
- **MATITK** -- no source is publicly available (request-gated download), the
  author's site grants no license ("provided as is, use at your own risk" is
  not a license), and the MathWorks File Exchange listing explicitly declares
  "No License". Already slated for replacement by `mexitk`.
- **Microsoft Visual C++ 7.1 runtime (`msvcr71.dll`, `msvcp71.dll`)** -- these
  are proprietary Microsoft files under the Visual C++ Redistributable EULA,
  not an open-source license. Reproducing EULA text here would misrepresent
  which terms actually apply (that depends on how these specific files were
  obtained, which cannot be determined from the binaries alone). Flagged in
  `provenance/binaries.yaml` as `flag-for-removal` -- this is a packaging
  question independent of the rest of this survey.

## Corrections to prior internal findings

Two prior characterizations used to plan this work turned out to be wrong when
checked against primary sources directly. Both are also flagged inline in
`provenance/binaries.yaml`:

1. **ASC is not "academic-only, NOT GPL-compatible."** The current official
   upstream license (fetched directly from the Chinese University of Hong
   Kong's own release, 2026-07-16) is a standard permissive 3-clause BSD
   license, which is GPL-compatible. See `ASC-TienTsinWong.txt`.
2. **`tetgen.exe` is not v1.5.** Direct inspection of the binary's embedded
   version string shows it is v1.6, byte-identical in its banner to
   `tetgen.osx`. Only the Linux `tetgen` binary (v1.4.3) predates the AGPLv3
   change.

A third item is a correction to the task brief rather than to a prior survey:
**the ITK actually shipped in this repo (`ITKCommon.dll`, `matitk.dll`,
`matitk.mex*`) is ITK 3.2.0, under ITK's old modified-BSD license, not
Apache-2.0.** Apache-2.0 only applies starting at ITK 4.0 (2011); it is kept
in this directory (`ITK-Apache-2.0.txt`) because it is expected to matter for
the forthcoming `mexitk` dependency, which will bundle a modern ITK.
