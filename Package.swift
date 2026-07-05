// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Qingniao",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Qingniao",
            targets: ["Qingniao"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "Qingniao",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Qingniao",
            exclude: [
                "App/QingniaoApp.swift",
                "Info.plist",
                "Qingniao.entitlements",
                "Resources/Assets.xcassets",
                "Resources/appcast.xml",
                "Resources/Localizable.xcstrings",
                "Services/ContentStore/ContentStore.swift",
                "Services/OCRService/OCRService.swift",
                "Services/SearchEngine/FileSearchSource.swift"
            ]
        ),
        .testTarget(
            name: "QingniaoTests",
            dependencies: ["Qingniao"],
            path: "QingniaoTests"
        )
    ]
)
