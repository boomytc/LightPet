# LightPet

LightPet is now organized as a product workspace. The current runtime product is:

```text
products/lightpet_runtime/
```

That product contains the Swift desktop runtime, static Web preview, runtime examples, package metadata, docs, assets, and scripts. Run product commands from that directory, or use the root Makefile targets that delegate into it.

## Layout

```text
.
├── AGENTS.md
├── Makefile
├── products/
│   ├── AGENTS.md
│   └── lightpet_runtime/
│       ├── AGENTS.md
│       ├── Package.swift
│       ├── Sources/
│       ├── Assets/
│       ├── preview/
│       ├── examples/
│       ├── docs/
│       └── scripts/
└── README.md
```

## Commands

```bash
make validate-contract
make build
make preview
make package-app
make clean
```

Equivalent direct product usage:

```bash
cd products/lightpet_runtime
python3 scripts/validate_animation_contract.py
swift build --product LightPetDesktop
python3 -m http.server 18091 --directory .
```

Open the Web preview at `http://127.0.0.1:18091/preview/web/`.

See `products/lightpet_runtime/README.md` for runtime behavior, pet package contract, and authoring notes.
