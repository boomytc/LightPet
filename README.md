# LightPet

Minimal local reproduction of the Codex custom pet runtime contract.

## Run

Web preview:

```bash
python3 -m http.server 18091
```

Open:

```text
http://127.0.0.1:18091/
```

Native macOS desktop pet:

```bash
swift run LightPetDesktop --scale 2
```

Mouse controls:

```text
hover visible sprite  waiting
left press            waving
left drag             move pet window; dragging switches running-left/running-right
double click          jumping
right click           size, pet, reset-position, and quit menu
```

Pet lookup:

```text
--pet path/to/pet.json  exact pet manifest path
--pet-id conan          default lookup key when --pet is not provided
```

Without `--pet`, the desktop wrapper tries `sample-pets/<pet-id>/pet.json`, then `${CODEX_HOME:-~/.codex}/pets/<pet-id>/pet.json`.

The default sample package is copied from:

```text
/Users/boom/.codex/pets/conan/
```

## What Is Reproduced

- Loads a local Codex pet manifest from `pet.json`.
- Resolves `spritesheetPath` relative to the manifest URL.
- Renders a `1536x1872` atlas as `8x9` cells.
- Uses `192x208` cells and the Codex row/frame duration table.
- Plays the same named states used by custom Codex pets.

This repo does not reproduce the Codex desktop overlay window, drag behavior, or app-state triggers. It reproduces the portable asset format and animation playback surface.

`LightPetDesktop` adds a local native macOS wrapper for the same files. It uses a transparent, borderless, floating AppKit panel and renders the same fixed atlas directly with Core Graphics. Transparent sprite pixels do not start pet interactions, and dragging is clamped to the visible screen area.

## File Contract

```text
sample-pets/<pet-id>/
├── pet.json
└── spritesheet.webp
```

`pet.json`:

```json
{
  "id": "conan",
  "displayName": "Conan",
  "description": "A lively pixel-art small desktop detective pet for Codex.",
  "spritesheetPath": "spritesheet.webp"
}
```

The spritesheet must be transparent-capable PNG or WebP, exactly `1536x1872`.
