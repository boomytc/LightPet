# LightPet

LightPet is a local runtime for Codex-compatible desktop pet packages. Its boundary is intentionally narrow: it parses existing pet files, validates the fixed spritesheet contract, and presents the pet as a native macOS desktop overlay.

Out of scope:

- Generating, repairing, or editing pet artwork.
- Prompt orchestration for new pets.
- Packaging generated assets into Codex pet folders.
- Dynamic integrations with other apps or software state.

Use the `hatch-pet` skill or another asset pipeline to create the pet files, then point LightPet at the resulting folder.

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
swift run LightPetDesktop --scale 1
```

Mouse controls:

```text
hover visible sprite  waiting
left press            waving
left drag             move pet window; dragging switches running-left/running-right
double click          jumping
right click           size, pet folder, reset-position, and quit menu
```

Pet lookup:

```text
--pet path/to/pet.json  exact pet manifest path
--pet-id conan          default lookup key when --pet is not provided
```

Without `--pet`, the desktop wrapper tries `sample-pets/<pet-id>/pet.json`, then `${CODEX_HOME:-~/.codex}/pets/<pet-id>/pet.json`.

The right-click `Pet` menu lists valid packages discovered under `sample-pets/*/pet.json` and `${CODEX_HOME:-~/.codex}/pets/*/pet.json`. A package appears there only after its manifest, spritesheet size, used frames, and transparent unused cells pass validation. The menu also includes `Choose Pet Folder...`, which lets you select any folder containing this exact pair:

```text
pet.json
spritesheet.webp
```

To make a pet appear in the menu on every launch, place that folder under `sample-pets/<pet-id>/` or `${CODEX_HOME:-~/.codex}/pets/<pet-id>/`.

`Choose Pet Folder...` only loads the selected folder for the current run. It does not copy, install, or modify pet files.

Resize smoke test:

```bash
swift run LightPetDesktop --show-dock --resize-smoke-test
```

This opens the native panel, switches through `0.5x`, `0.75x`, `1x`, `1.25x`, and `1.5x`, verifies the actual window size, then exits.

The default sample package is copied from:

```text
/Users/boom/.codex/pets/conan/
```

## What Is Rendered

- Loads a local Codex pet manifest from `pet.json`.
- Resolves `spritesheetPath` relative to the manifest URL.
- Renders a `1536x1872` atlas as `8x9` cells.
- Uses `192x208` cells and the Codex row/frame duration table.
- Plays the same named states used by custom Codex pets.

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

For right-click folder selection, the folder must contain `pet.json`, `spritesheet.webp`, and `pet.json` must set `"spritesheetPath": "spritesheet.webp"`.

## Spritesheet Contract

`spritesheet.webp` must be exactly `1536x1872` pixels:

```text
grid:  8 columns x 9 rows
cell:  192x208 pixels
```

Each row is one animation state. Used cells must contain visible pet pixels; unused cells after the row's frame count must be fully transparent.

| Row | State | Frames | What The Row Should Show |
| --- | --- | ---: | --- |
| 0 | `idle` | 6 | Calm resting loop, subtle breathing or blink. |
| 1 | `running-right` | 8 | Locomotion moving toward the right. |
| 2 | `running-left` | 8 | Locomotion moving toward the left. |
| 3 | `waving` | 4 | Friendly wave using the pet's limb only. |
| 4 | `jumping` | 5 | Vertical hop or bounce using body position. |
| 5 | `failed` | 8 | Dizzy, sad, or failed reaction. |
| 6 | `waiting` | 6 | Attentive hover state, looking ready. |
| 7 | `running` | 6 | Neutral running-in-place loop. |
| 8 | `review` | 6 | Focused inspection or thinking pose. |

When prompting `hatch-pet` or another generator, ask for a compact pixel-art mascot with consistent identity across all rows, transparent background, thick readable outline, limited palette, and no text, UI, speech bubbles, shadows, loose motion lines, or detached decorative effects. Effects should only be small, hard-edged, state-relevant, and attached to the pet silhouette.
