// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clawd",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Clawd",
            path: "Clawd",
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
    ]
)
