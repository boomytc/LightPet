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
        .executableTarget(name: "LightPetDesktop"),
        .testTarget(
            name: "LightPetDesktopTests",
            dependencies: ["LightPetDesktop"]
        )
    ]
)
