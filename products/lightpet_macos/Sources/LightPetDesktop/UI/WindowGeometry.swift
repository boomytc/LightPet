import AppKit
import Foundation
import LightPetDesktopCore

func defaultWindowOrigin(size: NSSize) -> NSPoint {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    return clampedWindowOrigin(
        NSPoint(x: screenFrame.maxX - size.width - 80, y: screenFrame.minY + 80),
        size: size
    )
}

func clampedWindowOrigin(_ origin: NSPoint, size: NSSize) -> NSPoint {
    let visibleFrame = visibleScreenUnion()
    let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
    let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)
    return NSPoint(
        x: min(max(origin.x, visibleFrame.minX), maxX),
        y: min(max(origin.y, visibleFrame.minY), maxY)
    )
}

func visibleScreenUnion() -> NSRect {
    let screens = NSScreen.screens
    guard var union = screens.first?.visibleFrame else {
        return NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
    for screen in screens.dropFirst() {
        union = union.union(screen.visibleFrame)
    }
    return union
}

@MainActor
func showFatalStartupError(_ error: Error) {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.messageText = (error as? RuntimeError)?.alertTitle ?? "Could Not Start LightPet"
    alert.informativeText = "\(error)"
    alert.alertStyle = .warning
    alert.runModal()
}
