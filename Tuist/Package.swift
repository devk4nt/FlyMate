// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [:],
    // Xcode 27 beta는 macOS 11 배포 타겟 미지원 — 매크로(SwiftSyntax 등) 타겟이 Mac에서 빌드되므로 상향
    baseSettings: .settings(
        base: ["MACOSX_DEPLOYMENT_TARGET": "13.0"],
        // 앱의 Staging 구성으로 빌드될 때 외부 패키지가 Release로 폴백하지 않도록 동일 구성 선언
        configurations: [
            .debug(name: .debug),
            .debug(name: "Staging"),
            .release(name: .release),
        ]
    )
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
