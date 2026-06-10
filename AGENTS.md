# LightPet Development Guide

## Project Boundary

LightPet is a local runtime for Codex-compatible desktop pet packages. Keep the app focused on loading, validating, previewing, and playing existing pet packages.

Do not turn the Swift app or Web preview into the full pet-generation pipeline. Full image generation, row repair, and visual QA should continue to run through the Codex `hatch-pet` skill unless the user explicitly asks for a different product direction.

The repository should keep only the durable parts of authoring:

- prompt contracts and action-row guidance under `docs/`
- small runtime example packages under `examples/pets/`
- local, ignored generation runs under `.pet-runs/`

## Runtime Contract

The current runtime contract is intentionally fixed:

- package files: `pet.json` plus `spritesheet.webp`
- atlas: `1536x1872`
- grid: `8` columns by `9` rows
- cell: `192x208`
- states: `idle`, `running-right`, `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running`, `review`

`docs/pet-animation-contract.json` is the machine-readable source of truth for atlas geometry, row order, frame counts, durations, mouse mappings, and authoring notes. Run `python3 scripts/validate_animation_contract.py` after changing animation metadata.

For Codex compatibility, adding a new action to an existing pet means regenerating or replacing one of these rows. True extra states need a manifest/runtime design first; do not quietly add extra rows or files that the current runtime cannot play.

## Code Layout

- `Sources/LightPetDesktop/Core/`: manifest loading, pet discovery, atlas geometry, frame extraction, alpha validation.
- `Sources/LightPetDesktop/UI/`: AppKit panel, animation view, mouse interaction, state routing.
- `Sources/LightPetDesktop/App/`: app entrypoint and delegate.
- `preview/web/`: static browser preview for the same pet package contract.
- `examples/pets/`: committed runtime packages that users can load directly.
- `.pet-runs/`: ignored authoring runs and QA artifacts. Use as local evidence, not as the default committed source of truth.
- `docs/`: implementation notes, prompt templates, and run-layout documentation.

## Authoring Workflow

Use the installed Codex `hatch-pet` skill for complete runs. This repo documents the prompts and output shape so finished pets can later receive targeted row updates without regenerating every state.

For an already finished pet, prefer a single-row workflow:

1. Pick the target compatible state row.
2. Ground generation with the original reference image, `references/canonical-base.png`, current contact sheet, and the target row layout guide.
3. Generate only the target strip through `hatch-pet` / `$imagegen`.
4. Run extraction, atlas composition, validation, contact sheet, and preview videos.
5. Accept only if identity, palette, silhouette, transparency, and unused-cell transparency still pass visual and deterministic QA.

Do not fabricate row strips with local drawing scripts, SVG, CSS, or Pillow as a substitute for generated art. Local scripts are only for deterministic processing and validation of generated images.

## Development Commands

Web preview:

```bash
python3 -m http.server 18091 --directory .
```

Open `http://127.0.0.1:18091/preview/web/`.

Desktop runtime:

```bash
swift run LightPetDesktop --scale 1
```

Resize smoke test:

```bash
swift run LightPetDesktop --show-dock --resize-smoke-test
```

Package local app:

```bash
scripts/package_app.sh
```

Cleanup:

```bash
make clean
```

## Change Guidance

- Keep Swift and Web animation row metadata in sync with the documented contract.
- If you change atlas geometry, state names, frame counts, or durations, update Swift, Web preview, README, and docs together.
- Do not commit `.build/`, `dist/`, `output/`, `.playwright-cli/`, or raw `$CODEX_HOME/generated_images` files.
- Do not commit `.pet-runs/` wholesale. Promote only deliberate examples or documentation fixtures.
- Keep `examples/pets/<id>/` to the runtime package surface unless the user asks to store authoring provenance there.
- When editing docs for pet authoring, distinguish Codex-compatible row replacement from future LightPet-only extra-state support.
