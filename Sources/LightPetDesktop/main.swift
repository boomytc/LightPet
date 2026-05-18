import AppKit
import CoreGraphics
import Foundation

private let cellWidth = 192
private let cellHeight = 208
private let atlasColumns = 8
private let atlasRows = 9
private let atlasWidth = cellWidth * atlasColumns
private let atlasHeight = cellHeight * atlasRows

private struct AnimationRow {
    let state: String
    let row: Int
    let frameCount: Int
    let durations: [TimeInterval]
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

private struct PetPackage {
    let manifest: PetManifest
    let manifestURL: URL
    let spritesheetURL: URL
    let atlas: CGImage
}

private struct LaunchOptions {
    var manifestPath = "sample-pets/conan/pet.json"
    var initialState = "idle"
    var scale: CGFloat = 2
    var showDock = false

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
                options.scale = CGFloat(value)
            case "--show-dock":
                options.showDock = true
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
  swift run LightPetDesktop [--pet path/to/pet.json] [--state idle] [--scale 2] [--show-dock]

Mouse:
  left drag     move pet window, switching running-left/running-right while dragging
  double click  cycle animation state
  right click   open state and quit menu
"""

private func loadPetPackage(from manifestPath: String) throws -> PetPackage {
    let manifestURL = URL(fileURLWithPath: manifestPath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        .standardizedFileURL
    let data = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(PetManifest.self, from: data)
    let spritesheetURL: URL
    if manifest.spritesheetPath.hasPrefix("/") {
        spritesheetURL = URL(fileURLWithPath: manifest.spritesheetPath).standardizedFileURL
    } else {
        spritesheetURL = manifestURL.deletingLastPathComponent().appendingPathComponent(manifest.spritesheetPath).standardizedFileURL
    }

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
    return PetPackage(manifest: manifest, manifestURL: manifestURL, spritesheetURL: spritesheetURL, atlas: atlas)
}

private struct RuntimeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class PetAnimationView: NSView {
    private let package: PetPackage
    private var activeRow: AnimationRow
    private var frameIndex = 0
    private var timer: Timer?
    private var dragStartMouse = NSPoint.zero
    private var dragStartOrigin = NSPoint.zero
    private var lastDragState: String?

    init(package: PetPackage, initialState: String) {
        self.package = package
        self.activeRow = rowByState[initialState] ?? animationRows[0]
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        startTimer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let sourceRect = CGRect(
            x: frameIndex * cellWidth,
            y: activeRow.row * cellHeight,
            width: cellWidth,
            height: cellHeight
        )

        guard let frame = package.atlas.cropping(to: sourceRect) else {
            return
        }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.interpolationQuality = .none
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(frame, in: CGRect(origin: .zero, size: bounds.size))
        context.restoreGState()
    }

    func setState(_ state: String, resetFrame: Bool = true) {
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
        if event.clickCount >= 2 {
            cycleState()
            return
        }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOrigin = window?.frame.origin ?? .zero
        lastDragState = nil
        setState("waving")
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else {
            return
        }
        let currentMouse = NSEvent.mouseLocation
        let deltaX = currentMouse.x - dragStartMouse.x
        let deltaY = currentMouse.y - dragStartMouse.y
        window.setFrameOrigin(NSPoint(x: dragStartOrigin.x + deltaX, y: dragStartOrigin.y + deltaY))

        let state = deltaX >= 0 ? "running-right" : "running-left"
        if state != lastDragState {
            setState(state)
            lastDragState = state
        }
    }

    override func mouseUp(with event: NSEvent) {
        setState("idle")
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        for row in animationRows {
            let item = NSMenuItem(title: row.state, action: #selector(selectState(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = row.state
            item.state = row.state == activeRow.state ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit LightPet", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func selectState(_ sender: NSMenuItem) {
        guard let state = sender.representedObject as? String else {
            return
        }
        setState(state)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func cycleState() {
        guard let currentIndex = animationRows.firstIndex(where: { $0.state == activeRow.state }) else {
            setState(animationRows[0].state)
            return
        }
        let nextIndex = animationRows.index(after: currentIndex) % animationRows.count
        setState(animationRows[nextIndex].state)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let options: LaunchOptions
    private let package: PetPackage
    private var panel: PetPanel?

    init(options: LaunchOptions, package: PetPackage) {
        self.options = options
        self.package = package
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let size = NSSize(width: CGFloat(cellWidth) * options.scale, height: CGFloat(cellHeight) * options.scale)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 80,
            y: screenFrame.minY + 80
        )
        let panel = PetPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = package.manifest.displayName
        panel.contentView = PetAnimationView(package: package, initialState: options.initialState)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.acceptsMouseMovedEvents = true
        panel.isReleasedWhenClosed = false
        panel.orderFrontRegardless()
        self.panel = panel

        print("LightPetDesktop loaded \(package.manifest.displayName) from \(package.manifestURL.path)")
        print("Left-drag to move, right-click for states, double-click to cycle states.")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

do {
    let options = try LaunchOptions.parse(arguments: CommandLine.arguments)
    let package = try loadPetPackage(from: options.manifestPath)
    let app = NSApplication.shared
    let delegate = AppDelegate(options: options, package: package)
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
