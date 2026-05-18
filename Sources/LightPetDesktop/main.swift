import AppKit
import CoreGraphics
import Darwin
import Foundation

private let cellWidth = 192
private let cellHeight = 208
private let atlasColumns = 8
private let atlasRows = 9
private let atlasWidth = cellWidth * atlasColumns
private let atlasHeight = cellHeight * atlasRows
private let visibleAlphaThreshold: UInt8 = 16
private let availableScales: [CGFloat] = [0.5, 0.75, 1, 1.25, 1.5]

private struct AnimationRow {
    let state: String
    let row: Int
    let frameCount: Int
    let durations: [TimeInterval]

    var totalDuration: TimeInterval {
        durations.reduce(0, +)
    }
}

private let animationRows: [AnimationRow] = [
    .init(state: "idle", row: 0, frameCount: 6, durations: [0.280, 0.110, 0.110, 0.140, 0.140, 0.320]),
    .init(state: "running-right", row: 1, frameCount: 8, durations: [0.120, 0.120, 0.120, 0.120, 0.120, 0.120, 0.120, 0.220]),
    .init(state: "running-left", row: 2, frameCount: 8, durations: [0.120, 0.120, 0.120, 0.120, 0.120, 0.120, 0.120, 0.220]),
    .init(state: "waving", row: 3, frameCount: 4, durations: [0.140, 0.140, 0.140, 0.280]),
    .init(state: "jumping", row: 4, frameCount: 5, durations: [0.140, 0.140, 0.140, 0.140, 0.280]),
    .init(state: "failed", row: 5, frameCount: 8, durations: [0.140, 0.140, 0.140, 0.140, 0.140, 0.140, 0.140, 0.240]),
    .init(state: "waiting", row: 6, frameCount: 6, durations: [0.150, 0.150, 0.150, 0.150, 0.150, 0.260]),
    .init(state: "running", row: 7, frameCount: 6, durations: [0.120, 0.120, 0.120, 0.120, 0.120, 0.220]),
    .init(state: "review", row: 8, frameCount: 6, durations: [0.150, 0.150, 0.150, 0.150, 0.150, 0.280]),
]

private let rowByState = Dictionary(uniqueKeysWithValues: animationRows.map { ($0.state, $0) })

private struct PetManifest: Decodable {
    let id: String
    let displayName: String
    let description: String
    let spritesheetPath: String
}

private struct PetFrame {
    let image: CGImage
    let alpha: [UInt8]

    func hasVisiblePixel(x: Int, y: Int) -> Bool {
        guard x >= 0, x < cellWidth, y >= 0, y < cellHeight else {
            return false
        }
        return alpha[y * cellWidth + x] > visibleAlphaThreshold
    }
}

private final class PetFrameStore {
    private let framesByState: [String: [PetFrame]]

    init(atlas: CGImage) throws {
        var builtFrames: [String: [PetFrame]] = [:]

        for row in animationRows {
            var frames: [PetFrame] = []
            for column in 0..<row.frameCount {
                let frame = try Self.makeFrame(atlas: atlas, row: row.row, column: column)
                let nontransparentPixels = frame.alpha.filter { $0 > visibleAlphaThreshold }.count
                guard nontransparentPixels > 50 else {
                    throw RuntimeError("\(row.state) column \(column) is empty or too sparse.")
                }
                frames.append(frame)
            }

            for column in row.frameCount..<atlasColumns {
                let frame = try Self.makeFrame(atlas: atlas, row: row.row, column: column)
                let nontransparentPixels = frame.alpha.filter { $0 > visibleAlphaThreshold }.count
                guard nontransparentPixels == 0 else {
                    throw RuntimeError("\(row.state) unused column \(column) is not transparent.")
                }
            }

            builtFrames[row.state] = frames
        }

        framesByState = builtFrames
    }

    func frame(for row: AnimationRow, index: Int) -> PetFrame {
        guard let frames = framesByState[row.state], !frames.isEmpty else {
            fatalError("Missing frames for \(row.state).")
        }
        return frames[index % frames.count]
    }

