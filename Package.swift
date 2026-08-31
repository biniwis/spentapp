// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoneyCity",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MoneyCity", targets: ["MoneyCity"])
    ],
    targets: [
        .target(
            name: "MoneyCity",
            path: "MoneyCity",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MoneyCityTests",
            dependencies: ["MoneyCity"],
            path: "MoneyCityTests"
        )
    ]
)
