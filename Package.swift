// swift-tools-version: 6.0
import PackageDescription

// SaneDictCcDictionary is a menu-bar-only macOS app with zero third-party dependencies by
// design: only Apple's own Foundation / AppKit / SwiftUI are used.
//
// Layout:
//   - SaneDictCcDictionaryCore  : pure, UI-agnostic logic (dict.cc parsing, search index,
//                   data-directory scanning). Foundation-only, so it is fully
//                   unit-testable without spinning up AppKit.
//   - SaneDictCcDictionary      : the executable app shell (AppKit status item + non-activating
//                   floating NSPanel hosting the SwiftUI content). Depends on
//                   SaneDictCcDictionaryCore.
//
// The app makes itself an accessory (no Dock icon) at runtime via
// NSApplication.setActivationPolicy(.accessory), so it behaves as a proper
// menu-bar agent even when launched with `swift run`. scripts/build-app.sh
// wraps the built binary into a SaneDictCcDictionary.app bundle for normal use.
let package = Package(
    name: "SaneDictCcDictionary",
    platforms: [
        // macOS 14 floor: SwiftUI Grid, .textSelection, modern SwiftUI APIs.
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "SaneDictCcDictionaryCore",
            path: "Sources/SaneDictCcDictionaryCore"
        ),
        .executableTarget(
            name: "SaneDictCcDictionary",
            dependencies: ["SaneDictCcDictionaryCore"],
            path: "Sources/SaneDictCcDictionary",
            swiftSettings: [
                // Swift 5 language mode keeps the concurrency model pragmatic for
                // a small single-process UI app instead of forcing Swift 6
                // strict-concurrency annotations across every AppKit callback.
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SaneDictCcDictionaryCoreTests",
            dependencies: ["SaneDictCcDictionaryCore"],
            path: "Tests/SaneDictCcDictionaryCoreTests"
        ),
    ]
)
