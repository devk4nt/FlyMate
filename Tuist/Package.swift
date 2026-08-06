// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings(
    productTypes: [:]
)
#endif

let package = Package(
    name: "FlyMateDependencies",
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "1.17.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.0.0"),
        .package(url: "https://github.com/kakao/kakao-ios-sdk.git", from: "2.23.0"),
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ]
)
