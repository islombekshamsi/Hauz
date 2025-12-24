// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "shoely",
    platforms: [
        .iOS(.v15)
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