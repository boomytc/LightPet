import AppKit
import CoreGraphics
import Darwin
import Foundation

let availableScales: [CGFloat] = [0.5, 0.75, 1, 1.25, 1.5]
let defaultsSuiteName = "LightPetDesktop"
let lastCodexPetIDKey = "lastCodexPetID"
let requiredManifestFilename = "pet.json"
let requiredSpritesheetFilename = "spritesheet.webp"

struct AnimationRow {
    let state: String
    let row: Int
    let frameCount: Int
    let durations: [TimeInterval]

    var totalDuration: TimeInterval {
        durations.reduce(0, +)
    }
}

let rowByState = Dictionary(uniqueKeysWithValues: animationRows.map { ($0.state, $0) })

struct PetManifest: Decodable {
    let id: String
    let displayName: String
    let description: String
    let spritesheetPath: String
    let rendering: String?

    var usesSmoothRendering: Bool {
        rendering == "smooth"
    }
}

struct PetFrame {
    let image: CGImage
    let alpha: [UInt8]

    func hasVisiblePixel(x: Int, y: Int) -> Bool {
        guard x >= 0, x < cellWidth, y >= 0, y < cellHeight else {
            return false
        }
        return alpha[y * cellWidth + x] > visibleAlphaThreshold
    }
}

final class PetFrameStore {
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
                let nonzeroAlphaPixels = frame.alpha.filter { $0 != 0 }.count
                guard nonzeroAlphaPixels == 0 else {
                    throw RuntimeError("\(row.state) unused column \(column) is not fully transparent.")
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

struct PetPackage {
    let manifest: PetManifest
    let manifestURL: URL
    let spritesheetURL: URL
    let frames: PetFrameStore
}

struct PetChoice {
    let manifest: PetManifest
    let manifestURL: URL

    var title: String {
        manifest.displayName.isEmpty ? manifest.id : manifest.displayName
    }
}

struct LaunchOptions {
    var manifestPath: String?
    var petID: String?
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

enum LaunchError: Error, CustomStringConvertible {
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

let helpText = """
Usage:
  swift run LightPetDesktop [--pet path/to/pet.json] [--pet-id pet-id] [--state idle] [--scale 1] [--show-dock]

Pet lookup:
  --pet exact manifest path wins.
  Without --pet, LightPet reads ${CODEX_HOME:-$HOME/.codex}/pets.
  It tries --pet-id, then the last selected Codex pet, then the first pet found.

Mouse:
  hover visible sprite  waiting
  click                 failed
  long press            waving
  drag left/right       running-left/running-right
  drag up/down          jumping/review
  right click           size, pet, reset-position, and quit menu

Sizes:
  0.5x, 0.75x, 1x, 1.25x, 1.5x
"""

func loadPetPackage(options: LaunchOptions) throws -> PetPackage {
    let manifestURL = try resolveManifestURL(options: options)
    var selectedLoadError: Error?
    do {
        return try loadPetPackage(manifestURL: manifestURL)
    } catch {
        guard options.manifestPath == nil else {
            throw error
        }
        selectedLoadError = error
        fputs("LightPetDesktop warning: pet at \(manifestURL.path) could not be loaded: \(error). Trying the next available Codex pet.\n", stderr)
    }

    let choices = discoverPetChoices().filter { $0.manifestURL.path != manifestURL.path }
    var lastError = selectedLoadError
    for choice in choices {
        do {
            return try loadPetPackage(manifestURL: choice.manifestURL)
        } catch {
            lastError = error
            fputs("LightPetDesktop warning: pet at \(choice.manifestURL.path) could not be loaded: \(error).\n", stderr)
        }
    }

    throw noLoadablePetsError(libraryURL: codexPetLibraryURL(), underlyingError: lastError)
}

func loadPetPackage(directoryURL: URL) throws -> PetPackage {
    let manifestURL = directoryURL.appendingPathComponent(requiredManifestFilename).standardizedFileURL
    guard FileManager.default.fileExists(atPath: manifestURL.path) else {
        throw RuntimeError("Selected folder must contain pet.json.")
    }
    let spritesheetURL = directoryURL.appendingPathComponent(requiredSpritesheetFilename).standardizedFileURL
    guard FileManager.default.fileExists(atPath: spritesheetURL.path) else {
        throw RuntimeError("Selected folder must contain spritesheet.webp.")
    }
    return try loadPetPackage(manifestURL: manifestURL)
}

func loadPetPackage(manifestURL: URL) throws -> PetPackage {
    let manifest = try loadPetManifest(manifestURL: manifestURL)
    let spritesheetURL = try validatePetPackageSurface(manifest: manifest, manifestURL: manifestURL)

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

func loadPetManifest(manifestURL: URL) throws -> PetManifest {
    let data = try Data(contentsOf: manifestURL)
    return try JSONDecoder().decode(PetManifest.self, from: data)
}

func validatePetPackageSurface(manifest: PetManifest, manifestURL: URL) throws -> URL {
    let standardizedManifestURL = manifestURL.standardizedFileURL
    guard standardizedManifestURL.lastPathComponent == requiredManifestFilename else {
        throw RuntimeError("Pet manifest path must be named pet.json.")
    }
    guard manifest.spritesheetPath == requiredSpritesheetFilename else {
        throw RuntimeError("pet.json must set spritesheetPath to spritesheet.webp.")
    }
    let spritesheetURL = standardizedManifestURL
        .deletingLastPathComponent()
        .appendingPathComponent(requiredSpritesheetFilename)
        .standardizedFileURL
    guard FileManager.default.fileExists(atPath: spritesheetURL.path) else {
        throw RuntimeError("Pet package must contain spritesheet.webp next to pet.json.")
    }
    return spritesheetURL
}

func discoverPetChoices() -> [PetChoice] {
    guard let libraryURL = try? ensureCodexPetLibraryExists() else {
        return []
    }
    return discoverPetChoices(in: libraryURL)
}

func discoverPetChoices(in libraryURL: URL) -> [PetChoice] {
    var seenPaths = Set<String>()
    var choices: [PetChoice] = []

    for manifestURL in petManifestURLs(in: libraryURL) {
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

func petChoice(manifestURL: URL) -> PetChoice? {
    guard
        let manifest = try? loadPetManifest(manifestURL: manifestURL),
        (try? validatePetPackageSurface(manifest: manifest, manifestURL: manifestURL)) != nil
    else {
        return nil
    }

    // Keep context-menu discovery lightweight. Full spritesheet decode,
    // frame extraction, and alpha validation happen only when a pet is loaded.
    return PetChoice(manifest: manifest, manifestURL: manifestURL)
}

func petManifestURLs(in root: URL) -> [URL] {
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
        let manifestURL = entry.appendingPathComponent(requiredManifestFilename).standardizedFileURL
        return FileManager.default.fileExists(atPath: manifestURL.path) ? manifestURL : nil
    }
}

func resolveManifestURL(options: LaunchOptions) throws -> URL {
    if let manifestPath = options.manifestPath {
        let manifestURL = fileURL(from: manifestPath)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw RuntimeError("Pet manifest does not exist at \(manifestURL.path).")
        }
        return manifestURL
    }

    let libraryURL = try ensureCodexPetLibraryExists()

    if let petID = options.petID ?? lastCodexPetID() {
        let manifestURL = codexPetManifestURL(petID: petID)
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            return manifestURL
        }
        fputs("LightPetDesktop warning: pet '\(petID)' was not found under \(libraryURL.path); falling back to the first available Codex pet.\n", stderr)
    }

    if let fallback = discoverPetChoices(in: libraryURL).first {
        return fallback.manifestURL
    }

    throw noPetsFoundError(libraryURL: libraryURL)
}

func fileURL(from path: String) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }
    return URL(
        fileURLWithPath: expanded,
        relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ).standardizedFileURL
}

func codexPetLibraryURL() -> URL {
    codexHomeURL()
        .appendingPathComponent("pets")
        .standardizedFileURL
}

func ensureCodexPetLibraryExists() throws -> URL {
    let libraryURL = codexPetLibraryURL()
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: libraryURL.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw RuntimeError(
                "The Codex pet path exists but is not a directory: \(libraryURL.path)",
                alertTitle: "Pet Directory Is Invalid"
            )
        }
        return libraryURL
    }

