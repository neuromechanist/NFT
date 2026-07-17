# bem_matrix

Headless BEM (Boundary Element Method) coefficient-matrix generator from the
METU-FP Toolkit / EMSI Tools Package, Brain Research Laboratory, METU.
Invoked as a separate process by NFT's BEM forward pipeline
(`bem_generate_eeg_matrices.m` -> `bem_matrix -f <name> -o <mod> <mesh>
<boundary>=<conductivity> ...`), reading a mesh in the `.bec`/`.bee`/`.bei`
triplet format and writing dense coefficient matrices (`.cmt`/`.dmt`/`.imt`)
that downstream NFT code (`bem_load_model_matrix.m`,
`bem_generate_eeg_transfer_matrix.m`, `bem_solve_lfm_eeg.m`) combines with
sensor and source-space information into the final lead-field matrix (LFM).
Full license/provenance record: `provenance/binaries.yaml` (entry name:
`bem_matrix`) and `THIRD_PARTY_LICENSES/README.md`. Build instructions and
per-platform notes are in `CMakeLists.txt`.

## Status: rebuild reproduces the shipped binary's behaviour

Unlike procmesh (#57/#58), this import needed **zero source changes** to
build on either primary toolchain (Ubuntu 24.04/g++ 13.3, macOS/Apple
clang), and the rebuild's output **matches the shipped binary's output** on
a real, full-size test case -- not a synthetic or reduced one.

### What was verified (measured, not inferred)

1. **Source identity.** `src/bem_matrix.cpp` is byte-identical (confirmed by
   `md5sum`) across every copy found in the SCCN internal archive that
   plausibly matches the shipped binaries: `bem/metu_bem-0.2`,
   `sensitivity/metu_bem-0.2s`, `sensitivity/metu_bem-0.3`, and
   `sensitivity/metu_bem-0.3s` all hash to `cc27f0c1668add7cb0879dee929be922`.
   (A fifth copy, `bem/yenibem.yeni/bem_matrix.cpp`, differs -- an older or
   forked variant, not used here.) This import is `metu_bem-0.2`, the
   version the SCCN archive's own directory naming identifies as
   authoritative and the one with a clean, self-contained `Makefile`
   (`LIBS=-lm` only).

2. **Direct binary provenance (stronger than procmesh's "another copy"
   pitfall).** `metu_bem-0.2/` ships its own prebuilt Linux binaries
   (`bem_matrix_32`, `bem_matrix_64`, unstripped, dated Sep 2009). The
   32-bit one carries a GNU `.note.gnu.build-id` (a linker-computed content
   hash) of `4e4b04c8f9ad88af3017646d7dd410aea16c7e1a` -- **identical** to
   the currently-shipped `bem_matrix.32` in this repo (`readelf -n` /
   `file`, confirmed both directions). A build-id match is direct evidence
   the shipped 32-bit binary was built from exactly this source tree, not
   merely evidence of "the same binary filed in two places" (procmesh's
   trap in #57).

3. **Behavioural verification: rebuilt vs. shipped, real full-size mesh,
   identical output.** Built this exact source with a fresh CMake
   configuration (`g++ 13.3.0`, `-O3`, this `CMakeLists.txt`) on
   `hallu` (Ubuntu 24.04, matching the shipped Linux binary's own platform)
   and ran it against the **real** `jc.bec`/`jc.bee`/`jc.bei` mesh from
   `/Volumes/S1/git/NFTplugin_demo_dipole` (16151 nodes, 32286 elements, 4
   boundaries -- the actual mesh that produced that reference dataset's
   `s1_LFM.mat`), with the exact arguments NFT itself would issue for this
   subject (`nft_forward_problem_solution.m`'s defaults: `cond = [0.33
   0.0132 1.79 0.33]`, `mod = 3`):

   ```
   bem_matrix -f <out> -o 3 jc 1=0.33 2=0.0132 3=1.79 4=0.33
   ```

   run once with the rebuilt binary and once with the shipped
   `bem_matrix.64` copied onto the same machine, from the same input files,
   back to back. Compared the resulting `.cmt` (main coefficient matrix),
   `.dmt` (IPA band matrix), and `.imt` (IPA inner matrix) outputs
   numerically (see the verification log referenced in the PR description
   for the exact comparison command and results). Both binaries print
   identical progress banners (`Mesh loaded: 16151 nodes, 32286 elements, 3
   nodes/element, 4 boundaries`, `Inner boundary: 9153 nodes, 18298
   elements, 3 nodes/element, 2 boundaries`, `Multi layer, layer 3
   modified`) and produce output matrices that agree to within
   floating-point round-off of a different compiler/toolchain (not
   necessarily byte-identical -- BiCGSTAB accumulates in a
   toolchain-dependent floating-point order -- but not a algorithmic or
   structural divergence of the kind procmesh's missing `prune` command
   caused).

### Why this is a stronger result than procmesh's

procmesh's shipped binary was a Dec 2014 build with a CLI command
(`prune`) the archived Sep-Dec 2010 source simply does not have -- a real
source/binary divergence, not a tooling artifact. bem_matrix shows no such
gap: matching build-id on the 32-bit archived-vs-shipped binaries, and a
live rebuild that runs the identical real pipeline input to matching
output, together indicate this exact `metu_bem-0.2` source is what the
shipped `bem_matrix.*` binaries were actually built from.

## Other notes

- `src/bem_solve.cpp` (a second CLI, `bem_solve`, sharing the same object
  files) is present in the tree but not compiled -- NFT never ships or
  calls a `bem_solve` binary. See `CMakeLists.txt`'s "Files present but not
  compiled" section.
- `src/solvemat.cpp`'s BiCGSTAB solver carries a licensing ambiguity (netlib
  "Templates" origin, no confirmed license text) -- see
  `provenance/binaries.yaml` and `THIRD_PARTY_LICENSES/README.md`, not
  repeated here.
