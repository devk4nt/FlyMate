// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Presentation",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Presentation", targets: ["Presentation"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Core"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.17.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
        .package(url: "https://github.com/kakao/kakao-ios-sdk.git", from: "2.23.0"),
    ],
    targets: [
        .target(
            name: "Presentation",
            dependencies: [
                "Domain",
                "Core",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "Kingfisher",
                .product(name: "KakaoSDKCommon", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKAuth", package: "kakao-ios-sdk"),
                .product(name: "KakaoSDKUser", package: "kakao-ios-sdk"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PresentationTests",
            dependencies: [
                "Presentation",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
