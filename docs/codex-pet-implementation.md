# Codex Pet Implementation Notes

## Project Boundary

LightPet is only a player and desktop presentation wrapper for existing Codex-compatible pet packages. It is responsible for:

- Reading `pet.json`.
- Loading and validating `spritesheet.webp`.
- Mapping mouse actions to existing animation rows.
- Showing size and pet-package choices in the desktop right-click menu.

It is not responsible for:

- Generating pet artwork.
- Repairing broken rows or transparent backgrounds.
- Prompt planning for image generation.
- Packaging generated files.
- Integrating animation states with external app or software events.

Use the `hatch-pet` skill or another asset pipeline to create packages that match the contract below.

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

The app discovers pets by folder name, reads `pet.json`, then loads the spritesheet named by `spritesheetPath`. For right-click folder selection, LightPet expects the selected folder to contain `pet.json` and `spritesheet.webp`, and expects `pet.json` to set `"spritesheetPath": "spritesheet.webp"`.

## Atlas Geometry

The animation surface is a fixed sprite atlas:

```text
atlas: 1536x1872
grid:  8 columns x 9 rows
cell:  192x208
```

The player does not need per-frame rectangles in the manifest. A state maps to a fixed atlas row, and a frame index maps to a fixed column. Unused cells after the last used column in a row must stay fully transparent.

`spritesheet.webp` should contain the pet only, on a transparent background. Each used frame must keep the same pet identity, silhouette, palette, outline style, and proportions. Avoid text, UI, speech bubbles, shadows, guide boxes, frame numbers, detached motion lines, loose sparkles, or decorative effects that are separate from the pet body.

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

Prompting guidance for `hatch-pet` or another generator:

The row names stay Codex-compatible, but LightPet treats them as mouse-action slots. For a mouse-only desktop pet, design the visuals around direct manipulation instead of external app state.

| State | Visual Intent |
| --- | --- |
| `idle` | Calm resting loop with subtle breathing, blink, or small posture shift. |
| `running-right` | Drag-right pose: the pet is pulled by the right hand, right sleeve, or right side of the body. |
| `running-left` | Drag-left pose: the pet is pulled by the left hand, left sleeve, or left side of the body. |
| `waving` | Long-press pose: the pet looks grabbed and may lightly struggle; no wave marks or floating symbols. |
| `jumping` | Drag-up pose: the pet is lifted upward or stretched upward by the grab. |
| `failed` | Click reaction: the pet staggers one step backward, then recovers. |
| `waiting` | Attentive hover state, looking ready for interaction. |
| `running` | Spare neutral drag or struggle loop; keep valid frames even though the current mouse logic does not trigger it directly. |
| `review` | Drag-down pose: the pet lies low or prone, as if pressed down by the cursor. |

Copyable prompt template:

```text
Create a LightPet-compatible desktop pet package.

Package metadata:
- id: {id}
- displayName: {displayName}
- description: {description}

Output contract:
- Create a folder named {id}.
- The folder must contain exactly this runtime contract:
  - pet.json
  - spritesheet.webp
- pet.json must contain:
  {
    "id": "{id}",
    "displayName": "{displayName}",
    "description": "{description}",
    "spritesheetPath": "spritesheet.webp"
  }

spritesheet.webp requirements:
- Format: transparent-capable WebP.
- Exact size: 1536x1872 pixels.
- Grid: 8 columns x 9 rows.
- Cell size: 192x208 pixels.
- Each used cell must contain visible pet pixels.
- Unused cells after each row's frame count must be fully transparent.
- Keep the same pet identity, silhouette, palette, outline style, and proportions across all rows.
- Use compact pixel-art mascot styling: readable chibi proportions, thick clear outline, limited palette, flat cel shading, transparent background.
- Do not include text, UI, speech bubbles, frame numbers, guide marks, shadows, detached motion lines, loose sparkles, or decorative effects separate from the pet body.
- Any effect must be small, hard-edged, pixel-style, mouse-action relevant, and attached to the pet silhouette.

Animation rows:
0. idle, 6 frames: calm resting loop with subtle breathing or blinking.
1. running-right, 8 frames: drag-right pose; the pet is pulled by the right hand, right sleeve, or right side of the body.
2. running-left, 8 frames: drag-left pose; the pet is pulled by the left hand, left sleeve, or left side of the body.
3. waving, 4 frames: long-press grabbed pose; the pet looks grabbed and may lightly struggle.
4. jumping, 5 frames: drag-up pose; the pet is lifted upward or stretched upward by the grab.
5. failed, 8 frames: click reaction; the pet staggers one step backward, then recovers.
6. waiting, 6 frames: attentive hover state, looking ready for interaction.
7. running, 6 frames: spare neutral drag or struggle loop; keep valid frames even if not triggered directly.
8. review, 6 frames: drag-down pose; the pet lies low or prone, as if pressed down by the cursor.
```

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
click                 failed
long press            waving
drag left/right       move the panel and select running-left/running-right
drag up/down          move the panel and select jumping/review
mouse up              return to waiting or idle depending on pointer position
right click           show size, pet, reset-position, and quit menu
```

The right-click menu intentionally does not list animation states. States are selected by the desktop pet's mouse interaction model.

Additional desktop behavior:

- Pet choices are discovered from `sample-pets/*/pet.json` and `${CODEX_HOME:-~/.codex}/pets/*/pet.json`, then fully loaded and validated before appearing in the menu.
- The right-click `Pet` submenu includes `Choose Pet Folder...`; it loads a selected directory only when that directory contains `pet.json` and `spritesheet.webp`.
- `Choose Pet Folder...` is a temporary runtime load. It does not copy, install, or modify pet files.
- To make a pet appear in the menu on every launch, put its folder under `sample-pets/<pet-id>/` or `${CODEX_HOME:-~/.codex}/pets/<pet-id>/`.
- Window size can be changed from the right-click menu.
- Hit testing samples the current frame alpha map, so transparent sprite pixels do not start pet interaction.
- Dragging is clamped to the visible screen union to keep the pet reachable.

This is the practical minimum for a desktop pet. More advanced behavior should be added as explicit mouse or desktop-environment triggers on top of the same state-controller boundary. Software integration events are intentionally out of scope for now.

## External Asset Creation

Pet generation stays outside this repository. A generator such as the `hatch-pet` skill should produce the final folder:

```text
<pet-id>/
├── pet.json
└── spritesheet.webp
```

For a package to work here, the generated spritesheet must already be transparent, correctly sized, row-aligned, visually consistent, and free of non-transparent unused cells. LightPet validates these runtime requirements but does not repair them.

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
