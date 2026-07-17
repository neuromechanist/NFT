# Licensing

## NFT itself

NFT (this codebase, excluding the third-party binaries described below) is
licensed under the **GNU General Public License, version 2 or later
(GPL-2.0-or-later)**. See the root `LICENSE` file for the full text.

**NFT's standing promise: free access for academia.** NFT is, and will remain,
free to use for academic and research purposes. Every third-party component
NFT bundles or invokes has been checked against that promise -- see the table
below. Where a component's terms are more restrictive for other uses (for
example, commercial use), that is stated plainly rather than glossed over.

## What NFT does NOT do

NFT does not attempt to clear commercial usage rights on your behalf, and
nothing in this document is legal advice. For each bundled or invoked
component, NFT states that component's terms as best as they could be
determined and gives you a machine-readable record
(`provenance/binaries.yaml`) and the verbatim license texts
(`THIRD_PARTY_LICENSES/`) to make your own compliance judgment. If your use
case is commercial, or otherwise falls outside a component's stated free-use
terms, you are responsible for contacting that component's rights holder
yourself. Nothing here grants a right NFT does not itself hold.

Some components' exact provenance could not be fully pinned down (no public
source, no license file, or evidence only available in an internal archive
that could not be independently re-verified). Those are recorded honestly as
`unknown` in `provenance/binaries.yaml` rather than guessed at -- "unknown" is
treated as a valid, useful answer here, not a gap to be quietly papered over.

## Per-component table

"Invocation" describes how NFT uses the component: **separate process** means
NFT's MATLAB code calls `system()`/an equivalent to run an independent
executable and communicates via files -- generally understood as "mere
aggregation" rather than creating a combined/derivative work (see GPLv2 §2,
"mere aggregation of another work not based on the Program... does not bring
the other work under the scope of this License"). **Linked** means the
component's object code is compiled into a shared library or MEX file that
MATLAB loads into the same process as NFT/EEGLAB code.

