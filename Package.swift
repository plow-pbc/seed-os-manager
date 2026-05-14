// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "seedctl",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "seedctl",
            path: "Sources/seedctl"
        ),
        .testTarget(
            name: "seedctlTests",
            dependencies: ["seedctl"],
            path: "Tests/seedctlTests"
        ),
    ]
)
