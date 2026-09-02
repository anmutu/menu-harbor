// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MenuHarbor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MenuHarbor", targets: ["MenuHarbor"]),
    ],
    targets: [
        .executableTarget(name: "MenuHarbor"),
        .testTarget(name: "MenuHarborTests", dependencies: ["MenuHarbor"]),
    ],
    swiftLanguageModes: [.v5]
)

