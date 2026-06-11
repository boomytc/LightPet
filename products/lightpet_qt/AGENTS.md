# LightPet Qt Development Guide

## Product Boundary

This directory is the standalone PySide6/Qt desktop runtime product for LightPet.
Keep it focused on loading, validating, previewing, and playing existing
Codex-compatible desktop pet packages.

Do not turn this product into the pet-generation pipeline. Full image
generation, row repair, and visual QA continue to belong to the Codex
`hatch-pet` skill unless the user explicitly changes the product direction.

## Runtime Contract

This product uses the same Codex-compatible package contract:

- package files: `pet.json` plus `spritesheet.webp`
- atlas: `1536x1872`
- grid: `8` columns by `9` rows
- cell: `192x208`
- states: `idle`, `running-right`, `running-left`, `waving`, `jumping`,
  `failed`, `waiting`, `running`, `review`

`docs/pet-animation-contract.json` is the product-local machine-readable
source of truth. Run `make validate-contract` after changing contract metadata.

## Environment

Use the product-local uv environment:

```bash
uv venv --python 3.12
uv pip install -e .
```

The repository intentionally does not commit `.venv/`.

## Code Layout

- `src/lightpet_qt/contract.py`: animation contract parsing and validation.
- `src/lightpet_qt/package_loader.py`: manifest loading, pet discovery,
  spritesheet validation, frame extraction, and alpha maps.
- `src/lightpet_qt/pet_window.py`: transparent desktop pet QWidget,
  animation timers, mouse interaction, context menu, and resize smoke test.
- `src/lightpet_qt/cli.py`: command-line entrypoint.
- `docs/`: product-local runtime contract.
- `examples/pets/`: committed runtime packages that users can load directly.
- `scripts/`: product-local validation scripts.
- `tests/`: stdlib unittest coverage for contract and loader behavior.

## Development Commands

Run commands from `products/lightpet_qt/`.

```bash
make venv
make install
make validate-contract
make test
make run-example
make resize-smoke-test
make clean
```

## Change Guidance

- Keep this product independent from sibling products at runtime.
- Do not read `products/lightpet_macos/` from runtime code.
- If atlas geometry, state names, frame counts, or durations change, update this
  product's contract and validation/test coverage together.
- Keep `examples/pets/<id>/` to the runtime package surface unless the user asks
  to store authoring provenance there.
- Do not commit `.venv/`, `dist/`, `output/`, `.playwright-cli/`, `.pet-runs/`,
  or raw `$CODEX_HOME/generated_images` files.
