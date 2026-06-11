from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
import json
from pathlib import Path
from typing import Any


PRODUCT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONTRACT_PATH = PRODUCT_ROOT / "docs" / "pet-animation-contract.json"
AVAILABLE_SCALES = (0.5, 0.75, 1.0, 1.25, 1.5)
DEFAULT_STATE = "idle"
MIN_VISIBLE_PIXELS = 50


class ContractError(ValueError):
    """Raised when the animation contract is internally inconsistent."""


@dataclass(frozen=True)
class AtlasGeometry:
    columns: int
    rows: int
    cell_width: int
    cell_height: int
    visible_alpha_threshold: int

    @property
    def width(self) -> int:
        return self.columns * self.cell_width

    @property
    def height(self) -> int:
        return self.rows * self.cell_height


@dataclass(frozen=True)
class AnimationRow:
    state: str
    row: int
    frame_count: int
    durations_ms: tuple[int, ...]
    purpose: str
    mouse_mapping: str
    authoring_notes: tuple[str, ...]

    @property
    def total_duration_ms(self) -> int:
        return sum(self.durations_ms)


@dataclass(frozen=True)
class AnimationContract:
    atlas: AtlasGeometry
    rows: tuple[AnimationRow, ...]

    @property
    def row_by_state(self) -> dict[str, AnimationRow]:
        return {row.state: row for row in self.rows}

    @property
    def state_names(self) -> tuple[str, ...]:
        return tuple(row.state for row in self.rows)


def load_animation_contract(path: Path | str = DEFAULT_CONTRACT_PATH) -> AnimationContract:
    contract_path = Path(path)
    try:
        payload = json.loads(contract_path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ContractError(f"Could not read animation contract: {contract_path}") from exc
    except json.JSONDecodeError as exc:
        raise ContractError(f"Animation contract is not valid JSON: {contract_path}") from exc

    return parse_animation_contract(payload)


@lru_cache(maxsize=1)
def default_contract() -> AnimationContract:
    return load_animation_contract(DEFAULT_CONTRACT_PATH)


def parse_animation_contract(payload: dict[str, Any]) -> AnimationContract:
    atlas_payload = payload.get("atlas")
    states_payload = payload.get("states")
    if not isinstance(atlas_payload, dict):
        raise ContractError("Animation contract is missing atlas.")
    if not isinstance(states_payload, list) or not states_payload:
        raise ContractError("Animation contract must contain at least one state.")

    atlas = AtlasGeometry(
        columns=_positive_int(atlas_payload, "columns"),
        rows=_positive_int(atlas_payload, "rows"),
        cell_width=_positive_int(atlas_payload, "cellWidth"),
        cell_height=_positive_int(atlas_payload, "cellHeight"),
        visible_alpha_threshold=_nonnegative_int(atlas_payload, "visibleAlphaThreshold"),
    )

    rows: list[AnimationRow] = []
    seen_states: set[str] = set()
    seen_indices: set[int] = set()
    for item in states_payload:
        if not isinstance(item, dict):
            raise ContractError("Each animation state must be an object.")
        state = item.get("state")
        if not isinstance(state, str) or not state:
            raise ContractError("Each animation state needs a non-empty state name.")
        if state in seen_states:
            raise ContractError(f"Duplicate animation state: {state}")
        seen_states.add(state)

        row_index = _nonnegative_int(item, "row")
        if row_index >= atlas.rows:
            raise ContractError(f"{state} row {row_index} is outside atlas rows.")
        if row_index in seen_indices:
            raise ContractError(f"Duplicate atlas row: {row_index}")
        seen_indices.add(row_index)

        frame_count = _positive_int(item, "frames")
        if frame_count > atlas.columns:
            raise ContractError(f"{state} uses {frame_count} frames but atlas has {atlas.columns} columns.")

        durations = item.get("durationsMs")
        if not isinstance(durations, list) or len(durations) != frame_count:
            raise ContractError(f"{state} must have one duration per frame.")
        duration_values = tuple(_positive_duration(value, state) for value in durations)

        notes = item.get("authoringNotes", [])
        if not isinstance(notes, list):
            raise ContractError(f"{state} authoringNotes must be a list.")

        rows.append(
            AnimationRow(
                state=state,
                row=row_index,
                frame_count=frame_count,
                durations_ms=duration_values,
                purpose=str(item.get("purpose") or state),
                mouse_mapping=str(item.get("mouseMapping") or ""),
                authoring_notes=tuple(str(note) for note in notes),
            )
        )

    rows.sort(key=lambda row: row.row)
    if rows[0].state != DEFAULT_STATE:
        raise ContractError(f"The first animation row must be {DEFAULT_STATE}.")

    return AnimationContract(atlas=atlas, rows=tuple(rows))


def format_scale(scale: float) -> str:
    if abs(scale - int(scale)) < 0.001:
        return str(int(scale))
    return f"{scale:.2f}".rstrip("0").rstrip(".")


def _positive_int(payload: dict[str, Any], key: str) -> int:
    value = payload.get(key)
    if not isinstance(value, int) or value <= 0:
        raise ContractError(f"{key} must be a positive integer.")
    return value


def _nonnegative_int(payload: dict[str, Any], key: str) -> int:
    value = payload.get(key)
    if not isinstance(value, int) or value < 0:
        raise ContractError(f"{key} must be a non-negative integer.")
    return value


def _positive_duration(value: Any, state: str) -> int:
    if not isinstance(value, int) or value <= 0:
        raise ContractError(f"{state} durationsMs values must be positive integers.")
    return value

