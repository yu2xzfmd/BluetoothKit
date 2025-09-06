// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BluetoothKit",
    defaultLocalization: "ja",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "BluetoothKit", targets: ["BluetoothKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "BluetoothKit",
            path: "Sources/BluetoothKit"
        ),
        .testTarget(
            name: "BluetoothKitTests",
            dependencies: ["BluetoothKit"],
            path: "Tests/BluetoothKitTests"
        ),
    ]
)
