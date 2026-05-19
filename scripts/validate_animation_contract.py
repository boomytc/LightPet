#!/usr/bin/env python3
"""Validate the shared pet animation contract against the Swift runtime."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "docs" / "pet-animation-contract.json"
SWIFT_RUNTIME_PATH = ROOT / "Sources" / "LightPetDesktop" / "Core" / "PetRuntime.swift"


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def swift_int(name: str, source: str) -> int:
    match = re.search(rf"let {re.escape(name)}(?:\s*:\s*\w+)? = (\d+)", source)
    if not match:
        fail(f"Swift constant {name} was not found")
    return int(match.group(1))


def swift_rows(source: str) -> list[dict[str, object]]:
    pattern = re.compile(
        r'\.init\(state: "([^"]+)", row: (\d+), frameCount: (\d+), durations: \[([^\]]*)\]\)'
    )
    rows: list[dict[str, object]] = []
    for match in pattern.finditer(source):
        durations = [
            round(float(value.strip()) * 1000)
            for value in match.group(4).split(",")
            if value.strip()
        ]
        rows.append(
            {
                "state": match.group(1),
                "row": int(match.group(2)),
                "frames": int(match.group(3)),
                "durationsMs": durations,
            }
        )
    return rows


def main() -> None:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    swift = SWIFT_RUNTIME_PATH.read_text(encoding="utf-8")

    atlas = contract["atlas"]
    expected_constants = {
        "cellWidth": atlas["cellWidth"],
        "cellHeight": atlas["cellHeight"],
        "atlasColumns": atlas["columns"],
        "atlasRows": atlas["rows"],
        "visibleAlphaThreshold": atlas["visibleAlphaThreshold"],
    }
    for name, expected in expected_constants.items():
        actual = swift_int(name, swift)
        if actual != expected:
            fail(f"{name} mismatch: Swift has {actual}, contract has {expected}")

    contract_rows = [
        {
            "state": row["state"],
            "row": row["row"],
            "frames": row["frames"],
            "durationsMs": row["durationsMs"],
        }
        for row in contract["states"]
    ]
    runtime_rows = swift_rows(swift)
    if runtime_rows != contract_rows:
        print("error: animation rows differ between Swift and contract", file=sys.stderr)
        print("Swift:", json.dumps(runtime_rows, ensure_ascii=False), file=sys.stderr)
        print("Contract:", json.dumps(contract_rows, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(1)

    print("Animation contract matches Swift runtime.")


if __name__ == "__main__":
    main()
