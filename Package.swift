// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mdreader",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "mdreader",
            path: "Sources/mdreader",
            resources: [
                .copy("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
