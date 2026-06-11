from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject, QPoint, QSize, Qt, QTimer, Signal
from PySide6.QtGui import QAction, QBitmap, QCursor, QGuiApplication, QPainter, QPen
from PySide6.QtWidgets import QApplication, QFileDialog, QMenu, QMessageBox, QWidget

from .contract import AVAILABLE_SCALES, AnimationContract, AnimationRow, format_scale
from .package_loader import (
    PetPackage,
    PetRuntimeError,
    discover_pet_choices,
    load_pet_package,
    load_pet_package_from_directory,
    remember_codex_pet,
)


class PetStateController(QObject):
    state_changed = Signal(str, bool)

    def __init__(self, contract: AnimationContract, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._contract = contract
        self.pointer_inside_visible_sprite = False
        self.is_dragging = False
        self.is_pressed = False
        self._did_long_press = False
        self._current_state: str | None = None

        self._press_timer = QTimer(self)
        self._press_timer.setSingleShot(True)
        self._press_timer.timeout.connect(self._long_press_timeout)

        self._transient_timer = QTimer(self)
        self._transient_timer.setSingleShot(True)
        self._transient_timer.timeout.connect(self._transient_timeout)

    def reset_current_state(self, state: str) -> None:
        self._current_state = state

    def update_pointer_presence(self, inside_visible_sprite: bool) -> None:
        self.pointer_inside_visible_sprite = inside_visible_sprite
        if self.is_pressed or self.is_dragging or self._transient_timer.isActive():
            return
        self._emit("waiting" if inside_visible_sprite else "idle")

    def mouse_down(self) -> None:
        self._transient_timer.stop()
        self._press_timer.stop()
        self.is_dragging = False
        self.is_pressed = True
        self._did_long_press = False
        self._press_timer.start(220)

    def mouse_dragged(self, delta_x: float, delta_y: float) -> None:
        self._transient_timer.stop()
        self._press_timer.stop()
        self.is_dragging = True
        self._emit(self._drag_state(delta_x, delta_y))

    def mouse_up(self) -> None:
        should_play_click_reaction = self.is_pressed and not self.is_dragging and not self._did_long_press
        self._press_timer.stop()
        self.is_pressed = False
        self.is_dragging = False
        self._did_long_press = False

        if should_play_click_reaction:
            row = self._contract.row_by_state.get("failed")
            self._play_transient("failed", row.total_duration_ms if row else 1220)
        else:
            self._emit("waiting" if self.pointer_inside_visible_sprite else "idle")

    def _long_press_timeout(self) -> None:
        if self.is_pressed and not self.is_dragging:
            self._did_long_press = True
            self._emit("waving")

    def _transient_timeout(self) -> None:
        if not self.is_dragging:
            self._emit("waiting" if self.pointer_inside_visible_sprite else "idle")

    def _drag_state(self, delta_x: float, delta_y: float) -> str:
        if abs(delta_y) > abs(delta_x):
            return "jumping" if delta_y < 0 else "review"
        return "running-right" if delta_x >= 0 else "running-left"

    def _play_transient(self, state: str, duration_ms: int) -> None:
        self._emit(state, replay=True)
        self._transient_timer.start(max(1, duration_ms))

    def _emit(self, state: str, replay: bool = False) -> None:
        if not replay and self._current_state == state:
            return
        self._current_state = state
        self.state_changed.emit(state, replay)


class PetWindow(QWidget):
    def __init__(
        self,
        package: PetPackage,
        contract: AnimationContract,
        settings,
        initial_state: str,
        scale: float,
        show_dock: bool,
    ) -> None:
        flags = Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        if not show_dock:
            flags |= Qt.WindowType.Tool
        super().__init__(None, flags)

        self._package = package
        self._contract = contract
        self._settings = settings
        self._scale = scale
        self._row_by_state = contract.row_by_state
        self._active_row = self._row_by_state.get(initial_state, contract.rows[0])
        self._frame_index = 0
        self._drag_start_global = QPoint()
        self._drag_start_window = QPoint()

        self._frame_timer = QTimer(self)
        self._frame_timer.setSingleShot(True)
        self._frame_timer.timeout.connect(self._advance_frame)

        self._pointer_timer = QTimer(self)
        self._pointer_timer.timeout.connect(self._route_pointer_presence)

        self._state_controller = PetStateController(contract, self)
        self._state_controller.reset_current_state(self._active_row.state)
        self._state_controller.state_changed.connect(self._set_state)

        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_NoSystemBackground, True)
        self.setMouseTracking(True)
        self.setWindowTitle(package.manifest.display_name)
        self.set_scale(scale, keep_center=False)
        self.move(_default_window_position(self.size()))

        self._start_timer()
        self._pointer_timer.start(50)

    def current_package(self) -> PetPackage:
        return self._package

    def current_scale(self) -> float:
        return self._scale

    def set_scale(self, scale: float, keep_center: bool = True) -> None:
        if scale not in AVAILABLE_SCALES:
            return
        old_center = self.frameGeometry().center()
        geometry = self._contract.atlas
        self._scale = scale
        self.resize(QSize(round(geometry.cell_width * scale), round(geometry.cell_height * scale)))
        if keep_center:
            next_position = QPoint(
                old_center.x() - self.width() // 2,
                old_center.y() - self.height() // 2,
            )
            self.move(_clamped_window_position(next_position, self.size()))
        self._apply_window_mask()
        self.update()

    def reset_position(self) -> None:
        self.move(_default_window_position(self.size()))

    def switch_pet(self, package: PetPackage) -> None:
        self._package = package
        remember_codex_pet(package, self._settings)
        self.setWindowTitle(package.manifest.display_name)
        self._active_row = self._row_by_state["idle"]
        self._frame_index = 0
        self._state_controller.reset_current_state(self._active_row.state)
        self._apply_window_mask()
        self._start_timer()
        self.update()
        self._route_pointer_presence()
        print(f"LightPetQt switched to {package.manifest.display_name} from {package.manifest_path}")

    def run_resize_smoke_test(self) -> None:
        scales = list(AVAILABLE_SCALES)

        def run_step(index: int) -> None:
            if index >= len(scales):
                QApplication.exit(0)
                return
            scale = scales[index]
            self.set_scale(scale)
            expected = QSize(
                round(self._contract.atlas.cell_width * scale),
                round(self._contract.atlas.cell_height * scale),
            )
            actual = self.size()
            if abs(actual.width() - expected.width()) > 1 or abs(actual.height() - expected.height()) > 1:
                print(f"Resize smoke test failed: expected {expected}, got {actual}.")
                QApplication.exit(1)
                return
            print(f"Resize smoke test scale {format_scale(scale)}x ok: {actual.width()}x{actual.height()}")
            QTimer.singleShot(250, lambda: run_step(index + 1))

        QTimer.singleShot(250, lambda: run_step(0))

    def paintEvent(self, event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_Source)
        painter.fillRect(self.rect(), Qt.GlobalColor.transparent)
        painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_SourceOver)
        if self._package.manifest.uses_smooth_rendering:
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        else:
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, False)

        painter.setPen(QPen(Qt.PenStyle.NoPen))
        painter.drawImage(self.rect(), self._current_frame().image)

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            if not self._contains_visible_pixel(event.position().toPoint()):
                event.ignore()
                return
            self._drag_start_global = event.globalPosition().toPoint()
            self._drag_start_window = self.pos()
            self._state_controller.mouse_down()
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        if event.buttons() & Qt.MouseButton.LeftButton and self._state_controller.is_pressed:
            current_global = event.globalPosition().toPoint()
            delta = current_global - self._drag_start_global
            self.move(_clamped_window_position(self._drag_start_window + delta, self.size()))
            if abs(delta.x()) > 2 or abs(delta.y()) > 2:
                self._state_controller.mouse_dragged(delta.x(), delta.y())
            event.accept()
            return

        self._route_pointer_presence()
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton and self._state_controller.is_pressed:
            self._state_controller.update_pointer_presence(self._contains_global_visible_pixel(QCursor.pos()))
            self._state_controller.mouse_up()
            event.accept()
            return
        super().mouseReleaseEvent(event)

    def leaveEvent(self, event) -> None:  # noqa: N802
        self._state_controller.update_pointer_presence(False)
        super().leaveEvent(event)

    def contextMenuEvent(self, event) -> None:  # noqa: N802
        if not self._contains_visible_pixel(event.pos()):
            event.ignore()
            return

        menu = QMenu(self)

        size_menu = menu.addMenu("Size")
        for scale in AVAILABLE_SCALES:
            action = QAction(f"{format_scale(scale)}x", size_menu)
            action.setCheckable(True)
            action.setChecked(abs(scale - self._scale) < 0.001)
            action.triggered.connect(lambda _checked=False, value=scale: self.set_scale(value))
            size_menu.addAction(action)

        pet_menu = menu.addMenu("Pet")
        choices = discover_pet_choices()
        if all(choice.manifest_path != self._package.manifest_path for choice in choices):
            from .package_loader import PetChoice

            choices.append(PetChoice(self._package.manifest, self._package.manifest_path))
            choices.sort(key=lambda choice: choice.title.casefold())

        if not choices:
            empty_action = QAction("No Pets Found", pet_menu)
            empty_action.setEnabled(False)
            pet_menu.addAction(empty_action)
        else:
            for choice in choices:
                action = QAction(choice.title, pet_menu)
                action.setCheckable(True)
                action.setChecked(choice.manifest_path == self._package.manifest_path)
                action.triggered.connect(
                    lambda _checked=False, path=choice.manifest_path: self._select_pet(path)
                )
                pet_menu.addAction(action)
            pet_menu.addSeparator()

        choose_action = QAction("Choose Pet Folder...", pet_menu)
        choose_action.triggered.connect(self._choose_pet_folder)
        pet_menu.addAction(choose_action)

        menu.addSeparator()
        reset_action = QAction("Reset Position", menu)
        reset_action.triggered.connect(self.reset_position)
        menu.addAction(reset_action)

        menu.addSeparator()
        quit_action = QAction("Quit LightPet", menu)
        quit_action.triggered.connect(QApplication.quit)
        menu.addAction(quit_action)

        menu.exec(event.globalPos())
        self._route_pointer_presence()

    def _select_pet(self, manifest_path: Path) -> None:
        try:
            self.switch_pet(load_pet_package(manifest_path, self._contract))
        except PetRuntimeError as exc:
            QMessageBox.warning(self, "Could Not Load Pet", str(exc))

    def _choose_pet_folder(self) -> None:
        directory = QFileDialog.getExistingDirectory(
            self,
            "Choose Pet Folder",
            str(self._package.manifest_path.parent),
            QFileDialog.Option.ShowDirsOnly,
        )
        if not directory:
            return
        try:
            self.switch_pet(load_pet_package_from_directory(directory, self._contract))
        except PetRuntimeError as exc:
            QMessageBox.warning(self, "Could Not Load Pet", str(exc))

    def _set_state(self, state: str, replay: bool = False) -> None:
        row = self._row_by_state.get(state)
        if row is None:
            return
        if row.state == self._active_row.state and not replay:
            return
        self._active_row = row
        self._frame_index = 0
        self._apply_window_mask()
        self._start_timer()
        self.update()

    def _advance_frame(self) -> None:
        self._frame_index = (self._frame_index + 1) % self._active_row.frame_count
        self._apply_window_mask()
        self.update()
        self._start_timer()

    def _start_timer(self) -> None:
        self._frame_timer.stop()
        delay = self._active_row.durations_ms[self._frame_index]
        self._frame_timer.start(max(1, delay))

    def _current_frame(self):
        return self._package.frames.frame(self._active_row, self._frame_index)

    def _contains_visible_pixel(self, local_point: QPoint) -> bool:
        if not self.rect().contains(local_point):
            return False
        frame = self._current_frame()
        sprite_x = int((local_point.x() / max(1, self.width())) * frame.cell_width)
        sprite_y = int((local_point.y() / max(1, self.height())) * frame.cell_height)
        return frame.has_visible_pixel(sprite_x, sprite_y)

    def _contains_global_visible_pixel(self, global_point: QPoint) -> bool:
        return self._contains_visible_pixel(self.mapFromGlobal(global_point))

    def _route_pointer_presence(self) -> None:
        self._state_controller.update_pointer_presence(self._contains_global_visible_pixel(QCursor.pos()))

    def _apply_window_mask(self) -> None:
        mask_image = self._current_frame().image.createAlphaMask()
        if mask_image.size() != self.size():
            mask_image = mask_image.scaled(
                self.size(),
                Qt.AspectRatioMode.IgnoreAspectRatio,
                Qt.TransformationMode.FastTransformation,
            )
        self.setMask(QBitmap.fromImage(mask_image))


def _default_window_position(size: QSize) -> QPoint:
    screen = QGuiApplication.primaryScreen()
    available = screen.availableGeometry() if screen else None
    if available is None:
        return QPoint(80, 80)
    return _clamped_window_position(
        QPoint(
            available.x() + available.width() - size.width() - 96,
            available.y() + available.height() - size.height() - 96,
        ),
        size,
    )


def _clamped_window_position(position: QPoint, size: QSize) -> QPoint:
    center = QPoint(position.x() + size.width() // 2, position.y() + size.height() // 2)
    screen = QGuiApplication.screenAt(center) or QGuiApplication.primaryScreen()
    if screen is None:
        return position
    available = screen.availableGeometry()
    max_x = available.x() + max(0, available.width() - size.width())
    max_y = available.y() + max(0, available.height() - size.height())
    return QPoint(
        min(max(position.x(), available.x()), max_x),
        min(max(position.y(), available.y()), max_y),
    )

