#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from lightpet_qt.contract import load_animation_contract  # noqa: E402
from lightpet_qt.package_loader import load_pet_package  # noqa: E402


EXPECTED_STATES = (
    "idle",
    "running-right",
    "running-left",
    "waving",
    "jumping",
    "failed",
    "waiting",
    "running",
    "review",
)


def main() -> int:
    contract = load_animation_contract(ROOT / "docs" / "pet-animation-contract.json")
    if contract.state_names != EXPECTED_STATES:
        print(f"error: unexpected states: {contract.state_names}", file=sys.stderr)
        return 1

    package = load_pet_package(ROOT / "examples" / "pets" / "lulu" / "pet.json", contract)
    for row in contract.rows:
        frames = package.frames.frames_by_state.get(row.state)
        if frames is None or len(frames) != row.frame_count:
            print(f"error: {row.state} frame store mismatch", file=sys.stderr)
            return 1

    print("Animation contract matches Qt runtime and bundled example package.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