    do {
        try FileManager.default.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        return libraryURL
    } catch {
        throw RuntimeError(
            "Could not create the Codex pet directory at \(libraryURL.path): \(error.localizedDescription)",
            alertTitle: "Could Not Create Pet Directory"
        )
    }
}

func codexHomeURL() -> URL {
    if let path = ProcessInfo.processInfo.environment["CODEX_HOME"], !path.isEmpty {
        return fileURL(from: path)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex")
        .standardizedFileURL
}

func codexPetManifestURL(petID: String) -> URL {
    codexPetLibraryURL()
        .appendingPathComponent(petID)
        .appendingPathComponent(requiredManifestFilename)
        .standardizedFileURL
}

func lastCodexPetID() -> String? {
    petDefaults().string(forKey: lastCodexPetIDKey)
}

func rememberCodexPet(package: PetPackage) {
    guard let petID = codexPetID(for: package.manifestURL) else {
        return
    }
    petDefaults().set(petID, forKey: lastCodexPetIDKey)
}

func codexPetID(for manifestURL: URL) -> String? {
    let standardizedManifestURL = manifestURL.standardizedFileURL
    guard standardizedManifestURL.lastPathComponent == requiredManifestFilename else {
        return nil
    }

    let petDirectoryURL = standardizedManifestURL.deletingLastPathComponent().standardizedFileURL
    guard petDirectoryURL.deletingLastPathComponent().standardizedFileURL.path == codexPetLibraryURL().path else {
        return nil
    }
    return petDirectoryURL.lastPathComponent
}

func petDefaults() -> UserDefaults {
    UserDefaults(suiteName: defaultsSuiteName) ?? .standard
}

struct RuntimeError: Error, CustomStringConvertible {
    let description: String
    let alertTitle: String

    init(_ description: String, alertTitle: String = "Could Not Start LightPet") {
        self.description = description
        self.alertTitle = alertTitle
    }
}

func noPetsFoundError(libraryURL: URL) -> RuntimeError {
    RuntimeError(
        "No valid pets were found in \(libraryURL.path).\n\nAdd a pet folder under \(libraryURL.path)/<pet-id>/ containing pet.json and spritesheet.webp, then launch LightPet again.",
        alertTitle: "No Pets Found"
    )
}

func noLoadablePetsError(libraryURL: URL, underlyingError: Error?) -> RuntimeError {
    let detail = underlyingError.map { "\n\nLast load error: \($0)" } ?? ""
    return RuntimeError(
        "No loadable pets were found in \(libraryURL.path).\n\nAdd a pet folder under \(libraryURL.path)/<pet-id>/ containing a valid pet.json and spritesheet.webp, then launch LightPet again.\(detail)",
        alertTitle: "No Loadable Pets"
    )
}
