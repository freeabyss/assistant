// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Assistant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SnapVault",
            targets: ["SnapVault"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SnapVault",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "SnapVault",
            exclude: [
                "App/SnapVaultApp.swift",
                "Info.plist",
                "SnapVault.entitlements",
                "Resources/Assets.xcassets",
                "Resources/appcast.xml",
                "Resources/Localizable.xcstrings",
                "Services/ContentStore/ContentStore.swift",
                "Services/OCRService/OCRService.swift",
                "Services/SearchEngine/FileSearchSource.swift"
            ]
        ),
        .testTarget(
            name: "SnapVaultTests",
            dependencies: ["SnapVault"],
            path: "SnapVaultTests"
        )
    ]
)
