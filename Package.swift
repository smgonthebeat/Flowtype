// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flowtype",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Flowtype", targets: ["VoiceInputApp"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceInputApp",
            resources: [
                .copy("../../Resources/Info.plist"),
                .copy("../../Resources/Flowtype-logo.svg"),
                .copy("../../Resources/Flowtype-logo.png"),
                .copy("../../Resources/Flowtype.icns"),
                .copy("../../Resources/Qwen-logo.svg"),
                .copy("../../Resources/HomeCardArtwork-mic.png"),
                .copy("../../Resources/HomeCardArtwork-wave.png"),
                .copy("../../Resources/HomeCardArtwork-docs.png"),
                .copy("../../Resources/HomeCardArtwork-clock.png")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("Speech"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "VoiceInputAppTests",
            dependencies: ["VoiceInputApp"],
            path: "Tests/VoiceInputAppTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
