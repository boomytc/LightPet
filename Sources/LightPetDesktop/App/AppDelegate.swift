import AppKit
import Darwin
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
        rememberCodexPet(package: currentPackage)

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
        print("Mouse-only states: hover=waiting, click=failed, hold=waving, drag=left/right/up/down.")

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

@MainActor
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
        rememberCodexPet(package: package)
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
