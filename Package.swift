// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "gitview",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "GitViewCore"),
        .executableTarget(name: "gitview", dependencies: ["GitViewCore"]),
        .testTarget(name: "GitViewCoreTests", dependencies: ["GitViewCore"]),
    ],
    swiftLanguageModes: [.v5]
)
