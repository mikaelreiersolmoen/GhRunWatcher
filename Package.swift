// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhRunWatcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GhRunWatcher", targets: ["RunWatcher"]),
        .executable(name: "GhRunWatcherMCP", targets: ["RunWatcherMCP"])
    ],
    targets: [
        .target(name: "GhRunWatcherIPC"),
        .executableTarget(
            name: "RunWatcher",
            dependencies: ["GhRunWatcherIPC"],
            path: "Sources/GhRunWatcher"
        ),
        .executableTarget(
            name: "RunWatcherMCP",
            dependencies: ["GhRunWatcherIPC"]
        )
    ]
)
