// swift-tools-version:6.0
import PackageDescription
let package = Package(
    name: "HotkeySpike",
    platforms: [.macOS("26.0")],
    targets: [.executableTarget(name: "HotkeySpike", swiftSettings: [.swiftLanguageMode(.v5)])]
)
