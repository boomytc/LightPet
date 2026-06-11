from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
from typing import Iterable

from PySide6.QtCore import QSettings
from PySide6.QtGui import QImage

from .contract import AnimationContract, AnimationRow, MIN_VISIBLE_PIXELS, default_contract


DEFAULTS_ORGANIZATION = "LightPet"
DEFAULTS_APPLICATION = "LightPetPySide6"
LAST_CODEX_PET_ID_KEY = "lastCodexPetID"


class PetRuntimeError(RuntimeError):
    def __init__(self, message: str, alert_title: str = "Could Not Start LightPet") -> None:
        super().__init__(message)
        self.alert_title = alert_title


@dataclass(frozen=True)
class PetManifest:
    id: str
    display_name: str
    description: str
    spritesheet_path: str
    rendering: str = "pixelated"

    @property
    def uses_smooth_rendering(self) -> bool:
        return self.rendering == "smooth"


@dataclass(frozen=True)
class PetFrame:
    image: QImage
    alpha: bytes
    cell_width: int
    cell_height: int
    visible_alpha_threshold: int

    def has_visible_pixel(self, x: int, y: int) -> bool:
        if x < 0 or x >= self.cell_width or y < 0 or y >= self.cell_height:
            return False
        return self.alpha[y * self.cell_width + x] > self.visible_alpha_threshold


@dataclass(frozen=True)
class PetFrameStore:
    frames_by_state: dict[str, tuple[PetFrame, ...]]

    @classmethod
    def from_atlas(cls, atlas: QImage, contract: AnimationContract) -> "PetFrameStore":
        geometry = contract.atlas
        if atlas.width() != geometry.width or atlas.height() != geometry.height:
            raise PetRuntimeError(
                f"Expected {geometry.width}x{geometry.height} spritesheet, "
                f"got {atlas.width()}x{atlas.height()}."
            )

        frames_by_state: dict[str, tuple[PetFrame, ...]] = {}
        for row in contract.rows:
            frames: list[PetFrame] = []
            for column in range(row.frame_count):
                frame = _make_frame(atlas, contract, row, column)
                visible_pixels = sum(1 for alpha in frame.alpha if alpha > geometry.visible_alpha_threshold)
                if visible_pixels <= MIN_VISIBLE_PIXELS:
                    raise PetRuntimeError(f"{row.state} column {column} is empty or too sparse.")
                frames.append(frame)

            for column in range(row.frame_count, geometry.columns):
                frame = _make_frame(atlas, contract, row, column)
                nonzero_alpha_pixels = sum(1 for alpha in frame.alpha if alpha != 0)
                if nonzero_alpha_pixels:
                    raise PetRuntimeError(f"{row.state} unused column {column} is not fully transparent.")

            frames_by_state[row.state] = tuple(frames)

        return cls(frames_by_state=frames_by_state)

    def frame(self, row: AnimationRow, index: int) -> PetFrame:
        frames = self.frames_by_state.get(row.state)
        if not frames:
            raise PetRuntimeError(f"Missing frames for {row.state}.")
        return frames[index % len(frames)]


@dataclass(frozen=True)
class PetPackage:
    manifest: PetManifest
    manifest_path: Path
    spritesheet_path: Path
    frames: PetFrameStore


@dataclass(frozen=True)
class PetChoice:
    manifest: PetManifest
    manifest_path: Path

    @property
    def title(self) -> str:
        return self.manifest.display_name or self.manifest.id


def load_pet_package(manifest_path: Path | str, contract: AnimationContract | None = None) -> PetPackage:
    active_contract = contract or default_contract()
    manifest_file = Path(manifest_path).expanduser().resolve()
    manifest = load_pet_manifest(manifest_file)
    spritesheet_path = resolve_spritesheet_path(manifest, manifest_file)
    atlas = QImage(str(spritesheet_path))
    if atlas.isNull():
        raise PetRuntimeError(f"Could not load spritesheet at {spritesheet_path}.")

    return PetPackage(
        manifest=manifest,
        manifest_path=manifest_file,
        spritesheet_path=spritesheet_path,
        frames=PetFrameStore.from_atlas(atlas, active_contract),
    )


