import Darwin
import Foundation
@testable import LightPetDesktop
import XCTest

final class PetRuntimeTests: XCTestCase {
    func testValidatePetPackageSurfaceRequiresCanonicalSpritesheetPath() throws {
        try withTemporaryDirectory { directoryURL in
            let manifestURL = directoryURL.appendingPathComponent("pet.json")
            try Data().write(to: directoryURL.appendingPathComponent("spritesheet.webp"))

            let manifest = PetManifest(
                id: "bad",
                displayName: "Bad",
                description: "Bad pet package.",
                spritesheetPath: "alt.webp",
                rendering: nil
            )

            XCTAssertThrowsError(try validatePetPackageSurface(manifest: manifest, manifestURL: manifestURL)) { error in
                XCTAssertTrue("\(error)".contains("spritesheetPath to spritesheet.webp"))
            }
        }
    }

    func testPetChoiceRejectsNoncanonicalDirectManifest() throws {
        try withTemporaryDirectory { directoryURL in
            try writeManifest(
                in: directoryURL,
                id: "bad",
                displayName: "Bad",
                spritesheetPath: "alt.webp"
            )
            try Data().write(to: directoryURL.appendingPathComponent("alt.webp"))

            XCTAssertNil(petChoice(manifestURL: directoryURL.appendingPathComponent("pet.json")))
        }
    }

    func testResolveManifestURLFallsBackToFirstValidDiscoveredPetWhenRequestedIDIsMissing() throws {
        try withTemporaryCodexHome { codexHomeURL in
            let petDirectoryURL = codexHomeURL
                .appendingPathComponent("pets")
                .appendingPathComponent("alpha")
            try writeCanonicalPackageSurface(in: petDirectoryURL, id: "alpha", displayName: "Alpha")

            let options = LaunchOptions(manifestPath: nil, petID: "missing")
            let manifestURL = try resolveManifestURL(options: options)

            XCTAssertEqual(manifestURL, petDirectoryURL.appendingPathComponent("pet.json").standardizedFileURL)
        }
    }

    func testResolveManifestURLTriesLastSelectedPetWhenRequestedIDIsMissing() throws {
        try withTemporaryCodexHome { codexHomeURL in
            let petsURL = codexHomeURL.appendingPathComponent("pets")
            let firstByTitleURL = petsURL.appendingPathComponent("alpha")
            try writeCanonicalPackageSurface(in: firstByTitleURL, id: "alpha", displayName: "Alpha")
            let lastSelectedURL = petsURL.appendingPathComponent("zulu")
            try writeCanonicalPackageSurface(in: lastSelectedURL, id: "zulu", displayName: "Zulu")

            try withTemporaryLastCodexPetID("zulu") {
                let options = LaunchOptions(manifestPath: nil, petID: "missing")
                let manifestURL = try resolveManifestURL(options: options)

                XCTAssertEqual(manifestURL, lastSelectedURL.appendingPathComponent("pet.json").standardizedFileURL)
            }
        }
    }

    func testLoadPetManifestRejectsEmptyRequiredStrings() throws {
        let validFields = [
            "id": "valid",
            "displayName": "Valid",
            "description": "Valid test pet.",
            "spritesheetPath": "spritesheet.webp",
            "rendering": "pixelated"
        ]

        for key in ["id", "displayName", "description", "spritesheetPath"] {
            try withTemporaryDirectory { directoryURL in
                var fields = validFields
                fields[key] = ""
                let data = try JSONSerialization.data(withJSONObject: fields, options: [.prettyPrinted, .sortedKeys])
                let manifestURL = directoryURL.appendingPathComponent("pet.json")
                try data.write(to: manifestURL)

                XCTAssertThrowsError(try loadPetManifest(manifestURL: manifestURL)) { error in
                    XCTAssertTrue("\(error)".contains("non-empty \(key)"))
                }
            }
        }
    }

    func testPetPanelMouseRoutingIgnoresOnlyTransparentIdlePanel() {
        XCTAssertTrue(shouldPetPanelIgnoreMouseEvents(
            insideVisibleSprite: false,
            interactionActive: false,
            contextMenuOpen: false
        ))
        XCTAssertFalse(shouldPetPanelIgnoreMouseEvents(
            insideVisibleSprite: true,
            interactionActive: false,
            contextMenuOpen: false
        ))
        XCTAssertFalse(shouldPetPanelIgnoreMouseEvents(
            insideVisibleSprite: false,
            interactionActive: true,
            contextMenuOpen: false
        ))
        XCTAssertFalse(shouldPetPanelIgnoreMouseEvents(
            insideVisibleSprite: false,
            interactionActive: false,
            contextMenuOpen: true
        ))
    }

