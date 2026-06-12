# Example Hatch-Pet Run

This fixture documents the shape of a Codex `hatch-pet` implementation run for
creating a LightPet-compatible desktop pet. Real local runs should still live
under the ignored `.pet-runs/<pet-id>/` directory.

This is product-owned authoring documentation for the macOS runtime package
surface. It is not a workspace-root runtime asset and should not be copied into
the repository root.

It intentionally contains only text fixtures. A real run will add generated
binary artifacts under `references/`, `decoded/`, `frames/`, `final/`, and
`qa/`; those artifacts remain ignored unless a maintainer deliberately promotes
specific files into a product example or documentation fixture.

Expected real-run structure:

```text
.pet-runs/<pet-id>/
├── pet_request.json
├── imagegen-jobs.json
├── prompts/
│   ├── base-pet.md
│   └── rows/
│       ├── idle.md
│       ├── running-right.md
│       ├── running-left.md
│       ├── waving.md
│       ├── jumping.md
│       ├── failed.md
│       ├── waiting.md
│       ├── running.md
│       └── review.md
├── references/
│   ├── canonical-base.png
│   └── layout-guides/
├── decoded/
├── frames/
│   └── frames-manifest.json
├── final/
│   ├── spritesheet.png
│   ├── spritesheet.webp
│   └── validation.json
└── qa/
    ├── contact-sheet.png
    ├── review.json
    ├── run-summary.json
    └── videos/
```

The accepted runtime package is the small output copied to a pet directory:

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
├── pet.json
└── spritesheet.webp
```
