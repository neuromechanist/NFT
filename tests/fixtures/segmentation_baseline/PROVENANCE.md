# Segmentation baseline fixture provenance

- Generated: 2026-07-16 23:33:25
- MATLAB: 25.2.0.3055257 (R2025b) Update 2
- Platform: GLNXA64 (arch glnxa64)
- NFT commit: b5acf92
- matitk MEX: /mnt/local/yahya/nft-ci/seg-baseline-final/matitk.mexa64
- matitk sha256: cbf3dc1cad068ae86a6eb3cf9e5056c9f64873a8cfe053572e6c810152754fec
- Input: /mnt/local/yahya/nft-ci/fixtures/segmentation_jc/Subj_mri.hdr/.img (subject jc, 256^3, 1mm isotropic)
- Run time: 39.3 s

## Why this had to run on Linux (hallu), not Apple Silicon

matitk ships mexa64 (Linux), mexw64 (Windows), and mexmaci64 (Intel Mac)
binaries only -- there is no mexmaca64 build, so `exist('matitk','file')` is 0 and
segmentation errors immediately on Apple Silicon (computer('arch')=='maca64'). This
fixture was captured over SSH on hallu (glnxa64, MATLAB 25.2.0.3055257 (R2025b) Update 2), the only available host
with both a working matitk MEX and a MathWorks license.

## Parameters used (NOT nft_segmentation's generic defaults)

nft_segmentation()'s own help text warns that sli/WMp/sl/st/sli_eyes "are
picked in the GUI by visually inspecting the subject's own slices, so treat these
defaults as generic starting points, not as subject-independent constants." The
historical NFT_test/jc_segments.mat records the values a human actually used for
this subject, so this baseline reuses THOSE instead of the generic fallback
(sli=66, WMp=[135 135 110], st=0.4):

| parameter | value used | generic default | source |
|---|---|---|---|
| sli (brain.slice) | 70 | 66 | jc_segments.mat parameters.brain.slice |
| WMp | [112 150 156] | [135 135 110] | jc_segments.mat parameters.brain.WMp |
| sl (fill level) | 0.4 | 0.4 | jc_segments.mat parameters.brain.filllevel (matches default) |
| st (threshold) | 0.5 | 0.4 | jc_segments.mat parameters.brain.threshold |
| sli_eyes | 87 | 110 | jc_segments.mat parameters.skull.sli_eyes |
| iter, ts, cond | 5, 0.0625, 3 | 5, 0.0625, 3 | jc_segments.mat parameters.filter (iter/cond); ts is hardcoded in the GUI, not a free parameter |
| LRflip | 0 | 0 | jc_segments.mat parameters.LRflip |

