# LightPet

LightPet is organized as a product workspace. Current products:

```text
products/lightpet_macos/   Swift/AppKit native macOS runtime plus Web preview
products/lightpet_qt/      PySide6/Qt desktop runtime
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
│   ├── lightpet_macos/
│   │   ├── AGENTS.md
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   ├── Assets/
│   │   ├── preview/
│   │   ├── examples/
│   │   ├── docs/
│   │   └── scripts/
│   └── lightpet_qt/
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

Qt product:

```bash
make qt-install
make qt-validate
make qt-test
make qt-run-example
```

Equivalent direct product usage:

```bash
cd products/lightpet_macos
python3 scripts/validate_animation_contract.py
swift build --product LightPetDesktop
python3 -m http.server 18091 --directory .
```

Equivalent direct Qt product usage:

```bash
cd products/lightpet_qt
uv venv --python 3.12
make install
make run-example
```

Open the Web preview at `http://127.0.0.1:18091/preview/web/`.

See `products/lightpet_macos/README.md` for runtime behavior, pet package contract, and authoring notes.
See `products/lightpet_qt/README.md` for the Qt runtime.
