// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "shoely",
    platforms: [
        .iOS(.v17) // Updated to the latest iOS version available
    ],
    products: [
        .library(
            name: "shoely",
            targets: ["shoely"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "shoely",
            dependencies: []
        ),
        .testTarget(
            name: "ShoelyTests",
            dependencies: ["shoely"]
        )
    ]
)