def load_pet_package_from_directory(
    directory_path: Path | str,
    contract: AnimationContract | None = None,
) -> PetPackage:
    directory = Path(directory_path).expanduser().resolve()
    manifest_path = directory / "pet.json"
    if not manifest_path.exists():
        raise PetRuntimeError("Selected folder must contain pet.json.")
    spritesheet_path = directory / "spritesheet.webp"
    if not spritesheet_path.exists():
        raise PetRuntimeError("Selected folder must contain spritesheet.webp.")
    manifest = load_pet_manifest(manifest_path)
    if manifest.spritesheet_path != "spritesheet.webp":
        raise PetRuntimeError("pet.json must set spritesheetPath to spritesheet.webp.")
    return load_pet_package(manifest_path, contract)


def load_pet_manifest(manifest_path: Path | str) -> PetManifest:
    manifest_file = Path(manifest_path).expanduser().resolve()
    try:
        payload = json.loads(manifest_file.read_text(encoding="utf-8"))
    except OSError as exc:
        raise PetRuntimeError(f"Could not read pet manifest at {manifest_file}.") from exc
    except json.JSONDecodeError as exc:
        raise PetRuntimeError(f"Pet manifest is not valid JSON at {manifest_file}.") from exc

    def required_string(key: str) -> str:
        value = payload.get(key)
        if not isinstance(value, str) or not value:
            raise PetRuntimeError(f"pet.json must contain a non-empty {key}.")
        return value

    rendering = payload.get("rendering", "pixelated")
    if rendering not in {"pixelated", "smooth"}:
        rendering = "pixelated"

    return PetManifest(
        id=required_string("id"),
        display_name=required_string("displayName"),
        description=required_string("description"),
        spritesheet_path=required_string("spritesheetPath"),
        rendering=rendering,
    )


def resolve_spritesheet_path(manifest: PetManifest, manifest_path: Path | str) -> Path:
    candidate = Path(manifest.spritesheet_path).expanduser()
    if not candidate.is_absolute():
        candidate = Path(manifest_path).expanduser().resolve().parent / candidate
    return candidate.resolve()


def discover_pet_choices(library_path: Path | str | None = None) -> list[PetChoice]:
    library = ensure_codex_pet_library_exists() if library_path is None else Path(library_path).expanduser()
    choices: list[PetChoice] = []
    seen: set[Path] = set()
    for manifest_path in pet_manifest_paths(library):
        if manifest_path in seen:
            continue
        seen.add(manifest_path)
        choice = pet_choice(manifest_path)
        if choice is not None:
            choices.append(choice)
    return sorted(choices, key=lambda choice: choice.title.casefold())


def pet_choice(manifest_path: Path | str) -> PetChoice | None:
    manifest_file = Path(manifest_path).expanduser().resolve()
    try:
        manifest = load_pet_manifest(manifest_file)
    except PetRuntimeError:
        return None
    if manifest.spritesheet_path != "spritesheet.webp":
        return None
    if not resolve_spritesheet_path(manifest, manifest_file).exists():
        return None
    return PetChoice(manifest=manifest, manifest_path=manifest_file)


def pet_manifest_paths(root: Path | str) -> Iterable[Path]:
    root_path = Path(root).expanduser()
    if not root_path.is_dir():
        return []
    return (
        (entry / "pet.json").resolve()
        for entry in root_path.iterdir()
        if entry.is_dir() and not entry.name.startswith(".") and (entry / "pet.json").exists()
    )


def resolve_initial_manifest_path(
    manifest_path: Path | str | None,
    pet_id: str | None,
    last_pet_id: str | None,
) -> Path:
    if manifest_path is not None:
        candidate = Path(manifest_path).expanduser().resolve()
        if not candidate.exists():
            raise PetRuntimeError(f"Pet manifest does not exist at {candidate}.")
        return candidate

    library_path = ensure_codex_pet_library_exists()
    for candidate_pet_id in (pet_id, last_pet_id):
        if not candidate_pet_id:
            continue
        candidate = codex_pet_manifest_path(candidate_pet_id)
        if candidate.exists():
            return candidate
        print(
            f"LightPetPySide6 warning: pet '{candidate_pet_id}' was not found under "
            f"{library_path}; falling back to the first available Codex pet."
        )

    choices = discover_pet_choices(library_path)
    if choices:
        return choices[0].manifest_path
    raise PetRuntimeError(
        f"No valid pets were found in {library_path}.\n\n"
        f"Add a pet folder under {library_path}/<pet-id>/ containing pet.json "
        "and spritesheet.webp, then launch LightPet again.",
        alert_title="No Pets Found",
    )


