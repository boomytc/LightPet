import AppKit
import Darwin
import Foundation
import LightPetDesktopCore
import LightPetDesktopRendering

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
    Task { @MainActor in
        showFatalStartupError(error)
        exit(1)
    }
    RunLoop.main.run()
    exit(1)
}
