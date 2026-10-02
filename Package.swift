// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DockAutoHide",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DockAutoHide",
            path: "Sources/DockAutoHide"
        )
    ]
)