def load_selected_pet_package(
    manifest_path: Path | str | None,
    pet_id: str | None,
    settings: QSettings,
    contract: AnimationContract,
) -> PetPackage:
    selected_manifest = resolve_initial_manifest_path(
        manifest_path=manifest_path,
        pet_id=pet_id,
        last_pet_id=last_codex_pet_id(settings),
    )
    try:
        return load_pet_package(selected_manifest, contract)
    except PetRuntimeError as exc:
        if manifest_path is not None:
            raise
        print(
            f"LightPetPySide6 warning: pet at {selected_manifest} could not be loaded: "
            "trying the next available Codex pet."
        )
        choices = [choice for choice in discover_pet_choices() if choice.manifest_path != selected_manifest]
        last_error: Exception = exc
        for choice in choices:
            try:
                return load_pet_package(choice.manifest_path, contract)
            except PetRuntimeError as fallback_error:
                last_error = fallback_error
                print(f"LightPetPySide6 warning: pet at {choice.manifest_path} could not be loaded.")
        raise PetRuntimeError(
            f"No loadable pets were found in {codex_pet_library_path()}.\n\n"
            "Add a pet folder containing a valid pet.json and spritesheet.webp, "
            f"then launch LightPet again.\n\nLast load error: {last_error}",
            alert_title="No Loadable Pets",
        ) from exc


def codex_home_path() -> Path:
    env_path = os.environ.get("CODEX_HOME")
    if env_path:
        return Path(env_path).expanduser().resolve()
    return (Path.home() / ".codex").resolve()


def codex_pet_library_path() -> Path:
    return codex_home_path() / "pets"


def ensure_codex_pet_library_exists() -> Path:
    library = codex_pet_library_path()
    if library.exists() and not library.is_dir():
        raise PetRuntimeError(
            f"The Codex pet path exists but is not a directory: {library}",
            alert_title="Pet Directory Is Invalid",
        )
    library.mkdir(parents=True, exist_ok=True)
    return library


def codex_pet_manifest_path(pet_id: str) -> Path:
    return codex_pet_library_path() / pet_id / "pet.json"


def codex_pet_id_for(manifest_path: Path | str) -> str | None:
    manifest_file = Path(manifest_path).expanduser().resolve()
    if manifest_file.name != "pet.json":
        return None
    pet_dir = manifest_file.parent
    try:
        if pet_dir.parent.resolve() != codex_pet_library_path().resolve():
            return None
    except OSError:
        return None
    return pet_dir.name


def last_codex_pet_id(settings: QSettings) -> str | None:
    value = settings.value(LAST_CODEX_PET_ID_KEY, "", str)
    return value or None


def remember_codex_pet(package: PetPackage, settings: QSettings) -> None:
    pet_id = codex_pet_id_for(package.manifest_path)
    if pet_id:
        settings.setValue(LAST_CODEX_PET_ID_KEY, pet_id)


def _make_frame(
    atlas: QImage,
    contract: AnimationContract,
    row: AnimationRow,
    column: int,
) -> PetFrame:
    geometry = contract.atlas
    image = atlas.copy(
        column * geometry.cell_width,
        row.row * geometry.cell_height,
        geometry.cell_width,
        geometry.cell_height,
    )
    if image.isNull():
        raise PetRuntimeError(f"Could not crop row {row.row}, column {column}.")
    return PetFrame(
        image=image,
        alpha=_alpha_map(image, geometry.cell_width, geometry.cell_height),
        cell_width=geometry.cell_width,
        cell_height=geometry.cell_height,
        visible_alpha_threshold=geometry.visible_alpha_threshold,
    )


def _alpha_map(image: QImage, width: int, height: int) -> bytes:
    rgba = image.convertToFormat(QImage.Format.Format_RGBA8888)
    data = memoryview(rgba.constBits())[: rgba.sizeInBytes()].tobytes()
    bytes_per_line = rgba.bytesPerLine()
    alpha = bytearray(width * height)
    for y in range(height):
        source_start = y * bytes_per_line
        row = data[source_start : source_start + width * 4]
        alpha[y * width : (y + 1) * width] = row[3::4]
    return bytes(alpha)

