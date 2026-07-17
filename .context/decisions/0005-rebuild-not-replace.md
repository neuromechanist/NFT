# ADR 0005: Rebuild binaries from recovered source; replace only as a fallback

**Status:** accepted
**Date:** 2026-07-16
**Owner:** Seyed Yahya Shirazi
**Supersedes:** ADR-0003

## Context

ADR-0003 (proposed, never accepted) set the binary strategy on the belief that most of
NFT's shipped binaries had **no recoverable source** — that `procmesh` "per the README
requires contacting the developers", and that a full source archive merely "exists off-repo
(to be located)". It therefore gave equal billing to *replacing* closed tools with
maintained libraries (ITK/VTK/CGAL, OpenMEEG, iso2mesh).

**The archive was located and surveyed (2026-07-16, issue #37), and that belief was wrong.**
Source exists, and is buildable, for essentially every shipped tool. `procmesh` — the item
ADR-0003 singled out as needing developer contact — already ships a `CMakeLists.txt` and is
pure, portable C++03 with **zero external dependencies**. Its reported OpenGL dependency is
dead code, proven three ways (commented-out `LIBS=` line; no `TARGET_LINK_LIBRARIES`;
`mouse.h` never compiled and `__GLUTMOUSE__` never defined), and confirmed on the artifact
(`otool -L` links no GL).

This matters because replacement is not neutral: swapping a tool changes the algorithm, and
NFT's first principle is *preserve the science, fix the engineering*. ADR-0003's framing
would have traded away the science to solve a problem that did not exist.

Two further facts, measured, reshape the strategy:

- **The real constraint is MATLAB's platform support, not ours.** MATLAB does not exist on
  Linux arm64, and R2025b is the final Intel-Mac release. So the target set is **Linux
  x86_64 + Mac arm64 primary**, Windows best-effort, `maci64` legacy — not the five targets
  previously assumed.
- **Licensing, not source availability, is now the binding constraint** on two tools.

## Decision

**Rebuild from recovered source. Replace only where rebuilding is genuinely impossible.**

Per tool, in preference order:

1. **Rebuild from source** — the default. Import under `src/tools/<tool>/` with per-tool
   CMake, pinned toolchains, and provenance. Applies to `bem_matrix`, `procmesh`, `quadmesh`,
   `lin2quad`, `asc`, `forward`/METU-FEM, `metufem.mex*`.
2. **Vendor from a public upstream** where one exists and is better than the archive —
   `Showmesh` (github.com/zakalinacar/Showmesh, GPL-2.0), `tetgen` (Codeberg, AGPLv3),
   `qslim` (CLI driver must be recovered from upstream; absent from the archive).
3. **Reimplement against the same underlying library** where source is unobtainable but the
   tool is a thin wrapper — `matitk` -> **mexitk**, a new BSD-3 MATLAB/ITK bridge. This
   preserves the algorithms exactly, because MATITK is itself an auto-generated wrapper over
   stock ITK filters.
4. **Drop** where the capability is superseded — `coordmap` (ADR-0004).
5. **Replace with a different library** — the **last** resort, taken only when 1-4 fail, and
   only with an explicit, owner-signed-off acknowledgement that the science changed, plus a
   quantified delta against a baseline captured beforehand.

Every shipped binary carries an honest `provenance/binaries.yaml` entry; "unknown" is a
valid value and is always preferable to a guess. A CI gate fails on any unattributed binary.

**Licensing posture:** NFT's promise is **free access for academia — that always holds**.
Every component's terms must permit free academic/research use. Everything else is handled
by a plain disclaimer in `LICENSING.md` and offloaded to the user; NFT does not attempt to
clear commercial rights on anyone's behalf, and grants no rights it does not hold.

## Consequences

Easier: the algorithms are preserved, so existing regression baselines stay valid and no
re-validation campaign is forced. Most tools turn out to be trivial (zero-dependency C++),
so the work is smaller than ADR-0003 assumed. We own the build end to end rather than
depending on another project's binary distribution.

Harder / obligations:

- **We become the maintainer** of ~2010-vintage C/C++ trees. Accepted deliberately: they are
  small, dependency-free, and need only minor portability fixes (e.g. `asc` needs
  `<values.h>` removed — it is dead weight absent from the modern macOS SDK — and the
  `register` keyword dropped for C++17). This is a better bet than inheriting an external
  project's cross-platform binary problems.
- **Non-GPL components must not be presented as GPL**, and must live under their own LICENSE
  in their own subtree. This is sound because NFT **invokes these tools as separate
  processes** (`system()` shell-outs), which is aggregation, not a derivative work — the
  reasoning that covers TetGen's AGPLv3.

  > **Correction (2026-07-16, same day):** this bullet originally cited `asc` as the example,
  > describing it as "Tien-Tsin Wong: academic-only, no fee, notice intact". **That was
  > wrong, and it is worth recording why rather than quietly deleting.** The Phase 1 survey
  > read the `LICENSE` file sitting in the SCCN archive — which is **ASC v2.01 (2004),
  > copyright Tien-Tsin Wong personally, academic/research/internal-business use only**. But
  > upstream **relicensed**: **ASC v2.01a (2009) is standard BSD-3-Clause, copyright The
  > Chinese University of Hong Kong** — fully GPL-compatible. Verified by fetching CUHK's own
  > current release (`asc-201a.zip`) and diffing it against the archive's LICENSE.
  >
  > So `asc` was **never** a licensing problem. Take **upstream 2.01a (BSD-3)**, not the
  > archive's patched 2.01, and re-apply Zeynep's portability patches on top if still needed.
  > No aggregation argument is required for it, and no "not GPL-relicensable" caveat applies.
  >
  > This error propagated into two decisions (the iso2mesh swap, then its reversal) before
  > being caught. The lesson generalises: **a LICENSE file in the archive describes the
  > vintage in the archive, not the component's current terms.** Check upstream for every
  > component before concluding anything about its licence.
- **Two rebuilds still lack a baseline to verify against**: segmentation (`matitk` -> mexitk)
  and FEM (`forward` does not run *anywhere* today — even its own build cluster is missing
  `libgfortran.so.3`). Baselines must be captured on Linux, where those binaries still work,
  *before* the swap. Mesh generation likewise has no test at all.
- The hosting decision for large binaries (git vs release assets vs fetch-on-install) remains
  a follow-up, as ADR-0003 noted. Unchanged.

## Alternatives considered

- **Keep ADR-0003's replace-first framing.** Rejected: it was premised on unrecoverable
  source, which measurement disproved, and it would trade away algorithmic fidelity to solve
  a non-problem. Its named replacements (OpenMEEG for BEM, iso2mesh for `asc`, CGAL/MeshFix
  for `procmesh`) are retained only as fallbacks.
- **Swap `asc` for iso2mesh** (briefly chosen, then reversed). Rejected on the owner's own
  maintainability criterion: `asc` is 80 files of dependency-free C++ needing two trivial
  fixes, whereas iso2mesh would introduce a dependency on another project's per-platform
  binary distribution — the exact problem this epic exists to eliminate — while also changing
  mesh output and forcing a re-baseline.
- **Keep shipping opaque binaries.** Rejected, as in ADR-0003: perpetuates unmaintainability
  and the silent Apple-Silicon failures that motivated the project.

## Receipts

E1 Phase 1 archive survey (issue #37), three independent parallel surveys. Highlights:

- `quadmesh`, `lin2quad`: **exact MD5 match** between shipped binary and archive source.
- `forward`: **SHA256 byte-identical** to `metu_fem-0.4`; PETSc 3.1-p4, sequential (MPIUNI).
  The old hardcoded `/home/zeynep/.../metu_fem-0.4/forward` path was exactly right.
- `procmesh`: shipped `.osx` SHA256-identical to a Dec 2014 build of the archive tree.
- FEM has **two** binaries: `forward` (PETSc, one-time precompute) and `metufem.mex*` (the
  repeatedly-called hot path, **no PETSc/MPI** — its own BiCGSTAB solver).
- `matitk`: no source anywhere; request-gated download; File Exchange listing declares
  "No License". Hence mexitk.
- Method caution: a naive `#include <petsc` grep gave a **false** dependency-free reading of
  `metu_fem`, missing quoted includes and makefile variables. Measure exhaustively.

Licence corrections found in Phase 2 (#38), each reversing a prior belief:

- **`asc` is BSD-3-Clause upstream** (v2.01a, 2009, CUHK), not academic-only. The archive
  holds the superseded v2.01 (2004) licence. See the correction note above.
- **ITK as shipped is 3.2.0 under the older Insight Software Consortium modified-BSD**, not
  Apache-2.0. Apache-2.0 applies only to ITK >= 4.0 (2011). Confirmed via debug path strings
  embedded in the shipped binaries (`d:\libs\itk\insighttoolkit-3.2.0\...`). Both texts are
  kept: the 3.2 licence covers what ships today; Apache-2.0 is forward-looking for mexitk.
- **`tetgen.exe` is v1.6, not v1.5** — byte-identical banner to `tetgen.osx`. **Only the
  Linux `tetgen` (v1.4.3, 2009) predates the AGPL change.**
- **The QSlim CLI driver source was found** at a public maintained port
  (github.com/alecjacobson/qslim) — the archive's `tools/qslim/` was an empty shell. **But
  MixKit's own COPYING.txt carves out `MxTriProject.cxx` (Hugues Hoppe) and
  `MxMat3/4-jacobi.cxx` (derived from Numerical Recipes in C) as NON-COMMERCIAL USE ONLY**,
  not LGPL. A rebuild inherits that restriction unless those files are avoided or replaced —
  a live decision for the rebuild phase, and the one place a genuine use restriction survives.
- **`msvcr71.dll` / `msvcp71.dll`** are the proprietary Microsoft VC++ 7.1 runtime. Ad-hoc
  redistribution outside the official vcredist installer is a real compliance question ->
  flagged for removal.
- **`cygwin1.dll`** as shipped is ~2006 (v1.5.24), predating Cygwin's 2009 move to
  LGPLv3+exception, so the current upstream text does **not** describe this binary's terms.
- **`quadmesh` is completely unattributed** — no LICENSE, no copyright header in any of its
  17 source files — despite being an exact MD5 match to what we ship. Needs an owner decision
  before import.

Related: ADR-0003 (superseded), ADR-0004 (drop coordmap), issues #31, #37, #38, #45.
