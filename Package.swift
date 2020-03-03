// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "pixlab",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "pixlab", targets: ["pixlab"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
        .package(url: "https://github.com/nicklockwood/Expression.git", .upToNextMinor(from: "0.12.0")),
        .package(url: "https://github.com/JohnSundell/ShellOut.git", from: "2.0.0"),
//        .package(url: "https://github.com/hexagons/LiveValues.git", from: "1.1.7"),
//        .package(url: "https://github.com/hexagons/RenderKit.git", from: "0.3.3"),
//        .package(url: "https://github.com/hexagons/PixelKit.git", from: "0.9.5"),
        .package(path: "~/Code/Frameworks/Production/LiveValues"),
        .package(path: "~/Code/Frameworks/Production/RenderKit"),
        .package(path: "~/Code/Frameworks/Production/PixelKit"),
//        .package(url: "https://github.com/hexagons/PIXLang.git", from: "0.1.0"),
        .package(path: "~/Code/Frameworks/Development/PIXLang"),
    ],
    targets: [
        .target(name: "pixlab", dependencies: [
            "LiveValues",
            "RenderKit",
            "PixelKit",
            "ArgumentParser",
            "Expression",
            "ShellOut",
            "PIXLang"
        ])
    ]
)
