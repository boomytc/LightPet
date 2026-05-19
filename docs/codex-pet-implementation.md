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

LightPet reads the same pet directory used by Codex and the `hatch-pet` skill:

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
  "spritesheetPath": "spritesheet.webp",
  "rendering": "pixelated"
}
```

The app discovers pets by folder name, reads `pet.json`, then loads the spritesheet named by `spritesheetPath`. For right-click folder selection, LightPet expects the selected folder to contain `pet.json` and `spritesheet.webp`, and expects `pet.json` to set `"spritesheetPath": "spritesheet.webp"`.

`rendering` is optional. Use `pixelated` for pixel art and `smooth` for non-pixel styles such as smooth 3D mascot art, hand-drawn sprites, or flat illustration. Omitted values default to `pixelated`.

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

LightPet supports non-pixel styles. The runtime only requires the transparent spritesheet contract; visual style can be pixel art, hand-drawn, flat illustration, smooth 3D toy-like mascot art, or another compact readable style. For non-pixel art, set `"rendering": "smooth"` in `pet.json`; for pixel art, set `"rendering": "pixelated"` or omit the field.

With reference image:

```text
Create a LightPet-compatible desktop pet package.

Package metadata:
- id: {id}
- displayName: {displayName}
- rendering: {rendering}

Reference image:
- Use the attached reference image as the visual source of truth.
- Infer one short pet description from the reference image for pet.json.
- Preserve the reference character's identity, proportions, silhouette, face, colors, clothing/accessories, material feel, and overall art style.
- If the reference is a smooth 3D toy-like mascot, keep that soft rounded 3D look instead of converting it to pixel art.
- Adapt the reference into consistent animation rows for mouse-only desktop pet interactions.

Output contract:
- Create a folder named {id}.
- The folder must contain exactly this runtime contract:
  - pet.json
  - spritesheet.webp
- pet.json must contain:
  {
    "id": "{id}",
    "displayName": "{displayName}",
    "description": "<one short sentence inferred from the reference image>",
    "spritesheetPath": "spritesheet.webp",
    "rendering": "{rendering}"
  }

spritesheet.webp requirements:
- Format: transparent-capable WebP.
- Exact size: 1536x1872 pixels.
- Grid: 8 columns x 9 rows.
- Cell size: 192x208 pixels.
- Each used cell must contain visible pet pixels.
- Unused cells after each row's frame count must be fully transparent.
- Keep the same pet identity, silhouette, palette, outline style, and proportions across all rows.
- Use the reference style consistently. For smooth 3D references, keep soft rounded forms, clean lighting, readable silhouettes, and transparent background.
- Do not include text, UI, speech bubbles, frame numbers, guide marks, shadows, detached motion lines, loose sparkles, or decorative effects separate from the pet body.
- Any effect must be small, hard-edged, style-consistent, mouse-action relevant, and attached to the pet silhouette.

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

Without reference image:

```text
Create a LightPet-compatible desktop pet package from text only.

Package metadata:
- id: {id}
- displayName: {displayName}
- description: {description}
- rendering: {rendering}

Character and style:
- Design a new desktop pet based on this description: {description}
- Art style: {style}
- If {style} is smooth 3D, make the pet look like a soft rounded toy mascot with clean lighting, simple materials, readable silhouette, and transparent background.
- If {style} is pixel art, use compact readable chibi proportions, crisp silhouette, limited palette, and transparent background.
- Keep the same identity, proportions, colors, clothing/accessories, and material feel across every row.

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
    "spritesheetPath": "spritesheet.webp",
    "rendering": "{rendering}"
  }

spritesheet.webp requirements:
- Format: transparent-capable WebP.
- Exact size: 1536x1872 pixels.
- Grid: 8 columns x 9 rows.
- Cell size: 192x208 pixels.
- Each used cell must contain visible pet pixels.
- Unused cells after each row's frame count must be fully transparent.
- Do not include text, UI, speech bubbles, frame numbers, guide marks, shadows, detached motion lines, loose sparkles, or decorative effects separate from the pet body.
- Any effect must be small, hard-edged, style-consistent, mouse-action relevant, and attached to the pet silhouette.

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

- Pet choices are discovered only from `${CODEX_HOME:-$HOME/.codex}/pets/*/pet.json`.
- If the Codex pet directory does not exist, startup creates it with intermediate directories.
- If the Codex pet path exists but is not a directory, startup shows a fatal alert.
- Startup lookup without `--pet` tries an explicit `--pet-id`, then the last successfully selected Codex pet, then the first discoverable Codex pet.
- If the remembered or requested Codex pet no longer exists, startup falls back to the first discoverable Codex pet instead of failing immediately.
- If no valid pet exists after fallback, startup shows a fatal alert instructing the user to add a folder containing `pet.json` and `spritesheet.webp`.
- If a non-`--pet` candidate exists but fails full spritesheet validation while loading, startup tries the next discoverable Codex pet before showing a fatal alert.
- Successful launches and right-click menu switches for `${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/` packages remember that `pet-id` for the next launch.
- The right-click menu keeps discovery lightweight: it reads `pet.json` and confirms `spritesheet.webp` exists, while full spritesheet validation runs only when a pet is selected or launched.
- The right-click `Pet` submenu includes `Choose Pet Folder...`; it loads a selected directory only when that directory contains `pet.json` and `spritesheet.webp`.
- `Choose Pet Folder...` is a temporary runtime load. It does not copy, install, modify pet files, or persist a default for folders outside the Codex pet directory.
- To make a pet appear in the menu on every launch, put its folder under `${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/`.
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

The native desktop wrapper discovers default pets from:

```text
${CODEX_HOME:-$HOME/.codex}/pets/
```

The browser preview remains a manifest-path preview tool; it can load any pet package URL that the local web server can serve.

This proves that the Codex pet format can be reproduced outside the Codex app as long as the atlas and manifest contract are preserved.