    private static func makeFrame(atlas: CGImage, row: Int, column: Int) throws -> PetFrame {
        let sourceRect = CGRect(
            x: column * cellWidth,
            y: row * cellHeight,
            width: cellWidth,
            height: cellHeight
        )
        guard let image = atlas.cropping(to: sourceRect) else {
            throw RuntimeError("Could not crop row \(row), column \(column).")
        }
        return PetFrame(image: image, alpha: try alphaMap(for: image))
    }

    private static func alphaMap(for image: CGImage) throws -> [UInt8] {
        let bytesPerPixel = 4
        let bytesPerRow = cellWidth * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: cellWidth * cellHeight * bytesPerPixel)

        try pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                throw RuntimeError("Could not allocate frame alpha buffer.")
            }
            guard let context = CGContext(
                data: baseAddress,
                width: cellWidth,
                height: cellHeight,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                throw RuntimeError("Could not create frame alpha context.")
            }
            context.clear(CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight))
            context.draw(image, in: CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight))
        }

        var alpha = [UInt8](repeating: 0, count: cellWidth * cellHeight)
        for index in 0..<alpha.count {
            alpha[index] = pixels[index * bytesPerPixel + 3]
        }
        return alpha
    }
}

private struct PetPackage {
    let manifest: PetManifest
    let manifestURL: URL
    let spritesheetURL: URL
    let frames: PetFrameStore
}

private struct PetChoice {
    let manifest: PetManifest
    let manifestURL: URL

    var title: String {
        manifest.displayName.isEmpty ? manifest.id : manifest.displayName
    }
}

private struct LaunchOptions {
    var manifestPath: String?
    var petID = "conan"
    var initialState = "idle"
    var scale: CGFloat = 1
    var showDock = false
    var runResizeSmokeTest = false

    static func parse(arguments: [String]) throws -> LaunchOptions {
        var options = LaunchOptions()
        var index = 1

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--pet":
                index += 1
                guard index < arguments.count else { throw LaunchError.missingValue("--pet") }
                options.manifestPath = arguments[index]
            case "--pet-id":
                index += 1
                guard index < arguments.count else { throw LaunchError.missingValue("--pet-id") }
                options.petID = arguments[index]
            case "--state":
                index += 1
                guard index < arguments.count else { throw LaunchError.missingValue("--state") }
                options.initialState = arguments[index]
            case "--scale":
                index += 1
                guard index < arguments.count else { throw LaunchError.missingValue("--scale") }
                guard let value = Double(arguments[index]), value > 0 else {
                    throw LaunchError.invalidValue("--scale", arguments[index])
                }
                let scale = CGFloat(value)
                guard isAvailableScale(scale) else {
                    throw LaunchError.invalidValue("--scale", arguments[index])
                }
                options.scale = scale
            case "--show-dock":
                options.showDock = true
            case "--resize-smoke-test":
                options.runResizeSmokeTest = true
            case "--help", "-h":
                throw LaunchError.helpRequested
            default:
                throw LaunchError.unknownArgument(argument)
            }
            index += 1
        }

        if rowByState[options.initialState] == nil {
            throw LaunchError.invalidValue("--state", options.initialState)
        }
        return options
    }
}

private enum LaunchError: Error, CustomStringConvertible {
    case helpRequested
    case missingValue(String)
    case invalidValue(String, String)
    case unknownArgument(String)

    var description: String {
        switch self {
        case .helpRequested:
            return helpText
        case let .missingValue(flag):
            return "\(flag) needs a value.\n\n\(helpText)"
        case let .invalidValue(flag, value):
            return "\(flag) has invalid value: \(value)\n\n\(helpText)"
        case let .unknownArgument(argument):
            return "Unknown argument: \(argument)\n\n\(helpText)"
        }
    }
}

