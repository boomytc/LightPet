import Darwin
import Foundation

package let availableScales: [Double] = [0.5, 0.75, 1, 1.25, 1.5]
package let defaultsSuiteName = "LightPetDesktop"
package let lastCodexPetIDKey = "lastCodexPetID"
package let requiredManifestFilename = "pet.json"
package let requiredSpritesheetFilename = "spritesheet.webp"

package struct AnimationRow {
    package let state: String
    package let row: Int
    package let frameCount: Int
    package let durations: [TimeInterval]

    package var totalDuration: TimeInterval {
        durations.reduce(0, +)
    }
}

package let rowByState = Dictionary(uniqueKeysWithValues: animationRows.map { ($0.state, $0) })

package struct PetManifest: Decodable {
    package let id: String
    package let displayName: String
    package let description: String
    package let spritesheetPath: String
    package let rendering: String?

    package init(
        id: String,
        displayName: String,
        description: String,
        spritesheetPath: String,
        rendering: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.spritesheetPath = spritesheetPath
        self.rendering = rendering
    }

    package var usesSmoothRendering: Bool {
        rendering == "smooth"
    }
}

package struct PetChoice {
    package let manifest: PetManifest
    package let manifestURL: URL

    package init(manifest: PetManifest, manifestURL: URL) {
        self.manifest = manifest
        self.manifestURL = manifestURL
    }

    package var title: String {
        manifest.displayName.isEmpty ? manifest.id : manifest.displayName
    }
}

