// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xmax_sdk",
    platforms: [.iOS("15.0")],
    products: [.library(name: "xmax-sdk", targets: ["xmax_sdk"])],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "xmax_sdk",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")]
        )
    ]
)
