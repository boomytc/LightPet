# LightPet macOS Development Guide

## Product Boundary

This directory is the standalone Swift/AppKit macOS runtime product. Keep it focused on loading, validating, previewing, and playing existing Codex-compatible desktop pet packages.

Do not turn the Swift app or Web preview into the full pet-generation pipeline. Full image generation, row repair, and visual QA should continue to run through the Codex `hatch-pet` skill unless the user explicitly asks for a different product direction.

This product keeps only the durable parts of authoring:

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

`docs/pet-animation-contract.json` is the machine-readable source of truth for atlas geometry, row order, frame counts, durations, mouse mappings, and authoring notes. Swift runtime constants and rows are generated into `Sources/LightPetDesktop/Core/GeneratedAnimationContract.swift`. After changing animation metadata, run `make generate-contract`, then `make validate-contract`.

For Codex compatibility, adding a new action to an existing pet means regenerating or replacing one of these rows. True extra states need a manifest/runtime design first; do not quietly add extra rows or files that the current runtime cannot play.

## Code Layout

- `Package.swift`: product-local SwiftPM environment for the desktop runtime.
- `Sources/LightPetDesktop/Core/`: generated animation contract data, manifest loading, pet discovery, frame extraction, alpha validation.
- `Sources/LightPetDesktop/UI/`: AppKit panel, animation view, mouse interaction, state routing.
- `Sources/LightPetDesktop/App/`: app entrypoint and delegate.
- `Assets/`: product-local app icon resources.
- `preview/web/`: static browser preview for the same pet package contract.
- `examples/pets/`: committed runtime packages that users can load directly.
- `.pet-runs/`: ignored authoring runs and QA artifacts. Use as local evidence, not as the default committed source of truth.
- `docs/`: implementation notes, prompt templates, and run-layout documentation.
- `scripts/`: product-local validation and packaging scripts.

## Authoring Workflow

Use the installed Codex `hatch-pet` skill for complete runs. This product documents the prompts and output shape so finished pets can later receive targeted row updates without regenerating every state.

For an already finished pet, prefer a single-row workflow:

1. Pick the target compatible state row.
2. Ground generation with the original reference image, `references/canonical-base.png`, current contact sheet, and the target row layout guide.
3. Generate only the target strip through `hatch-pet` / `$imagegen`.
4. Run extraction, atlas composition, validation, contact sheet, and preview videos.
5. Accept only if identity, palette, silhouette, transparency, and unused-cell transparency still pass visual and deterministic QA.

Do not fabricate row strips with local drawing scripts, SVG, CSS, or Pillow as a substitute for generated art. Local scripts are only for deterministic processing and validation of generated images.

## Development Commands

Run commands from `products/lightpet_macos/`.

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

Animation contract:

```bash
make generate-contract
python3 scripts/validate_animation_contract.py
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

- Keep product contract JSON files in sync through the root `make validate-all` diff check.
- If you change atlas geometry, state names, frame counts, or durations, update `docs/pet-animation-contract.json`, regenerate `GeneratedAnimationContract.swift`, and update README/docs together.
- Do not commit `.build/`, `.swiftpm/`, `dist/`, `output/`, `.playwright-cli/`, `.pet-runs/`, or raw `$CODEX_HOME/generated_images` files.
- Do not commit `.pet-runs/` wholesale. Promote only deliberate examples or documentation fixtures.
- Keep `examples/pets/<id>/` to the runtime package surface unless the user asks to store authoring provenance there.
- When editing docs for pet authoring, distinguish Codex-compatible row replacement from future LightPet-only extra-state support.
