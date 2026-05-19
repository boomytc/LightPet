# Pet Run Layout

`.pet-runs/<pet-id>/` stores local authoring evidence from a `hatch-pet` run. The directory is intentionally ignored by git by default. Treat it as a working folder and provenance sample, not as the runtime package itself.

The committed runtime package shape remains:

```text
examples/pets/<pet-id>/
├── pet.json
└── spritesheet.webp
```

## Directory Shape

```text
.pet-runs/<pet-id>/
├── pet_request.json
├── imagegen-jobs.json
├── references/
│   ├── reference-01.png
│   ├── canonical-base.png
│   └── layout-guides/
├── prompts/
│   ├── base-pet.md
│   └── rows/
├── decoded/
├── frames/
│   └── frames-manifest.json
├── final/
│   ├── spritesheet.png
│   ├── spritesheet.webp
│   ├── validation.json
│   └── package-validation.json
└── qa/
    ├── contact-sheet.png
    ├── review.json
    ├── run-summary.json
    └── videos/
```

## Stage Files

`pet_request.json` records the requested pet identity, description, style notes, chroma key, output paths, and other run-level choices. It is the high-level intent for the run.

`references/` stores source images used for identity grounding. `canonical-base.png` is the most important reference after base generation because every later row should preserve that exact pet identity.

`references/layout-guides/` stores one guide per state. These guides are construction references only. Generated rows should follow their slot count, spacing, centering, and padding without copying visible guide pixels.

`prompts/base-pet.md` is the exact base reference prompt. `prompts/rows/<state>.md` is the exact row strip prompt for one state. These files are the main reusable authoring artifact for future targeted action updates.

`imagegen-jobs.json` is the visual job ledger. It records job ids, prompt files, input images, decoded output paths, selected source image paths, hashes, status, and mirror provenance when a row such as `running-left` is derived from `running-right`. Do not manually edit this file to pretend a visual job is complete.

`decoded/` contains selected generated images copied into the deterministic pipeline. These files should come from recorded generated sources or approved deterministic derivations, not local fabricated art.

`frames/` contains per-row extracted `192x208` frame PNGs and `frames-manifest.json`. This stage proves each strip was converted into the fixed cell contract.

`final/` contains the composed atlas and deterministic validation output. The WebP file here is the candidate runtime spritesheet.

`qa/` contains human-review artifacts. `contact-sheet.png` is the fastest way to review row identity and frame completeness. `videos/` contains per-state animation previews. `review.json` and `run-summary.json` summarize QA outputs.

## Promotion Policy

Promote only the final runtime package when a pet is accepted:

```text
pet.json
spritesheet.webp
```

For examples inside this repository, place the accepted package under `examples/pets/<pet-id>/`. For local Codex/LightPet use, install it under `${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/`.

Do not commit raw `$CODEX_HOME/generated_images` outputs or entire `.pet-runs/` folders unless the user explicitly asks for a fixture or provenance snapshot. If a run needs to be documented, prefer a short doc note plus selected QA images over wholesale binary artifacts.

## Single-Row Repair Or Extension

For a finished pet, keep the existing run folder if available. To change one action:

1. Keep the original `references/`, `canonical-base.png`, current contact sheet, and target layout guide.
2. Reopen or create only the target row job.
3. Generate and record the target row through the normal `hatch-pet` job flow.
4. Rebuild `frames/`, `final/`, and `qa/`.
5. Compare old and new contact sheets before promoting the new package.

If the desired action is not one of the 9 compatible rows, first decide whether it should replace an existing row or wait for a LightPet-only manifest/runtime extension. Do not create extra rows that the current runtime cannot discover.

## QA Checklist

Before accepting a run:

- `final/spritesheet.webp` is `1536x1872`, transparent-capable, and uses the fixed `8x9` grid.
- every used frame has visible pet pixels
- every unused cell after the row frame count is fully transparent
- `qa/review.json` has no errors
- `qa/contact-sheet.png` shows the same pet identity across every row
- generated rows have no copied layout guide marks, visible backgrounds, shadows, detached effects, text, labels, or slot-crossing artifacts
- preview videos exist for every state unless explicitly skipped
