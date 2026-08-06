import ProjectDescription

// MARK: - Shared

let deploymentTargets: DeploymentTargets = .iOS("17.0")
let destinations: Destinations = [.iPhone, .iPad]

let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "DEVELOPMENT_TEAM": "",
    "CODE_SIGN_STYLE": "Automatic",
]

/// Packages/{name}/Sources/{name} 레이아웃의 모듈을 스태틱 프레임워크 타겟으로 정의한다.
func module(
    _ name: String,
    dependencies: [TargetDependency] = [],
    resources: ResourceFileElements? = nil
) -> Target {
    .target(
        name: name,
        destinations: destinations,
        product: .staticFramework,
        bundleId: "com.flymate.\(name.lowercased())",
        deploymentTargets: deploymentTargets,
        sources: ["Packages/\(name)/Sources/\(name)/**"],
        resources: resources,
        dependencies: dependencies
    )
}

/// 실제 Supabase 테스트 계정으로 로그인하는 디버그 스킴 (FlyMate-Test1~3)
func testAccountScheme(_ number: Int, email: String) -> Scheme {
    .scheme(
        name: "FlyMate-Test\(number)",
        shared: true,
        buildAction: .buildAction(targets: ["FlyMate"]),
        runAction: .runAction(
            configuration: .debug,
            executable: "FlyMate",
            arguments: .arguments(environmentVariables: [
                "TEST_EMAIL": .environmentVariable(value: email, isEnabled: true),
                "TEST_PASSWORD": .environmentVariable(value: "testpassword123", isEnabled: true),
            ])
        )
    )
}

// MARK: - Project

let project = Project(
    name: "FlyMate",
    settings: .settings(base: baseSettings),
    targets: [
        // MARK: 모듈 (Core → Domain → Data/Presentation 방향으로만 의존)
        module("Core"),
        module("Domain", dependencies: [
            .target(name: "Core"),
        ]),
        module("Data", dependencies: [
            .target(name: "Domain"),
            .target(name: "Core"),
            .external(name: "Supabase"),
        ]),
        module(
            "Presentation",
            dependencies: [
                .target(name: "Domain"),
                .target(name: "Core"),
                .external(name: "ComposableArchitecture"),
                .external(name: "Kingfisher"),
                .external(name: "KakaoSDKCommon"),
                .external(name: "KakaoSDKAuth"),
                .external(name: "KakaoSDKUser"),
            ],
            resources: ["Packages/Presentation/Sources/Presentation/Resources/**"]
        ),

        // MARK: 앱
        .target(
            name: "FlyMate",
            destinations: destinations,
            product: .app,
            bundleId: "com.flymate.app",
            deploymentTargets: deploymentTargets,
            infoPlist: .file(path: "FlyMate/Info.plist"),
            sources: ["FlyMate/**"],
            resources: [
                "Resources/**",
                "FlyMate/GoogleService-Info.plist",
            ],
            entitlements: "FlyMate/FlyMate.entitlements",
            dependencies: [
                .target(name: "Core"),
                .target(name: "Domain"),
                .target(name: "Data"),
                .target(name: "Presentation"),
                .external(name: "FirebaseCore"),
                .external(name: "FirebaseMessaging"),
            ],
            settings: .settings(
                base: baseSettings.merging([
                    "MARKETING_VERSION": "1.0.0",
                    "CURRENT_PROJECT_VERSION": "1",
                    "SWIFT_EMIT_LOC_STRINGS": true,
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                    "ENABLE_USER_SCRIPT_SANDBOXING": true,
                ]) { _, new in new },
                configurations: [
                    .debug(name: .debug, xcconfig: "Secrets.xcconfig"),
                    .release(name: .release, xcconfig: "Secrets.xcconfig"),
                ]
            )
        ),

        // MARK: 테스트
        .target(
            name: "FlyMateTests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "com.flymate.tests",
            deploymentTargets: deploymentTargets,
            sources: ["FlyMateTests/**"],
            dependencies: [
                .target(name: "FlyMate"),
            ]
        ),
        .target(
            name: "PresentationTests",
            destinations: destinations,
            product: .unitTests,
            bundleId: "com.flymate.presentationtests",
            deploymentTargets: deploymentTargets,
            sources: ["Packages/Presentation/Tests/PresentationTests/**"],
            dependencies: [
                .target(name: "Presentation"),
                .target(name: "Domain"),
                .target(name: "Core"),
                .external(name: "ComposableArchitecture"),
            ]
        ),
    ],
    schemes: [
        .scheme(
            name: "FlyMate",
            shared: true,
            buildAction: .buildAction(targets: ["FlyMate"]),
            testAction: .targets(
                ["FlyMateTests", "PresentationTests"],
                configuration: .debug
            ),
            runAction: .runAction(configuration: .debug, executable: "FlyMate"),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: "FlyMate"),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
        testAccountScheme(1, email: "test@flymate.app"),
        testAccountScheme(2, email: "test2@flymate.app"),
        testAccountScheme(3, email: "test3@flymate.app"),
    ]
)