package struct LaunchOptions {
    package var manifestPath: String?
    package var petID: String?
    package var initialState: String
    package var scale: Double
    package var showDock: Bool
    package var runResizeSmokeTest: Bool

    package init(
        manifestPath: String? = nil,
        petID: String? = nil,
        initialState: String = "idle",
        scale: Double = 1,
        showDock: Bool = false,
        runResizeSmokeTest: Bool = false
    ) {
        self.manifestPath = manifestPath
        self.petID = petID
        self.initialState = initialState
        self.scale = scale
        self.showDock = showDock
        self.runResizeSmokeTest = runResizeSmokeTest
    }

    package static func parse(arguments: [String]) throws -> LaunchOptions {
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
                guard isAvailableScale(value) else {
                    throw LaunchError.invalidValue("--scale", arguments[index])
                }
                options.scale = value
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

package enum LaunchError: Error, CustomStringConvertible {
    case helpRequested
    case missingValue(String)
    case invalidValue(String, String)
    case unknownArgument(String)

    package var description: String {
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

package let helpText = """
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

package func loadPetWithFallback<Package>(options: LaunchOptions, loader: (URL) throws -> Package) throws -> Package {
    let manifestURL = try resolveManifestURL(options: options)
    var selectedLoadError: Error?
    do {
        return try loader(manifestURL)
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
            return try loader(choice.manifestURL)
        } catch {
            lastError = error
            fputs("LightPetDesktop warning: pet at \(choice.manifestURL.path) could not be loaded: \(error).\n", stderr)
        }
    }

    throw noLoadablePetsError(libraryURL: codexPetLibraryURL(), underlyingError: lastError)
}

package func loadPetManifest(manifestURL: URL) throws -> PetManifest {
    let data = try Data(contentsOf: manifestURL)
    let manifest = try JSONDecoder().decode(PetManifest.self, from: data)
    try validateRequiredManifestString(manifest.id, key: "id")
    try validateRequiredManifestString(manifest.displayName, key: "displayName")
    try validateRequiredManifestString(manifest.description, key: "description")
    try validateRequiredManifestString(manifest.spritesheetPath, key: "spritesheetPath")
    return manifest
}

private func validateRequiredManifestString(_ value: String, key: String) throws {
    guard !value.isEmpty else {
        throw RuntimeError("pet.json must contain a non-empty \(key).")
    }
}

package func validatePetPackageSurface(manifest: PetManifest, manifestURL: URL) throws -> URL {
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

package func discoverPetChoices() -> [PetChoice] {
    guard let libraryURL = try? ensureCodexPetLibraryExists() else {
        return []
    }
    return discoverPetChoices(in: libraryURL)
}

package func discoverPetChoices(in libraryURL: URL) -> [PetChoice] {
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

package func petChoice(manifestURL: URL) -> PetChoice? {
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

package func petManifestURLs(in root: URL) -> [URL] {
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

package func resolveManifestURL(options: LaunchOptions) throws -> URL {
    if let manifestPath = options.manifestPath {
        let manifestURL = fileURL(from: manifestPath)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw RuntimeError("Pet manifest does not exist at \(manifestURL.path).")
        }
        return manifestURL
    }

    let libraryURL = try ensureCodexPetLibraryExists()

    for petID in preferredCodexPetIDs(options: options) {
        let manifestURL = codexPetManifestURL(petID: petID)
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            return manifestURL
        }
        fputs("LightPetDesktop warning: pet '\(petID)' was not found under \(libraryURL.path); trying the next pet candidate.\n", stderr)
    }

    if let fallback = discoverPetChoices(in: libraryURL).first {
        return fallback.manifestURL
    }

    throw noPetsFoundError(libraryURL: libraryURL)
}

package func preferredCodexPetIDs(options: LaunchOptions) -> [String] {
    var petIDs: [String] = []
    var seen = Set<String>()
    for petID in [options.petID, lastCodexPetID()] {
        guard let petID, !petID.isEmpty, seen.insert(petID).inserted else {
            continue
        }
        petIDs.append(petID)
    }
    return petIDs
}

package func fileURL(from path: String) -> URL {
    let expanded = (path as NSString).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }
    return URL(
        fileURLWithPath: expanded,
        relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ).standardizedFileURL
}

package func codexPetLibraryURL() -> URL {
    codexHomeURL()
        .appendingPathComponent("pets")
        .standardizedFileURL
}

package func ensureCodexPetLibraryExists() throws -> URL {
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

package func codexHomeURL() -> URL {
    if let path = ProcessInfo.processInfo.environment["CODEX_HOME"], !path.isEmpty {
        return fileURL(from: path)
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex")
        .standardizedFileURL
}

package func codexPetManifestURL(petID: String) -> URL {
    codexPetLibraryURL()
        .appendingPathComponent(petID)
        .appendingPathComponent(requiredManifestFilename)
        .standardizedFileURL
}

package func lastCodexPetID() -> String? {
    petDefaults().string(forKey: lastCodexPetIDKey)
}

package func rememberCodexPet(manifestURL: URL) {
    guard let petID = codexPetID(for: manifestURL) else {
        return
    }
    petDefaults().set(petID, forKey: lastCodexPetIDKey)
}

package func codexPetID(for manifestURL: URL) -> String? {
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

package func petDefaults() -> UserDefaults {
    UserDefaults(suiteName: defaultsSuiteName) ?? .standard
}

package struct RuntimeError: Error, CustomStringConvertible {
    package let description: String
    package let alertTitle: String

    package init(_ description: String, alertTitle: String = "Could Not Start LightPet") {
        self.description = description
        self.alertTitle = alertTitle
    }
}

package func noPetsFoundError(libraryURL: URL) -> RuntimeError {
    RuntimeError(
        "No valid pets were found in \(libraryURL.path).\n\nAdd a pet folder under \(libraryURL.path)/<pet-id>/ containing pet.json and spritesheet.webp, then launch LightPet again.",
        alertTitle: "No Pets Found"
    )
}

package func noLoadablePetsError(libraryURL: URL, underlyingError: Error?) -> RuntimeError {
    let detail = underlyingError.map { "\n\nLast load error: \($0)" } ?? ""
    return RuntimeError(
        "No loadable pets were found in \(libraryURL.path).\n\nAdd a pet folder under \(libraryURL.path)/<pet-id>/ containing a valid pet.json and spritesheet.webp, then launch LightPet again.\(detail)",
        alertTitle: "No Loadable Pets"
    )
}
