# Codex Pet Implementation Notes

## Runtime Contract

Codex custom pets are local asset packages under:

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
├── pet.json
└── spritesheet.webp
```

The manifest is intentionally small:

```json
{
  "id": "pet-id",
  "displayName": "Pet Name",
  "description": "One short sentence.",
  "spritesheetPath": "spritesheet.webp"
}
```

The app discovers pets by folder name, reads `pet.json`, then loads the spritesheet named by `spritesheetPath`.

## Atlas Geometry

The animation surface is a fixed sprite atlas:

```text
atlas: 1536x1872
grid:  8 columns x 9 rows
cell:  192x208
```

The player does not need per-frame rectangles in the manifest. A state maps to a fixed atlas row, and a frame index maps to a fixed column. Unused cells after the last used column in a row must stay fully transparent.

## Animation Table

| Row | State | Frames | Durations |
| --- | --- | ---: | --- |
| 0 | idle | 6 | 280, 110, 110, 140, 140, 320 ms |
| 1 | running-right | 8 | 120 ms each, final 220 ms |
| 2 | running-left | 8 | 120 ms each, final 220 ms |
| 3 | waving | 4 | 140 ms each, final 280 ms |
| 4 | jumping | 5 | 140 ms each, final 280 ms |
| 5 | failed | 8 | 140 ms each, final 240 ms |
| 6 | waiting | 6 | 150 ms each, final 260 ms |
| 7 | running | 6 | 120 ms each, final 220 ms |
| 8 | review | 6 | 150 ms each, final 280 ms |

## Playback Logic

The minimal web runtime is:

1. Fetch `pet.json`.
2. Resolve `spritesheetPath` against the manifest URL.
3. For the active state, read `row`, `frames`, and `durations`.
4. Render one `192x208` viewport using the spritesheet as a CSS background.
5. Advance frame index by the state duration table.

The CSS background math is:

```text
background-size: 1536px 1872px
background-position-x: -frameIndex * 192px
background-position-y: -rowIndex * 208px
```

When scaled, multiply every atlas and cell dimension by the same scale factor.

## Desktop Wrapper Logic

The native desktop wrapper in `Sources/LightPetDesktop/main.swift` keeps the same pet package contract. It changes only the host surface:

1. Decode `pet.json`.
2. Decode `spritesheet.webp` with `NSImage`.
3. Validate the decoded `CGImage` is exactly `1536x1872`.
4. Pre-slice and validate all used frames, while checking unused cells are transparent.
5. Open a transparent, borderless `NSPanel`.
6. Draw the active cached `192x208` frame into the panel.
7. Advance frames with a `Timer` using the same duration table as the web preview.

Window settings:

```text
style: borderless, non-activating panel
background: transparent
level: floating
spaces: can join all spaces, fullscreen auxiliary
```

Mouse behavior:

```text
hover visible sprite  waiting
left press            waving
left drag             move the panel; horizontal direction selects running-right or running-left
mouse up              return to waiting or idle depending on pointer position
double click          jumping
right click           show size, pet, reset-position, and quit menu
```

The right-click menu intentionally does not list animation states. States are selected by the desktop pet's mouse interaction model.

Additional desktop behavior:

- Pet choices are discovered from `sample-pets/*/pet.json` and `${CODEX_HOME:-~/.codex}/pets/*/pet.json`.
- Window size can be changed from the right-click menu.
- Hit testing samples the current frame alpha map, so transparent sprite pixels do not start pet interaction.
- Dragging is clamped to the visible screen union to keep the pet reachable.

This is the practical minimum for a desktop pet. More advanced behavior should be added as explicit mouse or desktop-environment triggers on top of the same state-controller boundary. Software integration events are intentionally out of scope for now.

## Asset Creation Pipeline

The `hatch-pet` skill handles asset creation around the same contract:

- Prepare a pet run folder and image generation manifest.
- Generate a base reference image.
- Generate or mirror row strips for the nine animation states.
- Extract frames into `192x208` cells.
- Compose the final `1536x1872` atlas.
- Validate transparent unused cells and non-empty used cells.
- Package `pet.json` and `spritesheet.webp` into `${CODEX_HOME}/pets/<pet-id>/`.

The deterministic scripts validate geometry and packaging, but visual consistency still needs manual review through the generated contact sheet and preview videos.

## Current Workspace Reproduction

This workspace implements a local runtime in:

```text
index.html
styles.css
app.js
Package.swift
Sources/LightPetDesktop/main.swift
```

The default pet package lives at:

```text
sample-pets/conan/
```

This proves that the Codex pet format can be reproduced outside the Codex app as long as the atlas and manifest contract are preserved.
