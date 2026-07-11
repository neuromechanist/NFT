# Key references

Foundational literature for the NFT modernization. BibTeX for all entries is in
`nft-references.bib`; downloaded open-access PDFs are in `pdf/`.

| # | Paper | DOI | PDF here? | Role |
|---|-------|-----|-----------|------|
| 1 | Akalin Acar & Makeig (2010), *Neuroelectromagnetic Forward Head Modeling Toolbox*, J. Neurosci. Methods 190:258-270 | `10.1016/j.jneumeth.2010.04.031` | No (Elsevier paywall; open copy at PMC4126205) | The original NFT paper. Defines the BEM pipeline, mesh generation, and template warping this repo implements. |
| 2 | Cao, Akalin Acar, Kreutz-Delgado & Makeig (2012), *A physiologically motivated sparse, compact, and smooth (SCS) approach to EEG source localization*, IEEE EMBC 2012:1546-1549 | `10.1109/EMBC.2012.6346237` | Yes | **SCS** = Sparse, Compact, and Smooth. One of the two flagship distributed-source inverse methods. |
| 3 | Akalin Acar, Acar & Makeig (2016), *Simultaneous head tissue conductivity and EEG source location estimation*, NeuroImage 124:168-180 | `10.1016/j.neuroimage.2015.08.032` | No (Elsevier paywall) | **SCALE** = Simultaneous Conductivity And source Location Estimation. The other flagship inverse method. |
| 4 | Akalin Acar & Makeig (2013), *Effects of Forward Model Errors on EEG Source Localization*, Brain Topogr. 26:378-396 | `10.1007/s10548-012-0274-6` | Yes | Quantifies how head-model / electrode-position / skull-conductivity errors degrade localization. Core motivation: accurate electrode positions and subject head models matter. |
| 5 | Shirazi & Huang (2019), *More Reliable EEG Electrode Digitizing Methods Can Reduce Source Estimation Uncertainty...*, Front. Neurosci. 13:1159 | `10.3389/fnins.2019.01159` | Yes | Electrode digitization accuracy vs. source estimation uncertainty. Motivates the 3D-scan electrode-localization goal. |

## The two flagship inverse methods

- **SCS** (entry 2, Cao et al. 2012) — Sparse, Compact, and Smooth distributed
  source localization. PDF present (NIH manuscript `nihms613673`).
- **SCALE** (entry 3, Akalin Acar et al. 2016) — jointly estimates tissue
  conductivity and source location. PDF paywalled; DOI + BibTeX recorded.

## Tutorials (local only, from `../NFT_test`)

Zeynep Akalin Acar's NFT walkthroughs, copied into `pdf/` (gitignored):
- `NFT_demo2021_AkalinAcar_EEGLABworkshop.pdf` — June 2021 EEGLAB workshop, 106
  slides, step-by-step (MR prep → segmentation → mesh → warping → forward → dipole →
  cortical/DSL). The authoritative workflow reference.
- `NFT_presentation2018_AkalinAcar.pdf` — 2018 presentation.

## Notes

- Paywalled PDFs (entries 1, 2) can be retrieved with institutional / Elsevier
  API access, or via the PMC open copy for entry 1 (PMC4126205). BibTeX and
  DOIs are already recorded so citations work without the PDF.
- Regenerate/extend BibTeX with:
  `uvx opencite lookup "<DOI>" -f bibtex --append-bib docs/references/nft-references.bib`
