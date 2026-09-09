// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TraeChime",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TraeChime",
            path: "Sources/TraeChime",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "TraeChimeHook",
            path: "Sources/TraeChimeHook"
        )
    ]
)
