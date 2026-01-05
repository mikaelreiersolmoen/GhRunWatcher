// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhRunWatcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GhRunWatcher", targets: ["RunWatcher"])
    ],
    targets: [
        .executableTarget(
            name: "RunWatcher"
        )
    ]
)
