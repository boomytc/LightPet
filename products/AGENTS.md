# LightPet Products Guide

## Scope

- Treat each `products/<product_name>/` directory as a standalone product root.
- Before editing, running, testing, packaging, or debugging a product, first `cd` into that product directory and follow its local `AGENTS.md`.
- Products are the stable application layer. They may contain native apps, web previews, examples, docs, assets, package metadata, scripts, and product-local ignored outputs.
- Do not treat `products/` itself as a shared runtime root.

## Product Boundaries

- Each product owns its own package metadata, `AGENTS.md`, `README.md`, assets, docs, examples, scripts, and launch or validation commands.
- Product runtime code must resolve paths from the product directory only.
- Product runtime code must not read sibling product assets, examples, docs, package metadata, or generated outputs.
- Do not add root-level shared runtime assets, examples, dependency metadata, or compatibility wrappers for product code.

## Validation

- Run product checks from the product directory, not from the repository root, unless using a root Makefile target that delegates into the product.
- Follow the product-local validation commands documented in `products/<product_name>/AGENTS.md`.

## Cleanup

- Remove transient `.build/`, `.swiftpm/`, `dist/`, `output/`, `.playwright-cli/`, and one-off validation artifacts after checks when they are no longer needed.
- Do not commit `.pet-runs/` wholesale. Promote only deliberate examples or documentation fixtures.
