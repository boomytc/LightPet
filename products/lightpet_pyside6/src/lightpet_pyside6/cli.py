from __future__ import annotations

import argparse
from dataclasses import dataclass
import sys
from pathlib import Path

from PySide6.QtCore import QSettings, Qt
from PySide6.QtWidgets import QApplication, QMessageBox

from .contract import AVAILABLE_SCALES, DEFAULT_STATE, ContractError, default_contract, format_scale
from .package_loader import (
    DEFAULTS_APPLICATION,
    DEFAULTS_ORGANIZATION,
    PetRuntimeError,
    load_selected_pet_package,
    remember_codex_pet,
)
from .pet_window import PetWindow


@dataclass(frozen=True)
class LaunchOptions:
    manifest_path: Path | None
    pet_id: str | None
    initial_state: str
    scale: float
    show_dock: bool
    resize_smoke_test: bool


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(sys.argv[1:] if argv is None else argv)

    QApplication.setAttribute(Qt.ApplicationAttribute.AA_DontShowIconsInMenus, False)
    app = QApplication(sys.argv[:1])
    app.setApplicationName(DEFAULTS_APPLICATION)
    app.setOrganizationName(DEFAULTS_ORGANIZATION)
    app.setQuitOnLastWindowClosed(False)
    settings = QSettings(DEFAULTS_ORGANIZATION, DEFAULTS_APPLICATION)

    try:
        contract = default_contract()
        if args.initial_state not in contract.row_by_state:
            raise PetRuntimeError(f"Unknown initial state: {args.initial_state}")
        package = load_selected_pet_package(
            manifest_path=args.manifest_path,
            pet_id=args.pet_id,
            settings=settings,
            contract=contract,
        )
    except (ContractError, PetRuntimeError) as exc:
        title = getattr(exc, "alert_title", "Could Not Start LightPet")
        QMessageBox.critical(None, title, str(exc))
        print(f"{title}: {exc}", file=sys.stderr)
        return 1

    remember_codex_pet(package, settings)
    window = PetWindow(
        package=package,
        contract=contract,
        settings=settings,
        initial_state=args.initial_state,
        scale=args.scale,
        show_dock=args.show_dock,
    )
    window.show()
    window.raise_()

    print(f"LightPetPySide6 loaded {package.manifest.display_name} from {package.manifest_path}")
    print("Mouse-only states: hover=waiting, click=failed, hold=waving, drag=left/right/up/down.")

    if args.resize_smoke_test:
        window.run_resize_smoke_test()

    return app.exec()


def _parse_args(argv: list[str]) -> LaunchOptions:
    parser = argparse.ArgumentParser(
        prog="lightpet-pyside6",
        description="PySide6 desktop runtime for Codex-compatible LightPet packages.",
    )
    parser.add_argument("--pet", dest="manifest_path", type=Path, help="Exact pet.json path.")
    parser.add_argument("--pet-id", help="Codex pet id to try when --pet is not provided.")
    parser.add_argument("--state", default=DEFAULT_STATE, help=f"Initial state, default: {DEFAULT_STATE}.")
    parser.add_argument(
        "--scale",
        type=float,
        default=1.0,
        choices=AVAILABLE_SCALES,
        metavar="SCALE",
        help="Window scale: " + ", ".join(f"{format_scale(scale)}x" for scale in AVAILABLE_SCALES),
    )
    parser.add_argument("--show-dock", action="store_true", help="Use a normal top-level window instead of a tool window.")
    parser.add_argument("--resize-smoke-test", action="store_true", help="Cycle through all supported sizes and exit.")
    parsed = parser.parse_args(argv)
    return LaunchOptions(
        manifest_path=parsed.manifest_path,
        pet_id=parsed.pet_id,
        initial_state=parsed.state,
        scale=parsed.scale,
        show_dock=parsed.show_dock,
        resize_smoke_test=parsed.resize_smoke_test,
    )


if __name__ == "__main__":
    raise SystemExit(main())

