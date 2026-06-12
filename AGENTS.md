# LightPet Workspace Guide

## Workspace Boundary

LightPet is organized as a product workspace. The repository root is not a runtime product and should only keep cross-product instructions, aggregate commands, and workspace metadata.

The default native product lives at `products/lightpet_macos/`. Treat any product directory as the standalone product root before editing, running, testing, packaging, or debugging that app.

## Product Rules

- Each `products/<product_name>/` directory must own its runtime code, package metadata, assets, docs, examples, scripts, ignored local run outputs, and validation commands.
- Product code must resolve paths from its own product root only.
- Do not add root-level SwiftPM packages, shared runtime assets, shared pet examples, or compatibility wrappers for product code.
- Do not read sibling product directories at runtime.
- Keep product environments independent. A product that needs dependencies must declare them under its own product root.

## Products

- `products/lightpet_macos/`: Swift/AppKit native macOS runtime, static Web preview, runtime examples, prompt contracts, and deterministic validation scripts.
- `products/lightpet_qt/`: PySide6/Qt desktop runtime for the same Codex-compatible pet package contract.

## Runtime Contract

The current LightPet runtime contract is intentionally fixed:

- package files: `pet.json` plus `spritesheet.webp`
- atlas: `1536x1872`
- grid: `8` columns by `9` rows
- cell: `192x208`
- states: `idle`, `running-right`, `running-left`, `waving`, `jumping`, `failed`, `waiting`, `running`, `review`

The machine-readable contract is product-local at `products/lightpet_macos/docs/pet-animation-contract.json`.

For Codex compatibility, adding a new action to an existing pet means regenerating or replacing one of these rows. True extra states need a manifest/runtime design first; do not quietly add extra rows or files that the current runtime cannot play.

## Development Commands

From the repository root, macOS product commands:

```bash
make validate-all
make validate-contract
make build
make preview
make package-app
make clean
```

Direct product commands should run from `products/lightpet_macos/` and follow that directory's `AGENTS.md`.
For the Qt product, run commands from `products/lightpet_qt/` and follow that directory's `AGENTS.md`.

## Cleanup

- Do not commit `.build/`, `.swiftpm/`, `.venv/`, `dist/`, `output`, `.playwright-cli/`, `.pet-runs/`, or raw `$CODEX_HOME/generated_images` files.
- Do not commit `.pet-runs/` wholesale. Promote only deliberate examples or documentation fixtures.
- Keep `examples/pets/<id>/` to the product runtime package surface unless the user asks to store authoring provenance there.