| Component | License | Invocation | What it means for you |
|---|---|---|---|
| ASC (isosurface extraction) | BSD-3-Clause (CUHK) | separate process | Permissive; free for any use including commercial, with attribution. Scheduled for replacement by iso2mesh regardless. |
| METU-FP BEM toolkit (`bem_matrix`) | GPL-2.0-or-later (+ one fragment of uncertain license, see `THIRD_PARTY_LICENSES/README.md`) | separate process | Free for any use under GPL terms once rebuilt with source available. |
| EMSI ProcMesh | GPL-2.0-or-later (+ OpenBSD-licensed `strlcpy.c` fragment) | separate process | Same as above. |
| QSlim / MixKit / libgfx | GPL-2.0-or-later (CLI) + LGPL-2.0-or-later-with-exception (MixKit) + MIT-style (libgfx), **but see caveat** | separate process | Free for any use, EXCEPT: MixKit's own license carves out two files (derived from Numerical Recipes in C) as non-commercial-use-only. A future rebuild must avoid or replace those files, or the resulting `qslim` binary would inherit that restriction. |
| quadmesh | GPL-2.0-or-later (**working assumption**, presumed METU-authored, no header -- see issue #51) | separate process | Treated as GPL for now by owner direction, pending an explicit grant. Revisit if #51 resolves otherwise. |
| lin2quad | GPL-2.0-or-later throughout (shared-library portion: genuine METU header; `lin2quad.cc`/`meshutil.*`: **working assumption**, presumed METU-authored, no header -- see issue #51) | separate process | Same as quadmesh for the unattributed portion; the shared-library portion was never in question. |
| Showmesh | GPL-2.0-or-later (+ bundled LGPL `gl2ps.c` and OpenBSD `strlcpy.c`) | separate process | Free for any use under GPL/LGPL terms; source is public (see below). |
| **TetGen** | v1.4.3 (Linux binary): pre-AGPL license, not re-verified. v1.6 (macOS/Windows binaries): **AGPL-3.0-or-later**, dual-licensed with a commercial option from WIAS | separate process | See the dedicated section below -- this is the most consequential entry in this table. |
| METU-FEM `forward` solver | GPL-2.0 (plain, not "or later") | separate process | Free for any use under GPL-2.0 terms once rebuilt with source available. |
| METU-FEM MATLAB bindings (`metufem.mex*`) | GPL-2.0-or-later wrapper + BSD-style solver core (not independently re-verified) | **linked** (MEX) | Free for any use once rebuilt with source available. |
| geodesic library | MIT (core) + GPL-2.0-or-later (MEX wrapper, NFT's own) | **linked** (MEX) | Free for any use; source already lives in this repo (`geodesic/src/`). |
| ITK 3.2.0 (as shipped: `ITKCommon.dll`, `matitk.dll`, `matitk.mex*`) | Modified BSD-style ("Insight Software Consortium" license) | **linked** (MEX/DLL) | Permissive, free for any use. Scheduled for replacement by `mexitk`. |
| ITK (future, via `mexitk`) | **Apache-2.0** | linked | See the dedicated ITK note below -- this matters for NFT's own license resolution, not for you directly. |
| MATITK | **unknown / no license stated anywhere** | **linked** (MEX/DLL) | No terms exist to rely on. Scheduled for replacement by `mexitk` specifically because of this gap. |
| Cygwin (`cygwin1.dll`) | GPLv2-with-exception (as shipped, ~2006-era binary) / LGPLv3-with-exception (current upstream, does not describe this specific binary) | **linked** (runtime dependency of some Windows binaries) | Free for any use under GPL/LGPL terms. Flagged for possible removal on packaging grounds, independent of licensing. |
| Microsoft Visual C++ 7.1 runtime (`msvcr71.dll`, `msvcp71.dll`) | **Proprietary (Microsoft)** | linked | Not open source. Ad hoc redistribution of these files outside Microsoft's official redistributable installer is a real compliance question. Flagged for removal. |

For exact sha256 hashes, source locations, and the full evidence trail behind
every row above, see `provenance/binaries.yaml`. For the license texts
themselves, see `THIRD_PARTY_LICENSES/`.

## TetGen and AGPLv3 (the acute case)

TetGen is licensed under the **GNU Affero General Public License, version 3
or later (AGPLv3+)**, effective from TetGen v1.5 onward, with a commercial
license also available from WIAS (Weierstrass Institute for Applied Analysis
and Stochastics). Two of the three TetGen binaries NFT ships
(`tetgen.osx`, `tetgen.exe`) are v1.6 and therefore under AGPLv3+; the third
(`tetgen`, the Linux binary) is the older v1.4.3, which predates the AGPL
change.

Two facts are relevant to how NFT may combine with AGPLv3-licensed TetGen,
and both are stated here without declaring a legal conclusion -- **that
determination is the owner's/SCCN's call, not something this document
resolves**:

1. **NFT invokes TetGen as a separate process.** `nft_warping_mesh.m:321` and
   `:333` call TetGen via `system()`, passing files in and reading files back
   out. NFT does not link against TetGen's object code. Under GPLv2 §2's
   "mere aggregation" language (which NFT's own license carries), running an
   independent AGPLv3 program as a subprocess and consuming its output files
   is generally understood as aggregation, not the creation of a combined
   derivative work.
2. **NFT's own license is GPL-2.0-*or-later*, not GPL-2.0-only.** That means
   NFT can be treated as distributed under GPLv3 at the recipient's option.
   GPLv3 §13 ("Use with the GNU Affero General Public License") explicitly
   permits conveying a work formed by combining a GPLv3-covered work with a
   work licensed under AGPLv3, adding the AGPLv3 §13 network-interaction
   requirement to the combination. This is a real, deliberate provision GPLv3
   added specifically to make GPLv3/AGPLv3 combination workable, and it
   applies to NFT because NFT chose "or later" rather than "GPLv2 only."

What is missing, and is a straightforward compliance gap regardless of how
the above is resolved: **NFT ships TetGen's compiled binaries without either
its source or its AGPLv3 license text.** AGPLv3 §13's network-copyleft
provision, and the ordinary requirement to make the corresponding source
available to anyone who receives the binary, are not satisfied today. This
should be fixed by vendoring TetGen's source (or a build recipe against the
public upstream) and including `THIRD_PARTY_LICENSES/TetGen-AGPLv3.txt`
(now present) alongside the binaries.

## ASC and academic-use terms

Earlier internal notes characterized ASC (the isosurface extraction tool) as
academic/research-use-only and NOT GPL-compatible. Checking directly against
the Chinese University of Hong Kong's own current release
(`THIRD_PARTY_LICENSES/ASC-TienTsinWong.txt`) found a standard permissive
3-clause BSD license instead -- free for any use, including commercial, with
attribution. This is a correction, not a downgrade of caution: it is stated
plainly here in case the SCCN internal archive's copy of ASC (which is
reported to be a modified variant) carries a different, more restrictive
license file that was not independently located during this pass. Until that
is confirmed, treat the archive copy with the same caution as any other
"unverified against primary source" entry. NFT invokes ASC as a separate
process (`nft_mesh_generation.m:142`), and it is scheduled for replacement by
iso2mesh regardless of how this resolves.

## ITK and the Apache-2.0 question

The ITK actually bundled in this repo today (`ITKCommon.dll`, `matitk.dll`,
`matitk.mex*`) is ITK 3.2.0, which predates Apache-2.0 -- it is under ITK's
older modified-BSD license (`THIRD_PARTY_LICENSES/ITK-ModifiedBSD-3.2.txt`),
fully permissive and fully GPL-compatible on its own terms.

The Apache-2.0 question matters for the **forthcoming** `mexitk` replacement,
which is expected to bundle a modern (v4+) ITK release. Apache-2.0 is
incompatible with GPL-2.0-*only* code (the two licenses have conflicting
patent and indemnification terms that neither can satisfy), but Apache-2.0
combinations ARE explicitly permitted with **GPLv3** (the Free Software
Foundation lists Apache License 2.0 as GPLv3-compatible). Because NFT's own
license is GPL-2.0-*or-later*, the same "or later" resolution path described
in the TetGen section above applies here too: NFT can be treated as
distributed under GPLv3, under which Apache-2.0 combination is fine. This is
worth keeping in mind when `mexitk` is integrated, so the combination is
documented at that time rather than assumed.

## Unattributed C/C++ tools presumed METU-authored: a working assumption, not a grant

Two shipped binaries (`quadmesh`, and the `lin2quad.cc`/`meshutil.*` portion
of `lin2quad`) have source that carries **no license header and no LICENSE
file at all**, confirmed by a direct grep for copyright/author/RCS-tag
evidence across every source file -- zero hits. SCCN does not own this code
and is not claiming to.

The EMSI Tools Package components NFT bundles (`bem_matrix`, `procmesh`, and
the shared library files `lin2quad` links against) carry a real, discovered
GPLv2+ header whose copyright line reads "Copyright (C) 2008 Zeynep Akalin
Acar, Can Erkin Acar, Nevzat G. Gencer," attributing the **Brain Research
Laboratory at Middle East Technical University (METU)** -- a different
institution from SCCN. `quadmesh` and the unattributed portion of `lin2quad`
are presumed to belong to that same METU-authored toolset on strong
circumstantial evidence: they share an unheadered Borland-C++-Builder-era
`point3`/`rect3`/`pstore` class-code family with `procmesh` (which IS
EMSI/METU-attributed), sit in Turkish-internally-named archive directories
("eski," Turkish for "old"), and appear nowhere else with any competing
authorship claim. This is circumstantial, not proof -- no header, RCS tag, or
authorship statement names either component directly, and
`provenance/binaries.yaml` says so plainly.

**Issue #51** tracks an explicit permission request to the presumed copyright
holders; the owner is contacting Zeynep Akalin Acar directly. This is
plausibly a short conversation rather than a dead end -- Zeynep has separately
published Showmesh, another NFT-adjacent tool, under GPL-2.0 with a real
public LICENSE file (https://github.com/zakalinacar/Showmesh).

**Final owner direction (2026-07-16):** rather than block Phase 3 (issue #39)
behind that human round-trip, NFT proceeds on a **working assumption of
GPL-2.0-or-later** for `quadmesh` and the unattributed portion of `lin2quad`,
consistent with the rest of the EMSI package, while #51 is pending. This is
recorded in `provenance/binaries.yaml` explicitly as an **assumption of
record** -- not a discovered header and not a license grant -- and must be
revisited if #51 resolves otherwise. (An earlier, narrower reading briefly
treated this as directly resolvable by an SCCN "anything belonging to NFT is
GPL2" declaration outright; the owner corrected that the same day, since SCCN
cannot declare a license for code it does not own. The working assumption
adopted here is a distinct, later, and final decision to proceed pragmatically
while permission is sought, not a re-assertion of ownership.)

The owner's GPL-2.0-or-later ruling holds without any working-assumption
caveat for NFT's own MATLAB toolbox code -- the `nft_*.m` files, the GUIs,
`segm_*`/`utilmesh_*`/`bem_*` MATLAB sources, tests -- which is unambiguously
SCCN/NFT-authored and already covered by the root `LICENSE`; that was never
in question. Every genuinely third-party component in this survey (TetGen,
ASC, ITK, MATITK, qslim/libgfx/MixKit, gl2ps, strlcpy, geodesic, the Microsoft
and Cygwin runtime DLLs, and the netlib fragment in `bem_matrix`) is
unaffected by any of this and keeps exactly the terms recorded for it above.

## Questions or disputes about a specific component's terms

Contact the rights holder identified in that component's entry in
`provenance/binaries.yaml` or `THIRD_PARTY_LICENSES/`. This document and the
records it points to reflect a good-faith survey completed 2026-07-16; they
are not a substitute for your own legal review if your use case depends on
getting a component's terms exactly right.