    func testLoadPetPackageFallsBackWhenRequestedPackageFailsSurfaceValidation() throws {
        try withTemporaryCodexHome { codexHomeURL in
            let petsURL = codexHomeURL.appendingPathComponent("pets")
            let brokenURL = petsURL.appendingPathComponent("broken")
            try writeManifest(
                in: brokenURL,
                id: "broken",
                displayName: "Broken",
                spritesheetPath: "alt.webp"
            )
            try Data().write(to: brokenURL.appendingPathComponent("alt.webp"))

            let validURL = petsURL.appendingPathComponent("valid")
            try writeCanonicalPackageSurface(in: validURL, id: "valid", displayName: "Valid")
            try copyExampleSpritesheet(to: validURL.appendingPathComponent("spritesheet.webp"))

            let options = LaunchOptions(manifestPath: nil, petID: "broken")
            let package = try loadPetPackage(options: options)

            XCTAssertEqual(package.manifest.id, "valid")
            XCTAssertEqual(package.manifestURL, validURL.appendingPathComponent("pet.json").standardizedFileURL)
        }
    }

    func testCodexPetIDOnlyAcceptsPetJSONDirectlyUnderCodexPetLibrary() throws {
        try withTemporaryCodexHome { codexHomeURL in
            let petDirectoryURL = codexHomeURL
                .appendingPathComponent("pets")
                .appendingPathComponent("lulu")
            try writeCanonicalPackageSurface(in: petDirectoryURL, id: "lulu", displayName: "Lulu")

            XCTAssertEqual(codexPetID(for: petDirectoryURL.appendingPathComponent("pet.json")), "lulu")
            XCTAssertNil(codexPetID(for: petDirectoryURL.appendingPathComponent("manifest.json")))
            XCTAssertNil(codexPetID(for: codexHomeURL.appendingPathComponent("outside").appendingPathComponent("pet.json")))
        }
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LightPetTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        try body(directoryURL)
    }

    private func withTemporaryCodexHome(_ body: (URL) throws -> Void) throws {
        let oldCodexHome = getenv("CODEX_HOME").map { String(cString: $0) }
        try withTemporaryDirectory { directoryURL in
            setenv("CODEX_HOME", directoryURL.path, 1)
            defer {
                if let oldCodexHome {
                    setenv("CODEX_HOME", oldCodexHome, 1)
                } else {
                    unsetenv("CODEX_HOME")
                }
            }
            try body(directoryURL)
        }
    }

    private func withTemporaryLastCodexPetID(_ petID: String, body: () throws -> Void) throws {
        let defaults = petDefaults()
        let previousPetID = defaults.string(forKey: lastCodexPetIDKey)
        defaults.set(petID, forKey: lastCodexPetIDKey)
        defer {
            if let previousPetID {
                defaults.set(previousPetID, forKey: lastCodexPetIDKey)
            } else {
                defaults.removeObject(forKey: lastCodexPetIDKey)
            }
        }
        try body()
    }

    private func productRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func copyExampleSpritesheet(to destinationURL: URL) throws {
        let sourceURL = productRoot()
            .appendingPathComponent("examples")
            .appendingPathComponent("pets")
            .appendingPathComponent("lulu")
            .appendingPathComponent("spritesheet.webp")
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func writeCanonicalPackageSurface(
        in directoryURL: URL,
        id: String,
        displayName: String
    ) throws {
        try writeManifest(in: directoryURL, id: id, displayName: displayName, spritesheetPath: "spritesheet.webp")
        if !FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("spritesheet.webp").path) {
            try Data().write(to: directoryURL.appendingPathComponent("spritesheet.webp"))
        }
    }

    private func writeManifest(
        in directoryURL: URL,
        id: String,
        displayName: String,
        spritesheetPath: String
    ) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let json = """
        {
          "id": "\(id)",
          "displayName": "\(displayName)",
          "description": "\(displayName) test pet.",
          "spritesheetPath": "\(spritesheetPath)",
          "rendering": "pixelated"
        }
        """
        try json.write(to: directoryURL.appendingPathComponent("pet.json"), atomically: true, encoding: .utf8)
    }
}
