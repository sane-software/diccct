// swift-tools-version: 6.0
import PackageDescription

// Diccct is a menu-bar-only macOS app with zero third-party dependencies by
// design: only Apple's own Foundation / AppKit / SwiftUI are used.
//
// Layout:
//   - DiccctCore  : pure, UI-agnostic logic (dict.cc parsing, search index,
//                   data-directory scanning). Foundation-only, so it is fully
//                   unit-testable without spinning up AppKit.
//   - Diccct      : the executable app shell (AppKit status item + non-activating
//                   floating NSPanel hosting the SwiftUI content). Depends on
//                   DiccctCore.
//
// The app makes itself an accessory (no Dock icon) at runtime via
// NSApplication.setActivationPolicy(.accessory), so it behaves as a proper
// menu-bar agent even when launched with `swift run`. scripts/build-app.sh
// wraps the built binary into a Diccct.app bundle for normal use.
let package = Package(
    name: "Diccct",
    platforms: [
        // macOS 14 floor: SwiftUI Grid, .textSelection, modern SwiftUI APIs.
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "DiccctCore",
            path: "Sources/DiccctCore"
        ),
        .executableTarget(
            name: "Diccct",
            dependencies: ["DiccctCore"],
            path: "Sources/Diccct",
            swiftSettings: [
                // Swift 5 language mode keeps the concurrency model pragmatic for
                // a small single-process UI app instead of forcing Swift 6
                // strict-concurrency annotations across every AppKit callback.
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "DiccctCoreTests",
            dependencies: ["DiccctCore"],
            path: "Tests/DiccctCoreTests"
        ),
    ]
)
