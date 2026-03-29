// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clawd",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Clawd",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Clawd",
            exclude: [
                "Info.plist",
            ],
            resources: [
                .process("Assets.xcassets"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Clawd/Info.plist"]),
            ]
        ),
        .testTarget(
            name: "ClawdTests",
            dependencies: ["Clawd"],
            path: "Tests"
        ),
    ]
)
