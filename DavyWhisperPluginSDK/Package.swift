// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DavyWhisperPluginSDK",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DavyWhisperPluginSDK", type: .dynamic, targets: ["DavyWhisperPluginSDK"]),
    ],
    targets: [
        .target(name: "DavyWhisperPluginSDK"),
        .testTarget(
            name: "DavyWhisperPluginSDKTests",
            dependencies: ["DavyWhisperPluginSDK"]
        ),
    ]
)
