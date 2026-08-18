import Foundation
import ProjectDescription

// MARK: - Shared

let deploymentTargets: DeploymentTargets = .iOS("17.0")
let destinations: Destinations = [.iPhone]

let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "6.0",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "DEVELOPMENT_LANGUAGE": "ko",
    "DEVELOPMENT_TEAM": "4Y2567YJY8",
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

/// 실제 Supabase 테스트 계정으로 로그인하는 디버그 스킴.
/// 계정 정보(이메일·비밀번호)는 커밋되지 않도록 tuist generate 시점의 환경변수에서 읽는다:
/// `TUIST_TEST_EMAIL_OWNER=<email> TUIST_TEST_PASSWORD=<pw> tuist generate` (mise.local.toml 참고)
func testAccountScheme(_ role: String, email: String) -> Scheme {
    let testPassword = Environment.testPassword.getString(default: "")
    return .scheme(
        name: "FlyMate-\(role)",
        shared: true,
        buildAction: .buildAction(targets: ["FlyMate"]),
        runAction: .runAction(
            configuration: .debug,
            executable: "FlyMate",
            arguments: .arguments(environmentVariables: [
                "TEST_EMAIL": .environmentVariable(value: email, isEnabled: true),
                "TEST_PASSWORD": .environmentVariable(value: testPassword, isEnabled: true),
            ])
        )
    )
}

// MARK: - Project

let project = Project(
    name: "FlyMate",
    options: .options(
        defaultKnownRegions: ["ko"],
        developmentRegion: "ko"
    ),
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
            scripts: [
                // Crashlytics dSYM 업로드 — 디버그(dwarf)는 dSYM이 없어 스크립트가 바로 종료됨
                .post(
                    script: #""${SRCROOT}/Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/run""#,
                    name: "Upload dSYMs to Crashlytics",
                    inputPaths: [
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}",
                        "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist",
                        "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist",
                        "${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}",
                    ],
                    basedOnDependencyAnalysis: false
                ),
            ],
            dependencies: [
                .target(name: "Core"),
                .target(name: "Domain"),
                .target(name: "Data"),
                .target(name: "Presentation"),
                .external(name: "FirebaseCore"),
                .external(name: "FirebaseMessaging"),
                .external(name: "FirebaseCrashlytics"),
            ],
            settings: .settings(
                base: baseSettings.merging([
                    "MARKETING_VERSION": "1.1",
                    "CURRENT_PROJECT_VERSION": "1",
                    "SWIFT_EMIT_LOC_STRINGS": true,
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                    // Crashlytics dSYM 업로드 스크립트가 네트워크/캐시 접근을 필요로 함
                    "ENABLE_USER_SCRIPT_SANDBOXING": false,
                    "OTHER_LDFLAGS": ["$(inherited)", "-ObjC"],
                    // 디버그 빌드도 dSYM 생성 — Crashlytics 테스트 크래시 심볼리케이션용
                    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
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
            name: "FlyMateUITests",
            destinations: destinations,
            product: .uiTests,
            bundleId: "com.flymate.uitests",
            deploymentTargets: deploymentTargets,
            sources: ["FlyMateUITests/**"],
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
                ["FlyMateTests", "PresentationTests", "FlyMateUITests"],
                configuration: .debug
            ),
            runAction: .runAction(configuration: .debug, executable: "FlyMate"),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release, executable: "FlyMate"),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
        // 다중 계정 시나리오용 실계정 스킴 — 시뮬레이터/기기 2대에 각각 띄워 크로스 계정 확인
        // Owner: 방장 계정 (스터디 생성·가입 승인·FCM 푸시 수신)
        testAccountScheme("Owner", email: Environment.testEmailOwner.getString(default: "")),
        // Member: 멤버 계정 (@멘션 알림 수신 확인용으로 추가)
        testAccountScheme("Member", email: Environment.testEmailMember.getString(default: "")),
        // Applicant: 가입 신청자 계정 (가입 승인 플로우 확인용으로 추가)
        testAccountScheme("Applicant", email: Environment.testEmailApplicant.getString(default: "")),
        // 방장 회원 탈퇴 시나리오 목 스킴 — 탈퇴 시 방장 승계(스터디 A→김하늘),
        // 혼자 방장인 스터디 삭제를 확인. 탈퇴 후 재로그인하면 결과 조회 가능
        .scheme(
            name: "FlyMate-OwnerDelete",
            shared: true,
            buildAction: .buildAction(targets: ["FlyMate"]),
            runAction: .runAction(
                configuration: .debug,
                executable: "FlyMate",
                arguments: .arguments(environmentVariables: [
                    "MOCK_OWNER_DELETE": .environmentVariable(value: "1", isEnabled: true),
                ])
            )
        ),
        // 앱 전역 Skeleton/Shimmer 시각 검수용 — 목 API 응답을 5초 지연한다.
        .scheme(
            name: "FlyMate-Loading",
            shared: true,
            buildAction: .buildAction(targets: ["FlyMate"]),
            runAction: .runAction(
                configuration: .debug,
                executable: "FlyMate",
                arguments: .arguments(environmentVariables: [
                    "MOCK_LOADING_DELAY_MS": .environmentVariable(value: "5000", isEnabled: true),
                ])
            )
        ),
        // 실기기에서 실제 로그인 플로우(Apple/카카오)로 진입하는 디버그 스킴
        .scheme(
            name: "FlyMate-Live",
            shared: true,
            buildAction: .buildAction(targets: ["FlyMate"]),
            runAction: .runAction(
                configuration: .debug,
                executable: "FlyMate",
                arguments: .arguments(environmentVariables: [
                    "LIVE_AUTH": .environmentVariable(value: "1", isEnabled: true),
                ])
            )
        ),
    ]
)
