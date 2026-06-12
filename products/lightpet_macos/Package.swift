// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LightPet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LightPetDesktop", targets: ["LightPetDesktop"])
    ],
    targets: [
        .target(
            name: "LightPetDesktopCore",
            path: "Sources/LightPetDesktop/Core"
        ),
        .target(
            name: "LightPetDesktopRendering",
            dependencies: ["LightPetDesktopCore"],
            path: "Sources/LightPetDesktop/Rendering"
        ),
        .executableTarget(
            name: "LightPetDesktop",
            dependencies: ["LightPetDesktopCore", "LightPetDesktopRendering"],
            path: "Sources/LightPetDesktop",
            exclude: ["Core", "Rendering"]
        ),
        .testTarget(
            name: "LightPetDesktopTests",
            dependencies: ["LightPetDesktopCore"]
        )
    ]
)
