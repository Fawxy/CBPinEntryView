// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CBPinEntryView",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "CBPinEntryView", targets: ["CBPinEntryView"])
    ],
    targets: [
        .target(name: "CBPinEntryView"),
        .testTarget(name: "CBPinEntryViewTests", dependencies: ["CBPinEntryView"])
    ]
)
