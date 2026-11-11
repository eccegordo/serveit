// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ServeIt",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ServeIt", path: "Sources/ServeIt")
    ]
)
