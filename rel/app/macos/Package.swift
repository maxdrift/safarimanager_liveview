// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "Safarimanager",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(name: "ElixirKit", path: "../../../elixirkit/elixirkit_swift")
    ],
    targets: [
        .executableTarget(
            name: "Safarimanager",
            dependencies: ["ElixirKit"]
        )
    ]
)
