import AppKit
import Foundation

@MainActor
final class PetStateController {
    private let longPressDelay: TimeInterval = 0.220
    private(set) var pointerInsideVisibleSprite = false
    private(set) var isDragging = false
    private(set) var isPressed = false
    private var transientTimer: Timer?
    private var pressTimer: Timer?
    private var didLongPress = false
    var onStateChange: ((String) -> Void)?

    func updatePointerPresence(insideVisibleSprite: Bool) {
        pointerInsideVisibleSprite = insideVisibleSprite
        guard !isPressed, !isDragging, transientTimer == nil else {
            return
        }
        emit(insideVisibleSprite ? "waiting" : "idle")
    }

    func mouseDown() {
        stopTransient()
        cancelPressTimer()
        isDragging = false
        isPressed = true
        didLongPress = false
        let timer = Timer(timeInterval: longPressDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPressed, !self.isDragging else {
                    return
                }
                self.didLongPress = true
                self.emit("waving")
            }
        }
        pressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func mouseDragged(deltaX: CGFloat, deltaY: CGFloat) {
        stopTransient()
        cancelPressTimer()
        isDragging = true
        emit(dragState(deltaX: deltaX, deltaY: deltaY))
    }

    func mouseUp() {
        let shouldPlayClickReaction = isPressed && !isDragging && !didLongPress
        cancelPressTimer()
        isPressed = false
        isDragging = false
        didLongPress = false
        if shouldPlayClickReaction {
            playTransient("failed", duration: rowByState["failed"]?.totalDuration ?? 1.220)
        } else {
            emit(pointerInsideVisibleSprite ? "waiting" : "idle")
        }
    }

    private func dragState(deltaX: CGFloat, deltaY: CGFloat) -> String {
        if abs(deltaY) > abs(deltaX) {
            return deltaY >= 0 ? "jumping" : "review"
        }
        return deltaX >= 0 ? "running-right" : "running-left"
    }

    private func playTransient(_ state: String, duration: TimeInterval) {
        stopTransient()
        cancelPressTimer()
        emit(state)
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                transientTimer = nil
                guard !isDragging else {
                    return
                }
                emit(pointerInsideVisibleSprite ? "waiting" : "idle")
            }
        }
        transientTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTransient() {
        transientTimer?.invalidate()
        transientTimer = nil
    }

    private func cancelPressTimer() {
        pressTimer?.invalidate()
        pressTimer = nil
    }

    private func emit(_ state: String) {
        onStateChange?(state)
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func close() {
        orderOut(nil)
    }
}

@MainActor
protocol PetAnimationViewMenuDelegate: AnyObject {
    func availablePetChoices(for view: PetAnimationView) -> [PetChoice]
    func currentPetManifestURL(for view: PetAnimationView) -> URL
    func currentScale(for view: PetAnimationView) -> CGFloat
    func petViewResetPosition(_ view: PetAnimationView)
    func petView(_ view: PetAnimationView, setScale scale: CGFloat)
    func petView(_ view: PetAnimationView, selectPetAt manifestURL: URL)
    func petViewChoosePetFolder(_ view: PetAnimationView)
    func petViewWillOpenContextMenu(_ view: PetAnimationView)
    func petViewDidCloseContextMenu(_ view: PetAnimationView)
    func petViewQuit(_ view: PetAnimationView)
}

final class PetAnimationView: NSView {
    private var package: PetPackage
    private let stateController = PetStateController()
    private var activeRow: AnimationRow
    private var frameIndex = 0
    private var timer: Timer?
    private var dragStartMouse = NSPoint.zero
    private var dragStartOrigin = NSPoint.zero
    weak var menuDelegate: PetAnimationViewMenuDelegate?

