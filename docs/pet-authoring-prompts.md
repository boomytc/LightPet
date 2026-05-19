# Pet Authoring Prompts

This document captures the prompt structure that LightPet wants to preserve from `hatch-pet` runs. It is not a replacement for the Codex `hatch-pet` skill. Use the skill for the full visual generation pipeline; use this file to keep action-row prompts consistent when extending or repairing an already finished pet.

## Grounding Inputs

For a finished pet, keep these assets available before asking for a new or repaired row:

- `pet.json` and the current `spritesheet.webp`
- original reference image(s), if any
- `references/canonical-base.png`
- `qa/contact-sheet.png`
- target `references/layout-guides/<state>.png`
- existing target row or related movement row when useful, such as `decoded/running-right.png` for `running-left`

The base image and contact sheet are important because row-level generation must preserve the existing pet identity, not create a related redesign.

## Base Pet Prompt Template

Use this shape when creating or refreshing the canonical base reference:

```text
Create a single clean reference sprite for a Codex app digital pet named {displayName}.

Pet: {stable pet identity, species/object, body shape, face, palette, clothing, accessories, material, and personality}.
Style contract: {pixel-art-adjacent Codex pet style or smooth 3D toy mascot style}. Keep details readable at 192x208. Preserve the exact palette and defining props. Do not convert the chosen style into another art direction.

Use this prompt as an authoritative sprite-production spec. Keep it as a clean isolated desktop-pet sprite, not a polished illustration, painterly character image, anime key art, vector mascot, glossy app icon, realistic portrait, or marketing artwork.

Output one centered full-body pet sprite pose only, on a perfectly flat {chroma_key_hex} chroma-key background. The pet must be fully visible, readable as a tiny digital pet, and suitable for animation into a 192x208 sprite cell. Do not include scenery, text, labels, borders, checkerboard transparency, detached effects, shadows, glows, or extra props not present in the reference unless explicitly requested. Do not use the chroma key or near-key colors in the pet, prop, highlights, or effects.
```

## Row Strip Prompt Template

Use this shape for a single action row:

```text
Create a single horizontal sprite strip for the Codex app digital pet `{pet_id}` in the state `{state}`.

Use the attached reference image(s) for pet identity and the attached base pet image as the canonical design. Use the attached layout guide image only for frame count, slot spacing, centering, and safe padding. Preserve the existing style while simplifying only details too small for 192x208. Do not simply copy the still reference pose. Generate distinct animation poses that create a readable cycle.

Identity lock:
- Do not redesign the pet. Only change pose/action for the `{state}` animation.
- Preserve the exact head shape, limb shape, face design, markings, palette, outline/material style, body proportions, prop design, and overall silhouette from the canonical base pet.
- Keep every frame recognizably the same individual pet, not a related variant.
- Preserve prop size, side, palette, and attachment unless the row action requires a small pose-only adjustment.
- Prefer a subtler animation over any change that mutates the pet identity.

Output exactly {frame_count} separate animation frames arranged left-to-right in one single row. Each frame must show the same pet: {stable pet identity sentence}.

Style contract: {style contract}. Keep the rendering compact and readable. Do not change art direction.

Animation action: {action description}.

State-specific requirements:
{state requirements}

Transparency and artifact rules:
- Prefer pose, expression, and silhouette changes over decorative effects.
- Effects are allowed only when they are state-relevant, opaque, hard-edged, style-consistent, fully inside the same frame slot, and physically touching or overlapping the pet silhouette.
- Do not draw detached effects, floating symbols, wave marks, motion arcs, speed lines, afterimages, blur, glows, floor patches, cast shadows, contact shadows, drop shadows, landing marks, dust, scenery, text, labels, frame numbers, guide marks, UI panels, speech bubbles, or checkerboard transparency.
- Do not use the chroma-key color or chroma-key-adjacent colors in the pet, prop, effects, highlights, shadows, or outlines.
- Reject any pose that is cropped, overlaps another pose, crosses into a neighboring frame slot, or creates a separate disconnected component.

Layout requirements:
- Exactly {frame_count} full-body frames, left to right, in one horizontal row.
- Follow the attached layout guide for slot count, spacing, centering, and padding, but do not reproduce visible guide pixels.
- Treat the image as {frame_count} equal-width invisible frame slots. Fill every slot with exactly one complete full-body pose.
- Spread poses evenly across the whole image width.
- Center one complete pose in each slot. No pose may cross into a neighboring slot.
- Use a perfectly flat {chroma_key_hex} chroma-key background across the whole image.
- Keep every frame self-contained with safe padding. No pet body part should be clipped.
- Avoid motion blur. Use clear pose changes readable at 192x208.
- Preserve the same silhouette, face, proportions, palette, material, and props across every frame.
```

## Compatible State Rows

The machine-readable source of truth is `docs/pet-animation-contract.json`. Use its `states[*].frames`, `states[*].durationsMs`, `purpose`, `mouseMapping`, and `authoringNotes` fields when writing row prompts or targeted repair instructions.

If a prompt, README, Swift runtime, or Web preview disagrees with that contract, update the contract first and then run:

```bash
python3 scripts/validate_animation_contract.py
```

## Adding One Action To A Finished Pet

For the current Codex-compatible package format, a new action must replace or reinterpret one of the 9 compatible rows. A true extra state requires a future LightPet manifest/runtime extension.

Single-row update flow:

1. Pick the target row and write a specific action sentence.
2. Attach the original reference, `canonical-base.png`, current contact sheet, and target layout guide.
3. Generate only the target row strip through `hatch-pet` / `$imagegen`.
4. Record the selected generated source through the skill's manifest-aware recording flow.
5. Re-extract frames, compose the atlas, validate unused cells, generate contact sheet, and render preview videos.
6. Compare the new contact sheet against the old one before accepting the row.

Block acceptance if the row changes species, body type, face, palette, prop design, prop side, material style, or overall silhouette. Deterministic validation is required but not enough; visual identity review is still mandatory.
