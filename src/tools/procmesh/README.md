# procmesh

Headless mesh-processing utility (self-intersection repair, vertex merging,
edge splitting/flipping, mesh pruning) from the EMSI Tools Package, Brain
Research Laboratory, METU. Invoked mid-pipeline by NFT's mesh-generation and
warping steps as `procmesh -c <script> <mesh.smf>` (see `conf.showmesh` in
`nft_get_config.m` -- the field name is a historical misnomer, this is
procmesh, not Showmesh). Full license/provenance record:
`provenance/binaries.yaml` (entry name: `procmesh`) and
`THIRD_PARTY_LICENSES/README.md`. Build instructions and per-platform notes
are in `CMakeLists.txt`.

## Status: rebuild does NOT yet reproduce the frozen warping baseline

This is the headline finding of this import, not a footnote. **Do not treat
this directory as ready to wire into `nft_get_config.m` (Phase 7, #43)
without resolving the gap below.**

### Root cause (measured, not guessed)

The rebuilt binary is missing one CLI command that the currently-shipped
`procmesh.osx` has: **`prune`** (used as `prune all` in NFT's own generated
command scripts). Confirmed by probing both binaries' command dispatch
tables with a deliberately invalid command (procmesh's error handler prints
every registered command name):

```
shipped procmesh.osx: ... refresh script info mark unmark prune
rebuilt procmesh:     ... refresh script info mark unmark
```

Every other command matches exactly (26 of 27). This is not a tolerance or
floating-point issue -- `warping_main_function.m` and `nft_mesh_generation.m`
both emit `prune all\n` (each marked `% XXX yeni` -- "yeni" is Turkish for
"new", consistent with this being a real, intentional feature added to
procmesh's command set at some point after the archived source was written).
When the rebuilt binary hits `prune all` it prints "Not found" and continues,
so the script never reaches its `save ScS.smf` command, `warping_main_function.m`'s
`movefile(...ScS.smf...)` finds nothing, and the whole warping pipeline
errors out. Confirmed via `tests/WarpingSmokeTest.m`
(NFT_DSL_DIR=/Volumes/S1/git/NFTplugin_demo_cortical): `WarpingSmokeTest`
fails on `MATLAB:MOVEFILE:FileNotFound` at `warping_main_function.m:83`,
while `BinaryCanaryTest` and `DslInverseRegressionTest` pass unaffected
(neither exercises procmesh's `prune` path).

### The `prune` source could not be located

`pruneDeletedElements()` exists as an internal `TriMeshLin` method in
`src/mesh.cxx` (called internally by `correct_mesh`/`improve_mesh` etc.), but
there is no CLI wrapper exposing it as a `prune` command in `src/command.cxx`
-- unlike the structurally similar `fix intersect`/`fix sharp`/`show
intersect` commands, which each have a small `all`-aware wrapper
(`cmd_proc_intersect`, `cmd_proc_sharp` in `command.cxx`).

Searched for a `command.cxx` (or equivalent) that already wires this up,
across every copy found in the SCCN internal archive and the one public
upstream fork, all on 2026-07-16:

- All five archived ProcMesh copies (`FMT_tools/ProcMesh` -- the one
  imported here, `FMT_tools/ProcMesh.0`, `FMT_tools/ProcMesh.xxx`,
  `FMT_tools.0/ProcMesh`, `FMT_tools.0/ProcMesh.old`): no `prune` command in
  any `command.cxx`.
- All seven archived Showmesh copies (`Showmesh.old`, `Showmesh.2`,
  `Showmesh.2.old`, `Showmesh.2.cmap`, `Showmesh.3`, `Showmesh.3a`,
  `Showmesh.4`) -- a related, later codebase (see `meshproc.diff` in the
  archive, which documents a `ProcMesh` -> `Showmesh.2` delta): no `prune`
  command in any `command.cxx`.
- The public upstream fork, <https://github.com/zakalinacar/Showmesh>
  (already the `vendor-upstream` source for NFT's `Showmesh` binary, fetched
  fresh 2026-07-16): no `prune` command either.

The shipped `procmesh.osx` is reported (see `provenance/binaries.yaml`)
SHA256-identical to a **December 2014** macOS build, later than every
archived ProcMesh source snapshot (Sep-Dec 2010, recompiled without source
changes in Nov 2016 per embedded object timestamps). The most likely
explanation is that whoever added `prune` (and the corresponding `% XXX
yeni` lines in the MATLAB wrappers) did so in a working copy that was never
folded back into any of the archive locations searched here -- i.e. this is
a genuine, currently-unrecovered gap, not something this import broke or
overlooked through insufficient searching.

### What this means going forward

Options, in order of preference, for whoever picks this up next:

1. **Ask the owner to check with Zeynep Akalin Acar for a copy that has this
   revision** -- the same kind of ask already in flight for issue #51
   (quadmesh/lin2quad authorship). This is the only way to get the *actual*
   `prune` implementation rather than a guess.
2. **Write a new, clearly-labeled CLI wrapper** around the already-present,
   unmodified `pruneDeletedElements()` method, mirroring the existing
   `cmd_proc_intersect`/`cmd_proc_sharp` pattern in `command.cxx`. This is
   plausible (the underlying mesh operation already exists and is exercised
   internally elsewhere) but is **new code, not recovered GPL source** -- it
   must be written and reviewed as such (own attribution, not METU's), and
   validated against the warping baseline before being trusted, since the
   shipped binary's exact retry/message semantics for `prune`
   ("Pruning mesh 0 ...", "Pruning done in 0 tries.") are not fully
   inferable from the CLI output alone and do not exactly match any existing
   command's pattern (`correct`'s "Corrected in N tries" always reports at
   least 1 try on success; the shipped `prune` reported 0).
3. Do not ship this rebuild as a drop-in replacement for `procmesh.osx`
   until one of the above resolves -- it silently no-ops the `prune all`
   step (with a "Not found" message, not a hard error) whenever the shipped
   binary would have pruned dead elements, which is exactly the kind of
   silent divergence this whole verification exercise exists to catch.

## Other portability fixes applied (behavior-preserving, unrelated to the
## `prune` gap)

See the inline comments at each fix site and `CMakeLists.txt`'s summary:

- `src/mesh.cxx` (`print_boundary`) and `src/meshbase.cxx`
  (`VertexStore::dumpBuckets`): `%d` -> `%zu` for `size_t` arguments passed
  to `printf`/`fprintf` (undefined behavior on LP64 platforms; found by
  `-Wformat`, not just the one instance flagged going in).
- `src/strlcpy.c`: added `#undef strlcpy` immediately after `#include
  <string.h>`. Recent Apple SDKs (confirmed: macOS 26 Command Line Tools,
  Apple clang 21) redeclare `strlcpy` as a checked-builtin macro that
  collides with this file's own definition, unconditionally (not gated on
  optimization level, unlike traditional `_FORTIFY_SOURCE` behavior) --
  without this, `src/tools/procmesh` fails to compile at all on a current
  Mac toolchain. The `#undef` is a no-op wherever `strlcpy` is not a macro.
  **This is a byte-identical copy of `geodesic/src/strlcpy.c`, which does
  not have this fix** -- that file is currently only compiled through
  MATLAB's `mex` (a different compiler invocation than a direct `cc
  strlcpy.c`), so it may not be hitting this collision today, but the same
  fix is very likely needed there too if `build_geodesic.m` is ever re-run
  on a sufficiently new macOS toolchain. Flagging for whoever next touches
  `geodesic/`, not fixed here (out of scope for this import).
