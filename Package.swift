// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacHungry",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HungryCore"),
        .testTarget(name: "HungryCoreTests", dependencies: ["HungryCore"]),
    ]
)
