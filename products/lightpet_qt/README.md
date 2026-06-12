# LightPet Qt

`products/lightpet_qt/` is a standalone PySide6/Qt desktop runtime for
Codex-compatible LightPet packages. It loads existing `pet.json` plus
`spritesheet.webp` folders, validates the fixed atlas contract, and plays the pet
as a transparent always-on-top desktop widget.

This product does not generate or repair pet art. Use the Codex `hatch-pet`
skill for generation and QA, then load the finished package here.

## Setup

```bash
uv venv --python 3.12
uv pip install -e .
```

## Run

Use the bundled example:

```bash
make run-example
```

Use the Codex pet library at `${CODEX_HOME:-$HOME/.codex}/pets`:

```bash
make run
```

Direct CLI usage:

```bash
PYTHONPATH=src .venv/bin/python -m lightpet_qt \
  --pet examples/pets/lulu/pet.json \
  --scale 1
```

## Mouse Controls

```text
hover visible sprite  waiting
click                 failed
long press            waving
drag left/right       running-left/running-right
drag up/down          jumping/review
right click           size, pet, reset-position, and quit menu
```

## Validation

```bash
make validate-contract
make test
```

`make validate-contract` loads `docs/pet-animation-contract.json`, verifies the
PySide6/Qt runtime can consume it, and validates the bundled example spritesheet.

## Package Contract

```text
<pet-id>/
├── pet.json
└── spritesheet.webp
```

`spritesheet.webp` must be exactly `1536x1872` with an `8x9` grid of
`192x208` cells. Used cells must contain visible pixels, and unused cells after
each row's frame count must be fully transparent.

All loading paths, including `--pet path/to/pet.json`, require the manifest file
to be named `pet.json`, require `"spritesheetPath": "spritesheet.webp"`, and
load the adjacent `spritesheet.webp`.
