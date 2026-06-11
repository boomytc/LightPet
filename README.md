# LightPet

LightPet is organized as a product workspace. Current products:

```text
products/lightpet_runtime/   Swift/AppKit desktop runtime plus Web preview
products/lightpet_pyside6/   PySide6 desktop runtime
```

Each product owns its runtime code, package metadata, docs, examples, scripts,
and local environment. Run product commands from the product directory, or use
root Makefile targets that delegate into a product.

## Layout

```text
.
├── AGENTS.md
├── Makefile
├── products/
│   ├── AGENTS.md
│   ├── lightpet_runtime/
│   │   ├── AGENTS.md
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   ├── Assets/
│   │   ├── preview/
│   │   ├── examples/
│   │   ├── docs/
│   │   └── scripts/
│   └── lightpet_pyside6/
│       ├── AGENTS.md
│       ├── pyproject.toml
│       ├── src/
│       ├── docs/
│       ├── examples/
│       ├── scripts/
│       └── tests/
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

PySide6 product:

```bash
make pyside6-install
make pyside6-validate
make pyside6-test
make pyside6-run-example
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
See `products/lightpet_pyside6/README.md` for the PySide6 runtime.
