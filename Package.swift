// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HiddenTextKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "HiddenTextKit", targets: ["HiddenTextKit"]),
        .executable(name: "HiddenTextDemo", targets: ["HiddenTextDemo"])
    ],
    targets: [
        .target(name: "HiddenTextKit"),
        .executableTarget(
            name: "HiddenTextDemo",
            dependencies: ["HiddenTextKit"]
        ),
        .testTarget(
            name: "HiddenTextKitTests",
            dependencies: ["HiddenTextKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