private let helpText = """
Usage:
  swift run LightPetDesktop [--pet path/to/pet.json] [--pet-id conan] [--state idle] [--scale 1] [--show-dock]

Pet lookup:
  --pet exact manifest path wins.
  Without --pet, LightPet tries sample-pets/<pet-id>/pet.json, then ${CODEX_HOME:-~/.codex}/pets/<pet-id>/pet.json.

Mouse:
  hover visible sprite  waiting
  left press            waving
  left drag             move pet window and switch running-left/running-right
  double click          jumping
  right click           size, pet, reset-position, and quit menu

Sizes:
  0.5x, 0.75x, 1x, 1.25x, 1.5x
"""

private func loadPetPackage(options: LaunchOptions) throws -> PetPackage {
    let manifestURL = try resolveManifestURL(options: options)
    return try loadPetPackage(manifestURL: manifestURL)
}

private func loadPetPackage(directoryURL: URL) throws -> PetPackage {
    let manifestURL = directoryURL.appendingPathComponent("pet.json").standardizedFileURL
    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
        throw RuntimeError("Selected folder must contain pet.json.")
    }
    let spritesheetURL = directoryURL.appendingPathComponent("spritesheet.webp").standardizedFileURL
    guard FileManager.default.fileExists(atPath: spritesheetURL.path) else {
        throw RuntimeError("Selected folder must contain spritesheet.webp.")
    }
    let manifest = try loadPetManifest(manifestURL: manifestURL)
    guard manifest.spritesheetPath == "spritesheet.webp" else {
        throw RuntimeError("pet.json must set spritesheetPath to spritesheet.webp.")
    }
    return try loadPetPackage(manifestURL: manifestURL)
}

private func loadPetPackage(manifestURL: URL) throws -> PetPackage {
    let manifest = try loadPetManifest(manifestURL: manifestURL)
    let spritesheetURL = resolveSpritesheetURL(manifest: manifest, manifestURL: manifestURL)

    guard let image = NSImage(contentsOf: spritesheetURL) else {
        throw RuntimeError("Could not load spritesheet at \(spritesheetURL.path).")
    }
    var proposedRect = NSRect(origin: .zero, size: image.size)
    guard let atlas = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
        throw RuntimeError("Could not decode spritesheet as CGImage at \(spritesheetURL.path).")
    }
    guard atlas.width == atlasWidth, atlas.height == atlasHeight else {
        throw RuntimeError("Expected \(atlasWidth)x\(atlasHeight) spritesheet, got \(atlas.width)x\(atlas.height).")
    }

    return PetPackage(
        manifest: manifest,
        manifestURL: manifestURL,
        spritesheetURL: spritesheetURL,
        frames: try PetFrameStore(atlas: atlas)
    )
}

private func loadPetManifest(manifestURL: URL) throws -> PetManifest {
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(PetManifest.self, from: data)
}

private func discoverPetChoices() -> [PetChoice] {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? "~/.codex"
    let roots = [
        Bundle.main.resourceURL?.appendingPathComponent("Pets"),
        cwd.appendingPathComponent("sample-pets").standardizedFileURL,
        fileURL(from: "\(codexHome)/pets"),
    ].compactMap { $0 }

    var seenPaths = Set<String>()
    var choices: [PetChoice] = []

    for manifestURL in roots.flatMap(petManifestURLs) {
        guard !seenPaths.contains(manifestURL.path) else {
            continue
        }
        seenPaths.insert(manifestURL.path)
        guard let choice = petChoice(manifestURL: manifestURL) else {
            continue
        }
        choices.append(choice)
    }

    return choices.sorted {
        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
    }
}

private func petChoice(manifestURL: URL) -> PetChoice? {
    guard
        let manifest = try? loadPetManifest(manifestURL: manifestURL),
        manifest.spritesheetPath == "spritesheet.webp"
    else {
        return nil
    }

    guard (try? loadPetPackage(manifestURL: manifestURL)) != nil else {
        return nil
    }
    return PetChoice(manifest: manifest, manifestURL: manifestURL)
}

