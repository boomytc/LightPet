import CoreGraphics
import Foundation
import ImageIO
import LightPetDesktopCore

package struct PetFrame {
    package let image: CGImage
    package let alpha: [UInt8]

    package func hasVisiblePixel(x: Int, y: Int) -> Bool {
        guard x >= 0, x < cellWidth, y >= 0, y < cellHeight else {
            return false
        }
        return alpha[y * cellWidth + x] > visibleAlphaThreshold
    }
}

package final class PetFrameStore {
    private let framesByState: [String: [PetFrame]]

    package init(atlas: CGImage) throws {
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

    package func frame(for row: AnimationRow, index: Int) -> PetFrame {
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

package struct PetPackage {
    package let manifest: PetManifest
    package let manifestURL: URL
    package let spritesheetURL: URL
    package let frames: PetFrameStore
}

package func loadPetPackage(options: LaunchOptions) throws -> PetPackage {
    try loadPetWithFallback(options: options, loader: loadPetPackage(manifestURL:))
}

package func loadPetPackage(directoryURL: URL) throws -> PetPackage {
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

package func loadPetPackage(manifestURL: URL) throws -> PetPackage {
    let manifest = try loadPetManifest(manifestURL: manifestURL)
    let spritesheetURL = try validatePetPackageSurface(manifest: manifest, manifestURL: manifestURL)

    guard let imageSource = CGImageSourceCreateWithURL(spritesheetURL as CFURL, nil) else {
        throw RuntimeError("Could not load spritesheet at \(spritesheetURL.path).")
    }
    guard let atlas = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
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

package func rememberCodexPet(package: PetPackage) {
    rememberCodexPet(manifestURL: package.manifestURL)
}
