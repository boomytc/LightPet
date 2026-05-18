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
4. Open a transparent, borderless `NSPanel`.
5. Crop the active `192x208` cell from the atlas and draw it into the panel.
6. Advance frames with a `Timer` using the same duration table as the web preview.

Window settings:

```text
style: borderless, non-activating panel
background: transparent
level: floating
spaces: can join all spaces, fullscreen auxiliary
```

Mouse behavior:

```text
left drag     move the panel; horizontal direction selects running-right or running-left
mouse up      return to idle
double click  cycle through animation states
right click   show state menu and quit command
```

This is the practical minimum for a desktop pet. More advanced behavior should be added as explicit state triggers on top of the same `setState(...)` boundary, for example hover, idle timeout, app activity, or screen-edge collision.

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