private func petManifestURLs(in root: URL) -> [URL] {
    guard
        let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
    else {
        return []
    }

    return entries.compactMap { entry in
        let manifestURL = entry.appendingPathComponent("pet.json").standardizedFileURL
        return FileManager.default.fileExists(atPath: manifestURL.path) ? manifestURL : nil
    }
}

private func resolveManifestURL(options: LaunchOptions) throws -> URL {
    if let manifestPath = options.manifestPath {
        let manifestURL = fileURL(from: manifestPath)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw RuntimeError("Pet manifest does not exist at \(manifestURL.path).")
        }
        return manifestURL
    }

    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? "~/.codex"
    let candidates = [
        Bundle.main.url(forResource: "pet", withExtension: "json", subdirectory: "Pets/\(options.petID)"),
        cwd.appendingPathComponent("sample-pets/\(options.petID)/pet.json").standardizedFileURL,
        fileURL(from: "\(codexHome)/pets/\(options.petID)/pet.json"),
    ].compactMap { $0 }

    for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
    }

    throw RuntimeError("Could not find pet '\(options.petID)'. Pass --pet path/to/pet.json.")
}

private func resolveSpritesheetURL(manifest: PetManifest, manifestURL: URL) -> URL {
    if manifest.spritesheetPath.hasPrefix("/") {
        return URL(fileURLWithPath: manifest.spritesheetPath).standardizedFileURL
    }
    return manifestURL.deletingLastPathComponent().appendingPathComponent(manifest.spritesheetPath).standardizedFileURL
}

private func fileURL(from path: String) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }
    return URL(
        fileURLWithPath: expanded,
        relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ).standardizedFileURL
}

private struct RuntimeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

@MainActor
private final class PetStateController {
    private(set) var pointerInsideVisibleSprite = false
    private(set) var isDragging = false
    private var transientTimer: Timer?
    var onStateChange: ((String) -> Void)?

    func updatePointerPresence(insideVisibleSprite: Bool) {
        pointerInsideVisibleSprite = insideVisibleSprite
        guard !isDragging, transientTimer == nil else {
            return
        }
        emit(insideVisibleSprite ? "waiting" : "idle")
    }

    func mouseDown() {
        stopTransient()
        isDragging = false
        emit("waving")
    }

    func mouseDragged(deltaX: CGFloat) {
        stopTransient()
        isDragging = true
        emit(deltaX >= 0 ? "running-right" : "running-left")
    }

    func mouseUp() {
        isDragging = false
        emit(pointerInsideVisibleSprite ? "waiting" : "idle")
    }

    func doubleClick() {
        playTransient("jumping", duration: rowByState["jumping"]?.totalDuration ?? 0.840)
    }

    private func playTransient(_ state: String, duration: TimeInterval) {
        stopTransient()
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

    private func emit(_ state: String) {
        onStateChange?(state)
    }
}

private final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func close() {
        orderOut(nil)
    }
}

@MainActor
private protocol PetAnimationViewMenuDelegate: AnyObject {
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

private final class PetAnimationView: NSView {
    private var package: PetPackage
    private let stateController = PetStateController()
    private var activeRow: AnimationRow
    private var frameIndex = 0
    private var timer: Timer?
    private var dragStartMouse = NSPoint.zero
    private var dragStartOrigin = NSPoint.zero
    private var didStartDrag = false
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

        context.interpolationQuality = .none
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
        if event.clickCount >= 2 {
            stateController.doubleClick()
            return
        }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        didStartDrag = false
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
            didStartDrag = true
            stateController.mouseDragged(deltaX: deltaX)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let inside = containsVisiblePixel(screenPoint: NSEvent.mouseLocation)
        stateController.updatePointerPresence(insideVisibleSprite: inside)
        stateController.mouseUp()
        didStartDrag = false
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

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let options: LaunchOptions
    private var currentPackage: PetPackage
    private var currentScale: CGFloat
    private var panel: PetPanel?
    private weak var petView: PetAnimationView?
    private var pointerTimer: Timer?
    private var isContextMenuOpen = false

