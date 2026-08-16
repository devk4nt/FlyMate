// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [:],
    // Xcode 27 beta는 macOS 11 배포 타겟 미지원 — 매크로(SwiftSyntax 등) 타겟이 Mac에서 빌드되므로 상향
    baseSettings: .settings(base: ["MACOSX_DEPLOYMENT_TARGET": "13.0"])
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