    init(package: PetPackage, initialState: String) {
        self.package = package
        self.activeRow = rowByState[initialState] ?? animationRows[0]
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        stateController.onStateChange = { [weak self] state in
            self?.setState(state)
        }
        startTimer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    var isDragging: Bool {
        stateController.isDragging
    }

    func updatePackage(_ package: PetPackage) {
        self.package = package
        activeRow = rowByState["idle"] ?? animationRows[0]
        frameIndex = 0
        window?.title = package.manifest.displayName
        needsDisplay = true
        startTimer()
        stateController.updatePointerPresence(insideVisibleSprite: containsVisiblePixel(screenPoint: NSEvent.mouseLocation))
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        containsVisiblePixel(localPoint: point) ? super.hitTest(point) : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let frame = currentFrame()
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.interpolationQuality = package.manifest.usesSmoothRendering ? .high : .none
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(frame.image, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
    }

    func updatePointerPresence(insideVisibleSprite: Bool) {
        stateController.updatePointerPresence(insideVisibleSprite: insideVisibleSprite)
    }

    func containsVisiblePixel(screenPoint: NSPoint) -> Bool {
        guard let window else {
            return false
        }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let localPoint = convert(windowPoint, from: nil)
        return containsVisiblePixel(localPoint: localPoint)
    }

    private func containsVisiblePixel(localPoint: NSPoint) -> Bool {
        guard bounds.contains(localPoint), bounds.width > 0, bounds.height > 0 else {
            return false
        }

        let frame = currentFrame()
        let spriteX = Int((localPoint.x / bounds.width) * CGFloat(cellWidth))
        let spriteY = Int((localPoint.y / bounds.height) * CGFloat(cellHeight))
        return frame.hasVisiblePixel(x: spriteX, y: spriteY)
    }

    private func currentFrame() -> PetFrame {
        package.frames.frame(for: activeRow, index: frameIndex)
    }

    private func setState(_ state: String, resetFrame: Bool = true) {
        guard let row = rowByState[state] else {
            return
        }
        guard row.state != activeRow.state || resetFrame else {
            return
        }
        activeRow = row
        if resetFrame {
            frameIndex = 0
        } else {
            frameIndex = min(frameIndex, row.frameCount - 1)
        }
        needsDisplay = true
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        let delay = activeRow.durations.indices.contains(frameIndex) ? activeRow.durations[frameIndex] : 0.140
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceFrame()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func advanceFrame() {
        frameIndex = (frameIndex + 1) % activeRow.frameCount
        needsDisplay = true
        startTimer()
    }

    override func mouseDown(with event: NSEvent) {
        guard containsVisiblePixel(localPoint: convert(event.locationInWindow, from: nil)) else {
            return
        }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        stateController.mouseDown()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else {
            return
        }
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - dragStartMouse.x
        let deltaY = currentMouse.y - dragStartMouse.y
        let nextOrigin = NSPoint(x: dragStartOrigin.x + deltaX, y: dragStartOrigin.y + deltaY)
        window.setFrameOrigin(clampedWindowOrigin(nextOrigin, size: window.frame.size))

        if abs(deltaX) > 2 || abs(deltaY) > 2 {
            stateController.mouseDragged(deltaX: deltaX, deltaY: deltaY)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let inside = containsVisiblePixel(screenPoint: NSEvent.mouseLocation)
        stateController.updatePointerPresence(insideVisibleSprite: inside)
        stateController.mouseUp()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard containsVisiblePixel(localPoint: convert(event.locationInWindow, from: nil)) else {
            return
        }
        let menu = NSMenu()

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        let currentScale = menuDelegate?.currentScale(for: self) ?? 1
        for scale in availableScales {
            let item = NSMenuItem(title: "\(formatScale(scale))x", action: #selector(selectScale(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: Double(scale))
            item.state = abs(scale - currentScale) < 0.001 ? .on : .off
            sizeMenu.addItem(item)
        }
        menu.addItem(sizeItem)
        menu.setSubmenu(sizeMenu, for: sizeItem)

        let petItem = NSMenuItem(title: "Pet", action: nil, keyEquivalent: "")
        let petMenu = NSMenu()
        let currentPetURL = menuDelegate?.currentPetManifestURL(for: self)
        for choice in menuDelegate?.availablePetChoices(for: self) ?? [] {
            let item = NSMenuItem(title: choice.title, action: #selector(selectPet(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice.manifestURL as NSURL
            item.state = choice.manifestURL == currentPetURL ? .on : .off
            petMenu.addItem(item)
        }
        if petMenu.items.isEmpty {
            let empty = NSMenuItem(title: "No Pets Found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            petMenu.addItem(empty)
        } else {
            petMenu.addItem(.separator())
        }

        let chooseFolder = NSMenuItem(title: "Choose Pet Folder...", action: #selector(choosePetFolder), keyEquivalent: "")
        chooseFolder.target = self
        petMenu.addItem(chooseFolder)

        menu.addItem(petItem)
        menu.setSubmenu(petMenu, for: petItem)

        menu.addItem(.separator())

        let reset = NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit LightPet", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menuDelegate?.petViewWillOpenContextMenu(self)
        defer {
            menuDelegate?.petViewDidCloseContextMenu(self)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func selectScale(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else {
            return
        }
        let scale = CGFloat(number.doubleValue)
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            menuDelegate?.petView(self, setScale: scale)
        }
    }

    @objc private func selectPet(_ sender: NSMenuItem) {
        let selectedURL: URL?
        if let url = sender.representedObject as? URL {
            selectedURL = url
        } else if let url = sender.representedObject as? NSURL {
            selectedURL = url as URL
        } else {
            selectedURL = nil
        }

        guard let selectedURL else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            menuDelegate?.petView(self, selectPetAt: selectedURL)
        }
    }

    @objc private func choosePetFolder() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            menuDelegate?.petViewChoosePetFolder(self)
        }
    }

    @objc private func resetPosition() {
        menuDelegate?.petViewResetPosition(self)
    }

    @objc private func quit() {
        menuDelegate?.petViewQuit(self)
    }
}
