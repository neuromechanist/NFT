# Architecture Decision Records

Architecture Decision Records (ADRs) capture significant decisions that shape the project: choice of stack, structural patterns, trade-offs accepted, alternatives rejected. Tuck them all in here so they are easy to find later.

## Convention

- One file per decision: `NNNN-short-kebab-title.md`, zero-padded to four digits.
- `0000-template.md` is the template; copy it to start a new ADR. Do not edit `0000-template.md` itself.
- Number sequentially. The next ADR after `0007-...` is `0008-...`.
- Status flows `proposed` -> `accepted` -> (later) `superseded by ADR-NNNN`. Never delete an ADR; supersede it.
- Keep each ADR short. If it grows past two screens, you are probably writing a design doc, not a decision.

## When to write an ADR

Write one when a decision:
- Will be hard or expensive to reverse.
- Cuts off other reasonable paths a future contributor might wonder about.
- Has been argued about more than once.
- Embeds a constraint (legal, performance, schedule) that is not obvious from the code.

Do not write one for routine choices that are obvious from reading the code.

## Index

Add new entries here as you create ADRs:

- ADR 0000 - template (do not edit)
- ADR 0001 - [Head model warps to electrodes](0001-head-model-warps-to-electrodes.md) (accepted)
- ADR 0002 - [DIPFIT is a compatibility contract, not code to fork](0002-dipfit-compatible-interop.md) (accepted)
- ADR 0003 - [Binary provenance and build-from-source strategy](0003-binary-provenance-strategy.md) (**superseded by ADR-0005** — its premises were disproven by measurement)
- ADR 0004 - [Drop coordmap](0004-drop-coordmap.md) (accepted)
- ADR 0005 - [Rebuild binaries from recovered source; replace only as a fallback](0005-rebuild-not-replace.md) (accepted, supersedes ADR-0003)
