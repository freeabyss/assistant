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
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.4.0")
    ],
    targets: [
        .target(
            name: "Qingniao",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Qingniao",
            exclude: [
                "App/QingniaoApp.swift",
                "Info.plist",
                "Qingniao.entitlements",
                "Resources/Assets.xcassets",
                "Resources/Localizable.xcstrings"
            ]
        ),
        .testTarget(
            name: "QingniaoTests",
            dependencies: ["Qingniao"],
            path: "QingniaoTests"
        )
    ]
)