Resulting threshold (segm_outer_skull's automatic k1max-based thr) was
**7854.32**, matching jc_segments.mat's parameters.skull.thr (7.8543e+03) to 5
significant figures -- this is deterministic given (filteredvol, thr method) and is
NOT affected by the eye clicks, so this match cross-validates the filtering/threshold
path independent of the (unrecoverable) eye coordinates.

## Eye seed points: FRESH derivation (the one input that could not be recovered)

jc_segments.mat's parameters.skull struct has only sli_eyes and thr -- the
two [x y] points a human clicked via ginput(2) on slice 87 were never saved anywhere
and cannot be recovered. Per the owner's prior decision on the equivalent lost-input
situation for cortex_source_scs.mat (PR #16, see tests/fixtures/dsl_baseline/
PROVENANCE.md), this is treated as a fresh re-baseline: derive new, defensible seed
points from the data rather than guessing at, or claiming to reproduce, the original.

Derivation: ran filtering + scalp + brain segmentation (the three matitk-backed
steps preceding the eye-marking step) with the parameters above, then reproduced
segm_outer_skull's own X_dark = filteredvol < thr computation for slice_eyes=87.
Restricting X_dark to the scalp mask on that slice and computing 8-connected
components (MATLAB bwconncomp/regionprops) found two components whose centroids are
closely bilaterally symmetric about the slice midline (256/2=128) and whose location
overlaps the two round dark orbit structures clearly visible in the filtered image
(visually confirmed by overlaying centroids on the slice -- see the session record; not
checked into the repo, described here for reproducibility):

| eye | area (px) | centroid (x,y) | eccentricity |
|---|---|---|---|
| left  | 41  | (83.44, 76.32) | 0.807 |
| right | 133 | (157.01, 67.62) | 0.714 |

Rounded to `Eyes = [83 76; 157 68]` (segm_outer_skull rounds internally via
`xp = round(eyes(:,1)); yp = round(eyes(:,2))` regardless of path, so this is exactly
what a human clicking those two points with ginput(2) on
`imagesc(reshape(X_dark(:,87,:),K,M))` would have produced -- Centroid(1)/Centroid(2)
from MATLAB's regionprops on that same 2-D matrix are already in ginput's (x,y)
data-coordinate convention.) Both points lie inside `X_dark & scalpmask` (confirmed: the
components were found there), which utilsegm_regiongrow requires -- a seed outside that
set raises "seed is empty" rather than silently misbehaving, so a bad choice would have
failed loudly, not passed quietly.

Left/right area is asymmetric (41 vs 133 px) and not centered on the full visible orbit
circle -- only part of each orbit is actually below the automatic dark threshold at this
slice, the rest is not. This is plausible (natural anatomical asymmetry / partial-volume
effects in a real scan) and does not by itself indicate an error; it is recorded here so
a future re-derivation can compare against it rather than assume the original reasoning.

## Plausibility checks (measured, not assumed)

- Mask proportions of total volume (256^3 = 16,777,216 voxels):

  | mask | this baseline | historical jc_segments.mat (different eye clicks) |
  |---|---|---|
  | scalp | 0.2336 | 0.2326 |
  | brain | 0.1298 | 0.1310 |
  | outer skull | 0.1589 | 0.1636 |
  | inner skull | 0.1445 | 0.1469 |

  The historical numbers are NOT a pass/fail target (its eye clicks are lost and
  irreproducible, so exact agreement is not expected or required) -- they are informative
  context only, and the close agreement here (all four within ~3% relative) is a useful
  independent plausibility signal, not a correctness proof.

- Anatomical containment: brain-in-outerskull = 1.0000, outerskull-in-scalp = 1.0000
  (both should be ~1.0 for a sane segmentation; both baseline runs were exactly 1.0000)
- Qualitative: a mid-axial-slice overlay of all four masks was visually inspected
  (smooth nested contours, no holes/artifacts, brain fully interior to a thin skull ring
  fully interior to scalp) -- not checked into the repo; described here for the record.

## Determinism

The full pipeline (filtering -> scalp -> brain -> outer skull -> inner skull ->
final skull/scalp correction) was run twice with identical inputs. All four masks were
bit-identical across the two runs (0 differing voxels out of 16,777,216, all four masks).
SegmentationRegressionTest compares a fresh run against this frozen baseline with an
exact-match check on that basis; see its own comments for the cross-platform caveat
(this was only measured on glnxa64/R2025b, not cross-checked against another platform).

## Fixture size discipline

Stores the four full-resolution logical masks (256^3 each) plus the small
parameters struct -- NOT the filtered MRI volume nft_segmentation() also writes
(jc_mri.mat-equivalent, continuous-valued, ~94 MB uncompressed and still ~94 MB after
MATLAB's default -v7 zlib compression, since continuous float data does not compress
well). Binary masks compress far better under -v7 -- the historical jc_segments.mat,
which stores the same four full-resolution masks, is 542 KB on disk -- so storing full
masks here (rather than a lossy digest, cf. tests/dsl_digest.m) is both affordable and
gives an exact per-voxel comparison rather than a compressed summary statistic.