    init(options: LaunchOptions, package: PetPackage) {
        self.options = options
        self.currentPackage = package
        self.currentScale = options.scale
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: CGFloat(cellWidth) * currentScale, height: CGFloat(cellHeight) * currentScale)
        let panel = PetPanel(
            contentRect: NSRect(origin: defaultWindowOrigin(size: size), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let petView = PetAnimationView(package: currentPackage, initialState: options.initialState)
        petView.menuDelegate = self
        panel.title = currentPackage.manifest.displayName
        panel.contentView = petView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        self.panel = panel
        self.petView = petView

        startPointerRoutingTimer(panel: panel, petView: petView)

        print("LightPetDesktop loaded \(currentPackage.manifest.displayName) from \(currentPackage.manifestURL.path)")
        print("Mouse-only states: hover=waiting, press=waving, drag=running-left/right, double-click=jumping.")

        if options.runResizeSmokeTest {
            runResizeSmokeTest(view: petView)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pointerTimer?.invalidate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startPointerRoutingTimer(panel: PetPanel, petView: PetAnimationView) {
        let timer = Timer(timeInterval: 0.050, repeats: true) { [weak panel, weak petView] _ in
            Task { @MainActor [weak panel, weak petView] in
                guard let panel, let petView else {
                    return
                }
                guard !self.isContextMenuOpen else {
                    panel.ignoresMouseEvents = false
                    return
                }
                let insideVisibleSprite = petView.containsVisiblePixel(screenPoint: NSEvent.mouseLocation)
                panel.ignoresMouseEvents = false
                petView.updatePointerPresence(insideVisibleSprite: insideVisibleSprite)
            }
        }
        pointerTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func runResizeSmokeTest(view: PetAnimationView) {
        let scales = availableScales
        for (index, scale) in scales.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(index + 1)) { [weak self, weak view] in
                guard let self, let view else {
                    print("Resize smoke test failed: app objects were released.")
                    exit(1)
                }
                self.petView(view, setScale: scale)
                guard let panel = self.panel else {
                    print("Resize smoke test failed: panel is missing.")
                    exit(1)
                }
                let expected = NSSize(width: CGFloat(cellWidth) * scale, height: CGFloat(cellHeight) * scale)
                let actual = panel.frame.size
                guard abs(actual.width - expected.width) < 0.5, abs(actual.height - expected.height) < 0.5 else {
                    print("Resize smoke test failed: expected \(expected), got \(actual).")
                    exit(1)
                }
                print("Resize smoke test scale \(formatScale(scale))x ok: \(Int(actual.width))x\(Int(actual.height))")
                if index == scales.count - 1 {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

extension AppDelegate: PetAnimationViewMenuDelegate {
    func availablePetChoices(for view: PetAnimationView) -> [PetChoice] {
        var choices = discoverPetChoices()
        if !choices.contains(where: { $0.manifestURL == currentPackage.manifestURL }) {
            choices.append(PetChoice(manifest: currentPackage.manifest, manifestURL: currentPackage.manifestURL))
        }
        return choices.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func currentPetManifestURL(for view: PetAnimationView) -> URL {
        currentPackage.manifestURL
    }

    func currentScale(for view: PetAnimationView) -> CGFloat {
        currentScale
    }

    func petViewResetPosition(_ view: PetAnimationView) {
        guard let panel else {
            return
        }
        panel.setFrameOrigin(defaultWindowOrigin(size: panel.frame.size))
    }

    func petView(_ view: PetAnimationView, setScale scale: CGFloat) {
        guard let panel else {
            return
        }
        currentScale = scale
        let oldFrame = panel.frame
        let oldCenter = NSPoint(x: oldFrame.midX, y: oldFrame.midY)
        let newSize = NSSize(width: CGFloat(cellWidth) * scale, height: CGFloat(cellHeight) * scale)
        let proposedOrigin = NSPoint(x: oldCenter.x - newSize.width / 2, y: oldCenter.y - newSize.height / 2)
        panel.setFrame(NSRect(origin: clampedWindowOrigin(proposedOrigin, size: newSize), size: newSize), display: true)
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
    }

    func petView(_ view: PetAnimationView, selectPetAt manifestURL: URL) {
        do {
            let package = try loadPetPackage(manifestURL: manifestURL)
            switchPet(to: package, view: view)
        } catch {
            showSwitchPetError(error)
        }
    }

    func petViewChoosePetFolder(_ view: PetAnimationView) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Pet Folder"
        openPanel.message = "Select a folder containing pet.json and spritesheet.webp."
        openPanel.prompt = "Choose"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = false
        openPanel.directoryURL = currentPackage.manifestURL.deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        guard openPanel.runModal() == .OK, let directoryURL = openPanel.url else {
            return
        }

        do {
            let package = try loadPetPackage(directoryURL: directoryURL)
            switchPet(to: package, view: view)
        } catch {
            showSwitchPetError(error)
        }
    }

    private func switchPet(to package: PetPackage, view: PetAnimationView) {
        currentPackage = package
        panel?.title = package.manifest.displayName
        view.updatePackage(package)
        print("LightPetDesktop switched to \(package.manifest.displayName) from \(package.manifestURL.path)")
    }

    func petViewWillOpenContextMenu(_ view: PetAnimationView) {
        isContextMenuOpen = true
        panel?.ignoresMouseEvents = false
    }

    func petViewDidCloseContextMenu(_ view: PetAnimationView) {
        isContextMenuOpen = false
        guard let panel, let petView else {
            return
        }
        let insideVisibleSprite = petView.containsVisiblePixel(screenPoint: NSEvent.mouseLocation)
        panel.ignoresMouseEvents = false
        petView.updatePointerPresence(insideVisibleSprite: insideVisibleSprite)
    }

    func petViewQuit(_ view: PetAnimationView) {
        NSApp.terminate(nil)
    }

    @MainActor
    private func showSwitchPetError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could Not Load Pet"
        alert.informativeText = "\(error)"
        alert.alertStyle = .warning
        alert.runModal()
    }
}

private func formatScale(_ scale: CGFloat) -> String {
    let value = Double(scale)
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(format: "%.2f", value).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
}

private func isAvailableScale(_ scale: CGFloat) -> Bool {
    availableScales.contains { abs($0 - scale) < 0.001 }
}

private func defaultWindowOrigin(size: NSSize) -> NSPoint {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    return clampedWindowOrigin(
        NSPoint(x: screenFrame.maxX - size.width - 80, y: screenFrame.minY + 80),
        size: size
    )
}

private func clampedWindowOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
    let visibleFrame = visibleScreenUnion()
    let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
    let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
    return NSPoint(
        x: min(max(origin.x, visibleFrame.minX), maxX),
        y: min(max(origin.y, visibleFrame.minY), maxY)
    )
}

private func visibleScreenUnion() -> NSRect {
    let screens = NSScreen.screens
    guard var union = screens.first?.visibleFrame else {
        return NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
    for screen in screens.dropFirst() {
        union = union.union(screen.visibleFrame)
    }
    return union
}

private var strongAppDelegate: AppDelegate?

do {
    let options = try LaunchOptions.parse(arguments: CommandLine.arguments)
    let package = try loadPetPackage(options: options)
    let app = NSApplication.shared
    let delegate = AppDelegate(options: options, package: package)
    strongAppDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(options.showDock ? .regular : .accessory)
    app.run()
} catch let error as LaunchError {
    print(error.description)
    if case .helpRequested = error {
        exit(0)
    }
    exit(2)
} catch {
    fputs("LightPetDesktop error: \(error)\n", stderr)
    exit(1)
}
