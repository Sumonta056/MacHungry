// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacHungry",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HungryCore"),
        .target(name: "HungrySystem", dependencies: ["HungryCore"]),
        .testTarget(name: "HungryCoreTests", dependencies: ["HungryCore"]),
        .testTarget(name: "HungrySystemTests", dependencies: ["HungrySystem", "HungryCore"]),
    ]
)
