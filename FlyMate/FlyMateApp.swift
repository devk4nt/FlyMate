@preconcurrency import SwiftUI
import StoreKit
import ComposableArchitecture
import Core
import Domain
import Presentation
import Data
import Foundation
import UserNotifications
import FirebaseMessaging

@main
struct FlyMateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let store: StoreOf<AppFeature>

    init() {
        self.store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            #if DEBUG
            if AppFeature.skipAuth {
                // 테스트 계정 스킴(FlyMate-Owner/Member/Applicant)은 실제 Supabase 세션으로 진입
                if let testEmail = ProcessInfo.processInfo.environment["TEST_EMAIL"] {
                    Self.registerLiveDependencies(&$0)
                    let supabaseClient = SupabaseClientProvider.shared.client
                    let testPassword = ProcessInfo.processInfo.environment["TEST_PASSWORD"] ?? "testpassword123"
                    $0.authClient.debugSignIn = {
                        try? await supabaseClient.auth.signOut()
                        _ = try await supabaseClient.auth.signIn(
                            email: testEmail,
                            password: testPassword
                        )
                    }
                } else {
                    // 기본 디버그 실행: 로그인 없이 목 데이터로 바로 진입
                    Self.registerMockDependencies(&$0)
                }
                return
            }
            #endif
            Self.registerLiveDependencies(&$0)
        }
    }

    private static func registerLiveDependencies(_ dependencies: inout DependencyValues) {
        let supabaseClient = SupabaseClientProvider.shared.client

        // Auth
        let authRepo = AuthRepositoryImpl(client: supabaseClient)
        dependencies.authClient = AuthClient(
            currentUser: { try await authRepo.currentUser() },
            signInWithApple: { try await authRepo.signInWithApple(idToken: $0, nonce: $1) },
            signInWithKakao: { try await authRepo.signInWithKakao(accessToken: $0) },
            signOut: { try await authRepo.signOut() },
            deleteAccount: { try await authRepo.deleteAccount(appleAuthorizationCode: $0) },
            observeAuthState: { authRepo.observeAuthState() }
        )

        // Study
        let studyRepo = StudyRepositoryImpl(client: supabaseClient)
        dependencies.studyClient = StudyClient(
            fetchMyStudies: { try await studyRepo.fetchMyStudies() },
            fetchStudy: { try await studyRepo.fetchStudy(id: $0) },
            createStudy: { try await studyRepo.createStudy($0) },
            requestJoinStudy: { try await studyRepo.requestJoinStudy(inviteCode: $0) },
            leaveStudy: { try await studyRepo.leaveStudy(id: $0) },
            deleteStudy: { try await studyRepo.deleteStudy(id: $0) },
            removeMember: { try await studyRepo.removeMember(studyID: $0, userID: $1) },
            transferOwnership: { try await studyRepo.transferOwnership(studyID: $0, newOwnerID: $1) },
            fetchInviteCodeInfo: { try await studyRepo.fetchInviteCodeInfo(code: $0) },
            updateNotice: { try await studyRepo.updateNotice(studyID: $0, notice: $1) },
            fetchPendingRequests: { try await studyRepo.fetchPendingRequests(studyID: $0) },
            approveJoinRequest: { try await studyRepo.approveJoinRequest(requestID: $0) },
            rejectJoinRequest: { try await studyRepo.rejectJoinRequest(requestID: $0) },
            cancelJoinRequest: { try await studyRepo.cancelJoinRequest(requestID: $0) },
            fetchMemberStats: { try await studyRepo.fetchMemberStats(studyID: $0, userID: $1) }
        )

        // Video
        let videoRepo = VideoRepositoryImpl(client: supabaseClient)
        dependencies.videoClient = VideoClient(
            fetchVideos: { try await videoRepo.fetchVideos(studyID: $0, cursor: $1) },
            fetchFeedVideos: { try await videoRepo.fetchFeedVideos(studyIDs: $0, cursor: $1) },
            fetchPendingFeedbackVideos: { try await videoRepo.fetchPendingFeedbackVideos(studyIDs: $0, userID: $1) },
            fetchVideo: { try await videoRepo.fetchVideo(id: $0) },
            uploadVideo: { try await videoRepo.uploadVideo($0, progress: $1) },
            deleteVideo: { try await videoRepo.deleteVideo(id: $0) }
        )

        // Feedback
        let feedbackRepo = FeedbackRepositoryImpl(client: supabaseClient)
        dependencies.feedbackClient = FeedbackClient(
            fetchFeedbacks: { try await feedbackRepo.fetchFeedbacks(videoID: $0) },
            createFeedback: { try await feedbackRepo.createFeedback($0) },
            fetchReceived: { try await feedbackRepo.fetchReceivedFeedbacks(userID: $0, cursor: $1) },
            fetchGiven: { try await feedbackRepo.fetchGivenFeedbacks(userID: $0, cursor: $1) },
            observeFeedbacks: { feedbackRepo.observeFeedbacks(videoID: $0) },
            deleteFeedback: { try await feedbackRepo.deleteFeedback(id: $0) }
        )

        // Feedback Comment
        let feedbackCommentRepo = FeedbackCommentRepositoryImpl(client: supabaseClient)
        dependencies.feedbackCommentClient = FeedbackCommentClient(
            fetchComments: { try await feedbackCommentRepo.fetchComments(feedbackID: $0) },
            fetchLatestComments: { try await feedbackCommentRepo.fetchLatestComments(feedbackIDs: $0) },
            createComment: { try await feedbackCommentRepo.createComment($0) },
            deleteComment: { try await feedbackCommentRepo.deleteComment(id: $0) }
        )

        // User
        let userRepo = UserRepositoryImpl(client: supabaseClient)
        dependencies.userClient = UserClient(
            fetchUser: { try await userRepo.fetchUser(id: $0) },
            updateProfile: { try await userRepo.updateProfile($0) },
            registerDeviceToken: { try await userRepo.registerDeviceToken($0) },
            removeDeviceToken: { try await userRepo.removeDeviceToken($0) },
            updateNotificationSettings: { try await userRepo.updateNotificationSettings(enabled: $0) },
            fetchMyActivityStats: { try await userRepo.fetchMyActivityStats() }
        )

        // Push Notification
        dependencies.pushNotificationClient = PushNotificationClient(
            requestAuthorization: {
                try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                )
            },
            getAuthorizationStatus: {
                await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            },
            registerForRemoteNotifications: {
                await UIApplication.shared.registerForRemoteNotifications()
            },
            observeFCMToken: {
                AsyncStream { continuation in
                    // 이미 발급된 토큰이 있으면 즉시 방출
                    if let existingToken = Messaging.messaging().fcmToken {
                        continuation.yield(existingToken)
                    }
                    let observer = NotificationCenter.default.addObserver(
                        forName: .fcmTokenReceived,
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let token = notification.userInfo?["token"] as? String {
                            continuation.yield(token)
                        }
                    }
                    continuation.onTermination = { @Sendable _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            },
            observePushNotificationTapped: {
                AsyncStream { continuation in
                    // Cold start 시 옵저버 등록 전에 유실된 페이로드를 즉시 방출
                    if let pending = AppDelegate.pendingPushPayload {
                        AppDelegate.pendingPushPayload = nil
                        continuation.yield(pending)
                    }
                    let observer = NotificationCenter.default.addObserver(
                        forName: .pushNotificationTapped,
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let payload = notification.userInfo?["payload"] as? [String: String] {
                            AppDelegate.pendingPushPayload = nil
                            continuation.yield(payload)
                        }
                    }
                    continuation.onTermination = { @Sendable _ in
                        NotificationCenter.default.removeObserver(observer)
                    }
                }
            }
        )

        // Notification
        let notificationRepo = NotificationRepositoryImpl(client: supabaseClient)
        dependencies.notificationClient = NotificationClient(
            fetchNotifications: { try await notificationRepo.fetchNotifications(userID: $0, cursor: $1) },
            fetchUnreadCount: { try await notificationRepo.fetchUnreadCount(userID: $0) },
            markAsRead: { try await notificationRepo.markAsRead(id: $0) },
            markAllAsRead: { try await notificationRepo.markAllAsRead(userID: $0) },
            observeNotifications: { notificationRepo.observeNotifications(userID: $0) }
        )

        // Report
        let reportRepo = ReportRepositoryImpl(client: supabaseClient)
        dependencies.reportClient = ReportClient(
            createReport: { try await reportRepo.createReport($0) },
            checkAlreadyReported: { try await reportRepo.checkAlreadyReported(targetType: $0, targetID: $1) }
        )

        // Block
        let blockRepo = BlockRepositoryImpl(client: supabaseClient)
        dependencies.blockClient = BlockClient(
            blockUser: { try await blockRepo.blockUser($0) },
            unblockUser: { try await blockRepo.unblockUser($0) },
            fetchBlockedUsers: { try await blockRepo.fetchBlockedUsers() }
        )

        // Recruit
        let recruitRepo = RecruitRepositoryImpl(client: supabaseClient)
        dependencies.recruitClient = RecruitClient(
            fetchPosts: { try await recruitRepo.fetchPosts(filter: $0, cursor: $1) },
            fetchPost: { try await recruitRepo.fetchPost(id: $0) },
            createPost: { try await recruitRepo.createPost($0) },
            updatePost: { try await recruitRepo.updatePost(id: $0, draft: $1) },
            closePost: { try await recruitRepo.closePost(id: $0) },
            reopenPost: { try await recruitRepo.reopenPost(id: $0, deadline: $1) },
            deletePost: { try await recruitRepo.deletePost(id: $0) },
            fetchComments: { try await recruitRepo.fetchComments(postID: $0) },
            createComment: { try await recruitRepo.createComment($0) },
            deleteComment: { try await recruitRepo.deleteComment(id: $0) }
        )

        // UserDefaults
        dependencies.userDefaultsClient = UserDefaultsClient(
            boolForKey: { UserDefaults.standard.bool(forKey: $0) },
            setBool: { value, key in UserDefaults.standard.set(value, forKey: key) }
        )

        // Subscription
        let subscriptionRepo = SubscriptionRepositoryImpl(client: supabaseClient)
        let storeKitService = StoreKitService()
        dependencies.subscriptionClient = SubscriptionClient(
            fetchEntitlements: { try await subscriptionRepo.fetchEntitlements(userID: $0) },
            fetchPlans: { try await subscriptionRepo.fetchPlans() },
            verifyReceipt: { try await subscriptionRepo.verifyReceipt($0) },
            checkFeatureLimit: { try await subscriptionRepo.checkFeatureLimit(userID: $0, feature: $1) },
            fetchProducts: { try await storeKitService.fetchProducts() },
            purchase: { try await storeKitService.purchase($0) },
            currentEntitlement: { await storeKitService.currentEntitlement() },
            observeTransactionUpdates: { storeKitService.observeTransactionUpdates() },
            restorePurchases: { try await storeKitService.restorePurchases() }
        )
    }

    #if DEBUG
    // MARK: - Mock Dependencies
    //
    // 시나리오: 승무원 지원자 "유나"는 국내·외항사 면접 스터디에서 영상을 주고받는다.
    // - 스터디 A: 멤버 4명, 영상 4개(내 영상 2 + 팀원 영상 2), 가입 대기 요청 1건
    // - 스터디 B: 멤버 3명, 영상 2개(내 영상 1 + 방장 영상 1)
    // - 피드백 14개(요청 응답·칭찬·지적·질문·멘션 등 상황별), 댓글 5개, 알림 4종
    // - 모든 영상에 촬영 포인트/피드백 요청 포함 — 시트 상단에 업로더 요구사항 노출
    // 생성/삭제는 LockIsolated 스토어에 반영되어 세션 내에서 지속된다.
    private static func registerMockDependencies(_ dependencies: inout DependencyValues) {
        let now = Date()
        let day: TimeInterval = 86_400
        let hour: TimeInterval = 3_600
        let loadingDelayMilliseconds = Int(
            ProcessInfo.processInfo.environment["MOCK_LOADING_DELAY_MS"] ?? "0"
        ) ?? 0

        @Sendable func simulateLoading() async throws {
            guard loadingDelayMilliseconds > 0 else { return }
            try await Task.sleep(for: .milliseconds(loadingDelayMilliseconds))
        }

        // 재현 가능한 고정 UUID (suffix로 구분: 1x 유저, 0x 스터디, 2x 멤버십, 1xx 영상, 2xx 피드백, 3xx 알림, 4xx 댓글, 5xx 가입요청)
        @Sendable func uuid(_ suffix: Int) -> UUID {
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
        }

        // 실제 재생 가능한 공개 샘플 영상 (플레이어/타임스탬프 이동 테스트용)
        @Sendable func sampleVideoURL(_ urlString: String) -> URL {
            URL(string: urlString)!
        }
        @Sendable func mockAssetURL(_ name: String) -> URL? {
            Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "MockThumbnails")
                ?? Bundle.main.url(forResource: name, withExtension: "jpg")
        }
        @Sendable func sampleThumbnailURL(_ suffix: Int) -> URL? {
            let assetName = switch suffix {
            case 100, 102, 104, 106: "flight-attendant-study-cafe"
            default: "flight-attendant-home-webcam"
            }
            return mockAssetURL(assetName)
        }
        // 항상 실제 재생 가능한 샘플 영상 사용 — 정지 이미지 목 영상은 심사에서 미완성으로 보일 수 있음
        @Sendable func mockVideoURL(_ assetName: String, fallback: String) -> URL {
            sampleVideoURL(fallback)
        }
        // ~10분짜리 장편 샘플 — 3분 내 타임스탬프 이동 모두 커버
        let bigBuckBunny = "https://archive.org/download/BigBuckBunny_124/Content/big_buck_bunny_720p_surround.mp4"
        let elephantsDream = "https://archive.org/download/ElephantsDream/ed_1024_512kb.mp4"
        let bipbopHLS = "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
        // ~52초 단편 샘플
        let sintelTrailer = "https://media.w3.org/2010/05/sintel/trailer.mp4"
        let sintelTrailer720 = "https://download.blender.org/durian/trailer/sintel_trailer-720p.mp4"

        // MARK: Users
        let meID = uuid(10)
        let haneulID = uuid(11)   // 김하늘 — 스터디 B 방장
        let seoyeonID = uuid(12)  // 박서연
        let minjunID = uuid(13)   // 이민준
        let jiwooID = uuid(14)    // 최지우 — 스터디 A 가입 대기

        let me = User(
            id: meID,
            email: "preview@flymate.app",
            name: "유나",
            provider: .apple,
            createdAt: now.addingTimeInterval(-90 * day)
        )

        // MARK: Studies
        let studyA = Study(
            id: uuid(1),
            name: "승무원 영상면접 스터디",
            description: "국내·외항사 승무원 영상면접을 함께 준비해요",
            ownerID: meID,
            inviteCode: "FLY123",
            maxMembers: 6,
            members: [
                StudyMember(id: uuid(21), userID: meID, userName: "유나", role: .owner, joinedAt: now.addingTimeInterval(-60 * day)),
                StudyMember(id: uuid(22), userID: haneulID, userName: "김하늘", role: .member, joinedAt: now.addingTimeInterval(-50 * day)),
                StudyMember(id: uuid(23), userID: seoyeonID, userName: "박서연", role: .member, joinedAt: now.addingTimeInterval(-45 * day)),
                StudyMember(id: uuid(24), userID: minjunID, userName: "이민준", role: .member, joinedAt: now.addingTimeInterval(-20 * day)),
            ],
            createdAt: now.addingTimeInterval(-60 * day),
            notice: "매주 화·목 저녁 9시까지 영상 업로드하고, 서로 피드백 2개 이상 남겨주세요!",
            noticeUpdatedAt: now.addingTimeInterval(-2 * day)
        )

        let studyB = Study(
            id: uuid(2),
            name: "외항사 영어면접 스터디",
            description: "영어 자기소개와 상황대처 답변 집중 훈련",
            ownerID: haneulID,
            inviteCode: "ANN456",
            maxMembers: 8,
            members: [
                StudyMember(id: uuid(25), userID: haneulID, userName: "김하늘", role: .owner, joinedAt: now.addingTimeInterval(-80 * day)),
                StudyMember(id: uuid(26), userID: meID, userName: "유나", role: .member, joinedAt: now.addingTimeInterval(-40 * day)),
                StudyMember(id: uuid(27), userID: jiwooID, userName: "최지우", role: .member, joinedAt: now.addingTimeInterval(-15 * day)),
            ],
            createdAt: now.addingTimeInterval(-80 * day),
            notice: "영어 답변 영상은 2분 이내로 올려주세요."
        )

        // 미가입 스터디 — 초대코드 "CRW789" 입력으로 가입 요청 시나리오 테스트용
        let studyC = Study(
            id: uuid(3),
            name: "외항사 승무원 준비반",
            description: "에미레이트·카타르 등 외항사 영어면접 집중 대비",
            ownerID: jiwooID,
            inviteCode: "CRW789",
            maxMembers: 8,
            members: [
                StudyMember(id: uuid(28), userID: jiwooID, userName: "최지우", role: .owner, joinedAt: now.addingTimeInterval(-30 * day)),
                StudyMember(id: uuid(29), userID: minjunID, userName: "이민준", role: .member, joinedAt: now.addingTimeInterval(-10 * day)),
            ],
            createdAt: now.addingTimeInterval(-30 * day),
            notice: "영어 답변 영상 위주로 올려주세요."
        )

        // FlyMate-OwnerDelete 스킴: 방장 회원 탈퇴 시나리오.
        // 혼자 방장인 스터디를 추가해 탈퇴 시 두 케이스를 모두 확인한다:
        // studyA → 가장 오래된 멤버(김하늘)에게 방장 승계, 혼자 연습방 → 삭제
        let soloStudy = Study(
            id: uuid(4),
            name: "혼자 연습방",
            description: "방장 혼자인 스터디 — 탈퇴 시 삭제되는 케이스",
            ownerID: meID,
            inviteCode: "SOLO01",
            maxMembers: 4,
            members: [
                StudyMember(id: uuid(30), userID: meID, userName: "유나", role: .owner, joinedAt: now.addingTimeInterval(-7 * day)),
            ],
            createdAt: now.addingTimeInterval(-7 * day)
        )
        let ownerDeleteScenario = ProcessInfo.processInfo.environment["MOCK_OWNER_DELETE"] == "1"
        let initialStudies = ownerDeleteScenario ? [studyA, studyB, soloStudy] : [studyA, studyB]

        let studyStore = LockIsolated(initialStudies)

        // MARK: Videos
        let videos: [Video] = [
            Video(
                id: uuid(100), studyID: studyA.id, uploaderID: meID, uploaderName: "유나",
                title: "기내 안전 안내 롤플레이",
                videoURL: mockVideoURL("flight-attendant-study-cafe", fallback: bigBuckBunny), thumbnailURL: sampleThumbnailURL(100),
                durationSeconds: 178, feedbackCount: 4,
                focusPoints: "발음, 시선 처리",
                feedbackRequest: "미소가 어색하지 않은지 봐주세요!",
                createdAt: now.addingTimeInterval(-3 * day)
            ),
            Video(
                id: uuid(101), studyID: studyA.id, uploaderID: meID, uploaderName: "유나",
                title: "1분 자기소개 스피치",
                videoURL: mockVideoURL("flight-attendant-home-webcam", fallback: sintelTrailer), thumbnailURL: sampleThumbnailURL(101),
                durationSeconds: 52, feedbackCount: 3,
                focusPoints: "목소리 톤, 말 속도",
                feedbackRequest: "1분 안에 핵심이 다 전달되는지 봐주세요",
                createdAt: now.addingTimeInterval(-1 * day)
            ),
            Video(
                id: uuid(102), studyID: studyA.id, uploaderID: seoyeonID, uploaderName: "박서연",
                title: "영어 기내방송 연습",
                videoURL: mockVideoURL("flight-attendant-study-cafe", fallback: elephantsDream), thumbnailURL: sampleThumbnailURL(102),
                durationSeconds: 145, feedbackCount: 2,
                focusPoints: "영어 발음과 억양",
                feedbackRequest: "R/L 발음이 명확하게 구분되는지 들어봐 주세요",
                createdAt: now.addingTimeInterval(-2 * day)
            ),
            Video(
                id: uuid(103), studyID: studyA.id, uploaderID: minjunID, uploaderName: "이민준",
                title: "돌발질문 대처 — 컴플레인 응대",
                videoURL: mockVideoURL("flight-attendant-home-webcam", fallback: bipbopHLS), thumbnailURL: sampleThumbnailURL(103),
                durationSeconds: 170, feedbackCount: 1,
                focusPoints: "돌발 상황 대처, 침착함",
                feedbackRequest: "화난 승객 응대할 때 목소리 톤이 방어적으로 들리는지 봐주세요",
                createdAt: now.addingTimeInterval(-5 * hour)
            ),
            Video(
                id: uuid(104), studyID: studyB.id, uploaderID: meID, uploaderName: "유나",
                title: "영어 자기소개 — Why cabin crew?",
                videoURL: mockVideoURL("flight-attendant-study-cafe", fallback: bigBuckBunny), thumbnailURL: sampleThumbnailURL(104),
                durationSeconds: 120, feedbackCount: 1,
                focusPoints: "영어 발음, 지원 동기 전달력",
                feedbackRequest: "지원 동기가 진부하게 들리지 않는지 솔직하게 말해주세요",
                createdAt: now.addingTimeInterval(-4 * day)
            ),
            Video(
                id: uuid(105), studyID: studyB.id, uploaderID: haneulID, uploaderName: "김하늘",
                title: "외항사 면접 — 서비스 경험 답변",
                videoURL: mockVideoURL("flight-attendant-home-webcam", fallback: sintelTrailer720), thumbnailURL: sampleThumbnailURL(105),
                durationSeconds: 52, feedbackCount: 1,
                focusPoints: "STAR 답변 구조",
                feedbackRequest: "결과(R) 파트가 약한 것 같은데 어떻게 보강하면 좋을까요?",
                createdAt: now.addingTimeInterval(-6 * hour)
            ),
            // 유나(나)가 아직 피드백하지 않은 영상 — 피드백 대기 큐 시나리오용
            Video(
                id: uuid(106), studyID: studyA.id, uploaderID: seoyeonID, uploaderName: "박서연",
                title: "한국어 기내방송 — 이륙 안내",
                videoURL: mockVideoURL("flight-attendant-study-cafe", fallback: sintelTrailer), thumbnailURL: sampleThumbnailURL(106),
                durationSeconds: 48, feedbackCount: 1,
                focusPoints: "톤 안정성, 속도",
                feedbackRequest: "이륙 안내 파트 속도가 적당한지 봐주세요",
                createdAt: now.addingTimeInterval(-8 * hour)
            ),
            Video(
                id: uuid(107), studyID: studyB.id, uploaderID: jiwooID, uploaderName: "최지우",
                title: "영어 상황면접 — 지연 승객 안내",
                videoURL: mockVideoURL("flight-attendant-home-webcam", fallback: sintelTrailer720), thumbnailURL: sampleThumbnailURL(107),
                durationSeconds: 55, feedbackCount: 1,
                focusPoints: "영어 표현, 상황 대처",
                feedbackRequest: "지연 안내 표현이 자연스러운지 봐주세요",
                createdAt: now.addingTimeInterval(-2 * hour)
            ),
        ]
        let videoStore = LockIsolated(videos)
        let myVideoIDs = Set(videos.filter { $0.uploaderID == meID }.map(\.id))

        // MARK: Feedbacks
        // 상황별 다양화: 업로더 요청에 직접 응답 / 칭찬 / 개선 지적 / 질문·제안 / 멘션
        let feedbackStore = MockFeedbackStore(initialFeedbacks: [
            // 영상 100 — 기내 안전 안내 (내 영상, 요청: 미소가 어색하지 않은지)
            Feedback(
                id: uuid(200), videoID: uuid(100), studyID: studyA.id, authorID: haneulID, authorName: "김하늘",
                content: "요청하신 미소 위주로 봤어요 — 도입부 인사는 정말 자연스러워요. 긴장한 티가 하나도 안 나요 😊",
                timestampSeconds: 12, createdAt: now.addingTimeInterval(-2 * day), commentCount: 2
            ),
            Feedback(
                id: uuid(210), videoID: uuid(100), studyID: studyA.id, authorID: haneulID, authorName: "김하늘",
                content: "안전벨트 시연 파트는 손동작을 좀 더 크게 하는 건 어떨까요? 카메라에 잘 안 잡혀요.",
                timestampSeconds: 55, createdAt: now.addingTimeInterval(-2 * day + 3 * hour)
            ),
            Feedback(
                id: uuid(201), videoID: uuid(100), studyID: studyA.id, authorID: seoyeonID, authorName: "박서연",
                content: "산소마스크 안내에서 말이 빨라지면서 미소도 같이 사라져요. 한 박자 쉬면 표정도 돌아올 거예요.",
                timestampSeconds: 95, createdAt: now.addingTimeInterval(-1 * day),
                mentionedUserIDs: [meID], commentCount: 1
            ),
            Feedback(
                id: uuid(202), videoID: uuid(100), studyID: studyA.id, authorID: minjunID, authorName: "이민준",
                content: "마무리 인사에서 시선이 카메라 아래로 떨어지네요. 끝까지 렌즈 보면서 미소 유지해 주세요!",
                timestampSeconds: 168, createdAt: now.addingTimeInterval(-20 * hour)
            ),
            // 영상 101 — 1분 자기소개 (내 영상, 요청: 1분 안에 핵심 전달되는지)
            Feedback(
                id: uuid(211), videoID: uuid(101), studyID: studyA.id, authorID: minjunID, authorName: "이민준",
                content: "첫인사 목소리 톤이 밝아서 바로 집중돼요. 도입부는 이대로 가시죠!",
                timestampSeconds: 5, createdAt: now.addingTimeInterval(-19 * hour)
            ),
            Feedback(
                id: uuid(203), videoID: uuid(101), studyID: studyA.id, authorID: haneulID, authorName: "김하늘",
                content: "요청하신 전달력 기준으로는, 지원 동기까지 완벽하게 들어와요. 다만 강점 소개가 30초를 넘겨서 뒤가 급해져요.",
                timestampSeconds: 18, createdAt: now.addingTimeInterval(-18 * hour)
            ),
            Feedback(
                id: uuid(204), videoID: uuid(101), studyID: studyA.id, authorID: seoyeonID, authorName: "박서연",
                content: "끝맺음이 살짝 급하게 끝나는 느낌이에요. \"감사합니다\" 앞에서 호흡 한 번!",
                timestampSeconds: 45, createdAt: now.addingTimeInterval(-10 * hour)
            ),
            // 영상 102 — 영어 기내방송 (박서연 영상, 요청: R/L 발음 구분, 내가 남긴 피드백 포함)
            Feedback(
                id: uuid(205), videoID: uuid(102), studyID: studyA.id, authorID: meID, authorName: "유나",
                content: "요청하신 R/L 체크했어요 — Ladies and gentlemen에서 이제 확실히 구분돼요! 쉐도잉 효과 보이네요.",
                timestampSeconds: 30, createdAt: now.addingTimeInterval(-1 * day), commentCount: 1
            ),
            Feedback(
                id: uuid(206), videoID: uuid(102), studyID: studyA.id, authorID: minjunID, authorName: "이민준",
                content: "착륙 안내 문장 간격이 일정해서 듣기 편했어요. 다만 landing이 '랜딩'처럼 들리는 순간이 한 번 있어요.",
                timestampSeconds: 110, createdAt: now.addingTimeInterval(-15 * hour)
            ),
            // 영상 103 — 돌발질문 대처 (이민준 영상, 요청: 톤이 방어적으로 들리는지)
            Feedback(
                id: uuid(207), videoID: uuid(103), studyID: studyA.id, authorID: meID, authorName: "유나",
                content: "걱정하신 방어적인 톤은 전혀 아니에요! 공감 표현을 먼저 한 게 좋았고, 해결책 제시 순서도 깔끔해요.",
                timestampSeconds: 45, createdAt: now.addingTimeInterval(-3 * hour)
            ),
            // 영상 104 — 영어 자기소개 (내 영상, 스터디 B, 요청: 지원 동기가 진부하지 않은지)
            Feedback(
                id: uuid(208), videoID: uuid(104), studyID: studyB.id, authorID: haneulID, authorName: "김하늘",
                content: "솔직 피드백 원하셨죠 — since I was young 도입은 조금 흔해요. 승무원 서비스를 직접 경험한 비행 이야기로 시작하면 훨씬 강렬할 것 같아요.",
                timestampSeconds: 60, createdAt: now.addingTimeInterval(-3 * day), commentCount: 1
            ),
            // 영상 105 — 서비스 경험 답변 (김하늘 영상, 스터디 B, 요청: 결과 파트 보강법)
            Feedback(
                id: uuid(209), videoID: uuid(105), studyID: studyB.id, authorID: meID, authorName: "유나",
                content: "상황·행동은 명확해요! 고민하신 결과 파트는 \"내리시면서 감사 인사를 하셨다\" 같은 구체적인 장면 하나만 붙이면 살 것 같아요.",
                timestampSeconds: 20, createdAt: now.addingTimeInterval(-2 * hour)
            ),
            // 영상 106 — 이륙 안내 (박서연 영상, 요청: 속도가 적당한지 — 내 피드백 없음, 대기 큐 유지)
            Feedback(
                id: uuid(212), videoID: uuid(106), studyID: studyA.id, authorID: minjunID, authorName: "이민준",
                content: "물어보신 속도는 딱 좋아요. 오히려 후반부가 살짝 느려지는데, 처음 페이스를 끝까지 유지하면 완벽!",
                timestampSeconds: 15, createdAt: now.addingTimeInterval(-6 * hour)
            ),
            // 영상 107 — 지연 승객 안내 (최지우 영상, 요청: 지연 안내 표현 — 내 피드백 없음, 대기 큐 유지)
            Feedback(
                id: uuid(213), videoID: uuid(107), studyID: studyB.id, authorID: haneulID, authorName: "김하늘",
                content: "We apologize for the inconvenience 억양이 자연스러워요. 다만 지연 사유 설명이 길어서 핵심만 남겨도 될 것 같아요.",
                timestampSeconds: 25, createdAt: now.addingTimeInterval(-1 * hour)
            ),
        ])

        // MARK: Comments
        let commentStore = LockIsolated<[FeedbackComment]>([
            FeedbackComment(
                id: uuid(400), feedbackID: uuid(200), studyID: studyA.id, authorID: meID, authorName: "유나",
                content: "감사합니다! 미소는 거울 보면서 연습한 보람이 있네요 😊",
                createdAt: now.addingTimeInterval(-2 * day + hour)
            ),
            FeedbackComment(
                id: uuid(401), feedbackID: uuid(200), studyID: studyA.id, authorID: haneulID, authorName: "김하늘",
                content: "@유나 다음 영상도 기대할게요!",
                mentionedUserIDs: [meID],
                createdAt: now.addingTimeInterval(-2 * day + 2 * hour)
            ),
            FeedbackComment(
                id: uuid(402), feedbackID: uuid(201), studyID: studyA.id, authorID: meID, authorName: "유나",
                content: "맞아요, 그 파트만 가면 긴장해서 빨라지더라고요. 다시 찍어볼게요!",
                createdAt: now.addingTimeInterval(-20 * hour)
            ),
            FeedbackComment(
                id: uuid(403), feedbackID: uuid(205), studyID: studyA.id, authorID: seoyeonID, authorName: "박서연",
                content: "@유나 님이 알려주신 쉐도잉 방법 덕분이에요. 감사합니다!",
                mentionedUserIDs: [meID],
                createdAt: now.addingTimeInterval(-12 * hour)
            ),
            FeedbackComment(
                id: uuid(404), feedbackID: uuid(208), studyID: studyB.id, authorID: meID, authorName: "유나",
                content: "역시 뻔했군요 😅 비행 경험 이야기로 다시 써볼게요. 솔직한 피드백 감사해요!",
                createdAt: now.addingTimeInterval(-3 * day + 2 * hour)
            ),
        ])

        // MARK: Notifications
        let notificationStore = LockIsolated<[AppNotification]>([
            AppNotification(
                id: uuid(300), recipientID: meID, type: .feedbackOnMyVideo,
                title: "새 피드백이 달렸어요",
                body: "이민준님이 \"기내 안전 안내 롤플레이\" 영상에 피드백을 남겼습니다.",
                referenceVideoID: uuid(100), referenceFeedbackID: uuid(202),
                isRead: false, createdAt: now.addingTimeInterval(-20 * hour)
            ),
            AppNotification(
                id: uuid(301), recipientID: meID, type: .replyOnMyFeedback,
                title: "내 피드백에 답글이 달렸어요",
                body: "박서연님이 회원님의 피드백에 답글을 남겼습니다.",
                referenceVideoID: uuid(102), referenceFeedbackID: uuid(205),
                isRead: false, createdAt: now.addingTimeInterval(-12 * hour)
            ),
            AppNotification(
                id: uuid(302), recipientID: meID, type: .mentionedInFeedback,
                title: "피드백에서 태그되었어요",
                body: "박서연님이 피드백에서 회원님을 태그했습니다.",
                referenceVideoID: uuid(100), referenceFeedbackID: uuid(201),
                isRead: true, createdAt: now.addingTimeInterval(-1 * day)
            ),
            AppNotification(
                id: uuid(303), recipientID: meID, type: .mentionedInFeedbackComment,
                title: "답글에서 태그되었어요",
                body: "김하늘님이 답글에서 회원님을 태그했습니다.",
                referenceVideoID: uuid(100), referenceFeedbackID: uuid(200),
                isRead: true, createdAt: now.addingTimeInterval(-2 * day + 2 * hour)
            ),
        ])

        // MARK: Join Requests (스터디 A 방장 시나리오용)
        let joinRequestStore = LockIsolated<[JoinRequest]>([
            JoinRequest(
                id: uuid(500), studyID: studyA.id, studyName: studyA.name,
                userID: jiwooID, userName: "최지우",
                status: .pending, createdAt: now.addingTimeInterval(-5 * hour)
            ),
        ])

        let memberStats: [UUID: (given: Int, received: Int, videos: Int)] = [
            meID: (given: 3, received: 8, videos: 3),
            haneulID: (given: 5, received: 1, videos: 1),
            seoyeonID: (given: 2, received: 3, videos: 2),
            minjunID: (given: 4, received: 1, videos: 1),
            jiwooID: (given: 0, received: 1, videos: 1),
        ]

        // MARK: Client 등록

        // Auth
        // 로그인 성공은 observeAuthState 재방출로 앱에 전파되므로 continuation을 보관한다
        // (탈퇴 → 로그인 화면 → 재로그인으로 승계 결과를 확인하는 플로우 지원)
        let authObserver = LockIsolated<AsyncStream<User?>.Continuation?>(nil)
        dependencies.authClient = AuthClient(
            currentUser: { me },
            signInWithApple: { _, _ in
                authObserver.value?.yield(me)
                return me
            },
            signInWithKakao: { _ in
                authObserver.value?.yield(me)
                return me
            },
            signOut: {},
            deleteAccount: { _ in
                // 서버 remove_user_content_all_studies의 방장 승계 시뮬레이션:
                // 소유 스터디는 가장 오래된 멤버에게 승계, 남은 멤버가 없으면 삭제
                studyStore.withValue { studies in
                    for index in studies.indices.reversed() where studies[index].ownerID == meID {
                        let successor = studies[index].members
                            .filter { $0.userID != meID }
                            .min { $0.joinedAt < $1.joinedAt }
                        if let successor {
                            studies[index].ownerID = successor.userID
                            for memberIndex in studies[index].members.indices {
                                studies[index].members[memberIndex].role =
                                    studies[index].members[memberIndex].userID == successor.userID ? .owner : .member
                            }
                        } else {
                            studies.remove(at: index)
                        }
                    }
                    for index in studies.indices {
                        studies[index].members.removeAll { $0.userID == meID }
                    }
                }
            },
            observeAuthState: {
                AsyncStream { continuation in
                    authObserver.setValue(continuation)
                    continuation.yield(me)
                }
            }
        )

        // Apple 재인증 (회원 탈퇴 시 revoke용 authorization code) — 실제 시트 없이 즉시 성공
        dependencies.appleSignInClient = AppleSignInClient(
            signIn: {
                AppleSignInResult(
                    idToken: "mock-id-token",
                    nonce: "mock-nonce",
                    fullName: nil,
                    email: nil,
                    authorizationCode: "mock-authorization-code"
                )
            }
        )

        // Study
        dependencies.studyClient = StudyClient(
            fetchMyStudies: {
                try await simulateLoading()
                return studyStore.value
            },
            fetchStudy: { id in
                try await simulateLoading()
                return studyStore.value.first { $0.id == id } ?? studyA
            },
            createStudy: { request in
                let study = Study(
                    id: UUID(),
                    name: request.name,
                    description: request.description,
                    ownerID: meID,
                    inviteCode: "NEW123",
                    maxMembers: request.maxMembers,
                    members: [
                        StudyMember(id: UUID(), userID: meID, userName: me.name, role: .owner, joinedAt: Date())
                    ],
                    createdAt: Date()
                )
                studyStore.withValue { $0.append(study) }
                return study
            },
            requestJoinStudy: { code in
                if studyStore.value.contains(where: { $0.inviteCode == code }) {
                    throw AppError.business(.alreadyJoined)
                }
                guard code == studyC.inviteCode else {
                    throw AppError.business(.invalidInviteCode)
                }
                // 3초 뒤 방장(최지우)이 승인한 것처럼 내 스터디 목록에 추가
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    studyStore.withValue { studies in
                        guard !studies.contains(where: { $0.id == studyC.id }) else { return }
                        var joined = studyC
                        joined.members.append(
                            StudyMember(id: UUID(), userID: meID, userName: me.name, role: .member, joinedAt: Date())
                        )
                        studies.append(joined)
                    }
                }
                return JoinRequest(
                    id: UUID(), studyID: studyC.id, studyName: studyC.name,
                    userID: meID, userName: me.name,
                    status: .pending, createdAt: Date()
                )
            },
            leaveStudy: { id in studyStore.withValue { $0.removeAll { $0.id == id } } },
            deleteStudy: { id in studyStore.withValue { $0.removeAll { $0.id == id } } },
            removeMember: { studyID, userID in
                studyStore.withValue { studies in
                    guard let index = studies.firstIndex(where: { $0.id == studyID }) else { return }
                    studies[index].members.removeAll { $0.userID == userID }
                }
            },
            transferOwnership: { studyID, newOwnerID in
                studyStore.withValue { studies in
                    guard let index = studies.firstIndex(where: { $0.id == studyID }) else { return }
                    studies[index].ownerID = newOwnerID
                    for memberIndex in studies[index].members.indices {
                        studies[index].members[memberIndex].role =
                            studies[index].members[memberIndex].userID == newOwnerID ? .owner : .member
                    }
                }
            },
            fetchInviteCodeInfo: { code in
                guard let study = (studyStore.value + [studyC]).first(where: { $0.inviteCode == code }) else {
                    throw AppError.business(.invalidInviteCode)
                }
                return InviteCode(
                    code: code,
                    studyID: study.id,
                    studyName: study.name,
                    createdAt: now,
                    expiresAt: now.addingTimeInterval(7 * day),
                    isActive: true
                )
            },
            updateNotice: { studyID, notice in
                studyStore.withValue { studies in
                    guard let index = studies.firstIndex(where: { $0.id == studyID }) else { return }
                    studies[index].notice = notice
                    studies[index].noticeUpdatedAt = Date()
                }
            },
            fetchPendingRequests: { studyID in
                try await simulateLoading()
                return joinRequestStore.value.filter { $0.studyID == studyID }
            },
            approveJoinRequest: { requestID in
                guard let request = joinRequestStore.value.first(where: { $0.id == requestID }) else { return }
                joinRequestStore.withValue { $0.removeAll { $0.id == requestID } }
                studyStore.withValue { studies in
                    guard let index = studies.firstIndex(where: { $0.id == request.studyID }) else { return }
                    studies[index].members.append(
                        StudyMember(id: UUID(), userID: request.userID, userName: request.userName, role: .member, joinedAt: Date())
                    )
                }
            },
            rejectJoinRequest: { requestID in
                joinRequestStore.withValue { $0.removeAll { $0.id == requestID } }
            },
            cancelJoinRequest: { requestID in
                joinRequestStore.withValue { $0.removeAll { $0.id == requestID } }
            },
            fetchMemberStats: { studyID, userID in
                try await simulateLoading()
                let stats = memberStats[userID] ?? (given: 0, received: 0, videos: 0)
                return MemberStats(
                    userID: userID,
                    studyID: studyID,
                    feedbackGivenCount: stats.given,
                    feedbackReceivedCount: stats.received,
                    videosUploadedCount: stats.videos,
                    joinedAt: now.addingTimeInterval(-40 * day)
                )
            }
        )

        // Video
        let uploadedVideoURL = sampleVideoURL(sintelTrailer)
        let uploadedThumbnailURL = sampleThumbnailURL(999)
        dependencies.videoClient = VideoClient(
            fetchVideos: { studyID, _ in
                try await simulateLoading()
                // ponytail: 커서 무시 — 목 데이터는 단일 페이지
                return videoStore.value
                    .filter { $0.studyID == studyID }
                    .sorted { $0.createdAt > $1.createdAt }
            },
            fetchFeedVideos: { studyIDs, cursor in
                try await simulateLoading()
                // ponytail: 커서 무시 — 목 데이터는 단일 페이지
                guard cursor == nil else { return [] }
                return videoStore.value
                    .filter { studyIDs.contains($0.studyID) }
                    .sorted { $0.createdAt > $1.createdAt }
            },
            fetchPendingFeedbackVideos: { studyIDs, userID in
                try await simulateLoading()
                let completedVideoIDs = Set(
                    feedbackStore.all().filter { $0.authorID == userID }.map(\.videoID)
                )
                return videoStore.value
                    .filter {
                        studyIDs.contains($0.studyID)
                            && $0.uploaderID != userID
                            && !completedVideoIDs.contains($0.id)
                    }
                    .sorted { $0.createdAt < $1.createdAt }
            },
            fetchVideo: { id in
                try await simulateLoading()
                return videoStore.value.first { $0.id == id } ?? videos[0]
            },
            uploadVideo: { request, progress in
                for step in [0.25, 0.5, 0.75, 1.0] as [Double] {
                    try await Task.sleep(for: .milliseconds(300))
                    progress(step)
                }
                let video = Video(
                    id: UUID(),
                    studyID: request.studyID,
                    uploaderID: meID,
                    uploaderName: me.name,
                    title: request.title,
                    videoURL: uploadedVideoURL,
                    thumbnailURL: uploadedThumbnailURL,
                    durationSeconds: request.durationSeconds,
                    focusPoints: request.focusPoints,
                    feedbackRequest: request.feedbackRequest,
                    createdAt: Date()
                )
                videoStore.withValue { $0.insert(video, at: 0) }
                return video
            },
            deleteVideo: { id in videoStore.withValue { $0.removeAll { $0.id == id } } }
        )

        // Feedback
        dependencies.feedbackClient = FeedbackClient(
            fetchFeedbacks: { videoID in
                try await simulateLoading()
                return feedbackStore.feedbacks(for: videoID)
            },
            createFeedback: { request in
                let feedback = Feedback(
                    id: UUID(),
                    videoID: request.videoID,
                    studyID: videoStore.value.first { $0.id == request.videoID }?.studyID ?? studyA.id,
                    authorID: meID,
                    authorName: me.name,
                    content: request.content,
                    timestampSeconds: request.timestampSeconds,
                    createdAt: Date(),
                    mentionedUserIDs: request.mentionedUserIDs
                )
                feedbackStore.add(feedback)
                return feedback
            },
            fetchReceived: { userID, _ in
                try await simulateLoading()
                return feedbackStore.all().filter { myVideoIDs.contains($0.videoID) && $0.authorID != userID }
            },
            fetchGiven: { userID, _ in
                try await simulateLoading()
                return feedbackStore.all().filter { $0.authorID == userID }
            },
            observeFeedbacks: { videoID in
                feedbackStore.observe(videoID: videoID)
            },
            deleteFeedback: { id in
                feedbackStore.delete(id: id)
            }
        )

        // Feedback Comment
        dependencies.feedbackCommentClient = FeedbackCommentClient(
            fetchComments: { feedbackID in
                try await simulateLoading()
                return commentStore.value
                    .filter { $0.feedbackID == feedbackID }
                    .sorted { $0.createdAt < $1.createdAt }
            },
            fetchLatestComments: { feedbackIDs in
                try await simulateLoading()
                let allComments = commentStore.value
                var latest: [UUID: FeedbackComment] = [:]
                for feedbackID in feedbackIDs {
                    latest[feedbackID] = allComments
                        .filter { $0.feedbackID == feedbackID }
                        .max { $0.createdAt < $1.createdAt }
                }
                return latest
            },
            createComment: { request in
                let comment = FeedbackComment(
                    id: UUID(),
                    feedbackID: request.feedbackID,
                    studyID: feedbackStore.all().first { $0.id == request.feedbackID }?.studyID ?? studyA.id,
                    authorID: meID,
                    authorName: me.name,
                    content: request.content,
                    mentionedUserIDs: request.mentionedUserIDs,
                    createdAt: Date()
                )
                commentStore.withValue { $0.append(comment) }
                return comment
            },
            deleteComment: { id in
                commentStore.withValue { $0.removeAll { $0.id == id } }
            }
        )

        // User
        dependencies.userClient = UserClient(
            fetchUser: { _ in me },
            updateProfile: { _ in me },
            registerDeviceToken: { _ in },
            removeDeviceToken: { _ in },
            updateNotificationSettings: { _ in },
            fetchMyActivityStats: {
                try await simulateLoading()
                return MyActivityStats(
                    studiesCount: 2,
                    videosUploadedCount: 5,
                    feedbackReceivedCount: 12,
                    feedbackGivenCount: 9
                )
            }
        )

        // Push Notification
        dependencies.pushNotificationClient = PushNotificationClient(
            requestAuthorization: { true },
            getAuthorizationStatus: { .authorized },
            registerForRemoteNotifications: {},
            observeFCMToken: { AsyncStream { continuation in continuation.finish() } },
            observePushNotificationTapped: { AsyncStream { continuation in continuation.finish() } }
        )

        // Notification
        dependencies.notificationClient = NotificationClient(
            fetchNotifications: { _, _ in
                try await simulateLoading()
                return notificationStore.value.sorted { $0.createdAt > $1.createdAt }
            },
            fetchUnreadCount: { _ in
                notificationStore.value.filter { !$0.isRead }.count
            },
            markAsRead: { id in
                notificationStore.withValue { notifications in
                    guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
                    notifications[index].isRead = true
                }
            },
            markAllAsRead: { _ in
                notificationStore.withValue { notifications in
                    for index in notifications.indices {
                        notifications[index].isRead = true
                    }
                }
            },
            observeNotifications: { _ in AsyncStream { continuation in continuation.finish() } }
        )

        // Report
        dependencies.reportClient = ReportClient(
            createReport: { request in
                Report(
                    id: UUID(),
                    reporterID: meID,
                    targetType: request.targetType,
                    targetID: request.targetID,
                    reason: request.reason,
                    detail: request.detail,
                    createdAt: Date()
                )
            },
            checkAlreadyReported: { _, _ in false }
        )

        // Block (인메모리 목)
        let memberNames: [UUID: String] = Dictionary(
            (studyA.members + studyB.members).map { ($0.userID, $0.userName) },
            uniquingKeysWith: { first, _ in first }
        )
        let blockedUserStore = LockIsolated<[BlockedUser]>([])
        dependencies.blockClient = BlockClient(
            blockUser: { userID in
                blockedUserStore.withValue { blocked in
                    guard !blocked.contains(where: { $0.id == userID }) else { return }
                    blocked.insert(
                        BlockedUser(
                            id: userID,
                            name: memberNames[userID] ?? "알 수 없는 사용자",
                            profileImageURL: nil,
                            blockedAt: Date()
                        ),
                        at: 0
                    )
                }
            },
            unblockUser: { userID in
                blockedUserStore.withValue { blocked in
                    blocked.removeAll { $0.id == userID }
                }
            },
            fetchBlockedUsers: { blockedUserStore.value }
        )

        // Recruit (스터디원 모집 — 인메모리 목)
        let recruitPostStore = LockIsolated<[RecruitPost]>([
            RecruitPost(
                id: uuid(600),
                title: "국내 항공사 영상면접 스터디원 모집",
                description: "다음 달 공채 대비로 매주 영상 촬영하고 상호 피드백해요. 꾸준히 참여할 분만!",
                field: .flightAttendant,
                meetingType: .hybrid,
                region: "서울",
                schedule: "매주 화·목 20시, 주 2회",
                startDate: now.addingTimeInterval(10 * day),
                endDate: now.addingTimeInterval(60 * day),
                maxMembers: 6,
                deadline: now.addingTimeInterval(7 * day),
                requirement: "승무원 준비 3개월 이상, 주 1회 영상 업로드 가능",
                contactMethod: "댓글로 문의해주세요",
                linkURL: nil,
                authorID: haneulID,
                authorName: "김하늘",
                status: .recruiting,
                commentCount: 1,
                createdAt: now.addingTimeInterval(-2 * day)
            ),
            RecruitPost(
                id: uuid(601),
                title: "외항사 영어면접 온라인 스터디",
                description: "영어 자기소개와 상황면접 영상을 올리고 피드백을 주고받아요.",
                field: .flightAttendant,
                meetingType: .online,
                region: nil,
                schedule: "매주 토 10시, 주 1회",
                startDate: now.addingTimeInterval(-20 * day),
                endDate: nil,
                maxMembers: 4,
                deadline: now.addingTimeInterval(-1 * day),
                requirement: "주 1회 영어 답변 영상 업로드 가능하신 분",
                contactMethod: "오픈채팅으로 문의해주세요",
                linkURL: URL(string: "https://open.kakao.com/o/example"),
                authorID: meID,
                authorName: "유나",
                status: .recruiting,
                commentCount: 0,
                createdAt: now.addingTimeInterval(-25 * day)
            ),
        ])
        let recruitCommentStore = LockIsolated<[RecruitComment]>([
            RecruitComment(
                id: uuid(650),
                postID: uuid(600),
                parentID: nil,
                authorID: seoyeonID,
                authorName: "박서연",
                authorProfileURL: nil,
                content: "혹시 온라인만 참여도 가능할까요?",
                createdAt: now.addingTimeInterval(-1 * day)
            ),
        ])
        dependencies.recruitClient = RecruitClient(
            fetchPosts: { filter, _ in
                try await simulateLoading()
                return recruitPostStore.value
                    .filter { post in
                        (!filter.recruitingOnly || post.isRecruiting())
                            && (filter.field == nil || post.field == filter.field)
                            && (filter.meetingType == nil || post.meetingType == filter.meetingType)
                    }
                    .sorted { $0.createdAt > $1.createdAt }
            },
            fetchPost: { id in
                try await simulateLoading()
                guard let post = recruitPostStore.value.first(where: { $0.id == id }) else {
                    throw AppError.business(.notFound)
                }
                return post
            },
            createPost: { draft in
                let post = RecruitPost(
                    id: UUID(), title: draft.title, description: draft.description,
                    field: draft.field, meetingType: draft.meetingType, region: draft.region,
                    schedule: draft.schedule, startDate: draft.startDate, endDate: draft.endDate,
                    maxMembers: draft.maxMembers, deadline: draft.deadline,
                    requirement: draft.requirement, contactMethod: draft.contactMethod,
                    linkURL: draft.linkURL, authorID: meID, authorName: me.name,
                    status: .recruiting, commentCount: 0, createdAt: Date()
                )
                recruitPostStore.withValue { $0.insert(post, at: 0) }
                return post
            },
            updatePost: { id, draft in
                guard let old = recruitPostStore.value.first(where: { $0.id == id }) else {
                    throw AppError.business(.notFound)
                }
                let updated = RecruitPost(
                    id: id, title: draft.title, description: draft.description,
                    field: draft.field, meetingType: draft.meetingType, region: draft.region,
                    schedule: draft.schedule, startDate: draft.startDate, endDate: draft.endDate,
                    maxMembers: draft.maxMembers, deadline: draft.deadline,
                    requirement: draft.requirement, contactMethod: draft.contactMethod,
                    linkURL: draft.linkURL, authorID: old.authorID, authorName: old.authorName,
                    status: old.status, commentCount: old.commentCount,
                    createdAt: old.createdAt, updatedAt: Date()
                )
                recruitPostStore.withValue { store in
                    if let index = store.firstIndex(where: { $0.id == id }) { store[index] = updated }
                }
                return updated
            },
            closePost: { id in
                try mockUpdateRecruitStatus(recruitPostStore, id: id, status: .closed, deadline: nil)
            },
            reopenPost: { id, deadline in
                try mockUpdateRecruitStatus(recruitPostStore, id: id, status: .recruiting, deadline: deadline)
            },
            deletePost: { id in
                recruitPostStore.withValue { $0.removeAll { $0.id == id } }
            },
            fetchComments: { postID in
                try await simulateLoading()
                return recruitCommentStore.value
                    .filter { $0.postID == postID }
                    .sorted { $0.createdAt < $1.createdAt }
            },
            createComment: { request in
                let comment = RecruitComment(
                    id: UUID(), postID: request.postID, parentID: request.parentID,
                    authorID: meID, authorName: me.name, authorProfileURL: nil,
                    content: request.content, createdAt: Date()
                )
                recruitCommentStore.withValue { $0.append(comment) }
                return comment
            },
            deleteComment: { id in
                recruitCommentStore.withValue { $0.removeAll { $0.id == id || $0.parentID == id } }
            }
        )

        // UserDefaults — 기본 디버그 실행에서도 실제 앱과 동일하게 온보딩 상태 유지
        dependencies.userDefaultsClient = UserDefaultsClient(
            boolForKey: { UserDefaults.standard.bool(forKey: $0) },
            setBool: { value, key in UserDefaults.standard.set(value, forKey: key) }
        )

        // Subscription (프리미엄 — 스터디 2개 소속 시나리오와 일관성 유지)
        let premium = Entitlement(
            planID: "premium_monthly",
            status: "active",
            expiresDate: now.addingTimeInterval(30 * day),
            maxOwnedStudies: 5,
            maxJoinedStudies: 5,
            maxVideoDurationSeconds: 180,
            maxStudyMembers: 8,
            currentOwnedStudies: 1,
            currentJoinedStudies: 1
        )
        dependencies.subscriptionClient = SubscriptionClient(
            fetchEntitlements: { _ in premium },
            fetchPlans: {
                [
                    SubscriptionPlan(id: "free", name: "무료", maxOwnedStudies: 1, maxJoinedStudies: 1, maxVideoDurationSeconds: 60, maxStudyMembers: 3),
                    SubscriptionPlan(id: "premium_monthly", name: "프리미엄 (월간)", maxOwnedStudies: 5, maxJoinedStudies: 5, maxVideoDurationSeconds: 180, maxStudyMembers: 8),
                    SubscriptionPlan(id: "premium_yearly", name: "프리미엄 (연간)", maxOwnedStudies: 5, maxJoinedStudies: 5, maxVideoDurationSeconds: 180, maxStudyMembers: 8),
                ]
            },
            verifyReceipt: { _ in premium },
            checkFeatureLimit: { _, feature in FeatureLimit(allowed: true, current: 1, max: 5, feature: feature) },
            fetchProducts: { [] },
            purchase: { _ in fatalError("Mock: purchase not available") },
            currentEntitlement: { nil },
            observeTransactionUpdates: { AsyncStream { continuation in continuation.finish() } },
            restorePurchases: {}
        )
    }

    nonisolated private static func mockUpdateRecruitStatus(
        _ store: LockIsolated<[RecruitPost]>,
        id: UUID,
        status: RecruitStatus,
        deadline: Date?
    ) throws -> RecruitPost {
        guard let old = store.value.first(where: { $0.id == id }) else {
            throw AppError.business(.notFound)
        }
        let updated = RecruitPost(
            id: old.id, title: old.title, description: old.description,
            field: old.field, meetingType: old.meetingType, region: old.region,
            schedule: old.schedule, startDate: old.startDate, endDate: old.endDate,
            maxMembers: old.maxMembers, deadline: deadline ?? old.deadline,
            requirement: old.requirement, contactMethod: old.contactMethod,
            linkURL: old.linkURL, authorID: old.authorID, authorName: old.authorName,
            status: status, commentCount: old.commentCount,
            createdAt: old.createdAt, updatedAt: old.updatedAt
        )
        store.withValue { posts in
            if let index = posts.firstIndex(where: { $0.id == id }) { posts[index] = updated }
        }
        return updated
    }

    private final class MockFeedbackStore: @unchecked Sendable {
        private let lock = NSLock()
        private var feedbacks: [Feedback]
        private var continuations: [UUID: AsyncStream<[Feedback]>.Continuation] = [:]

        init(initialFeedbacks: [Feedback]) {
            self.feedbacks = initialFeedbacks
        }

        func all() -> [Feedback] {
            lock.withLock { feedbacks }
        }

        func feedbacks(for videoID: UUID) -> [Feedback] {
            lock.withLock {
                feedbacks.filter { $0.videoID == videoID }
            }
        }

        func add(_ feedback: Feedback) {
            lock.withLock {
                feedbacks.append(feedback)
            }
            let videoFeedbacks = self.feedbacks(for: feedback.videoID)
            lock.withLock {
                continuations[feedback.videoID]?.yield(videoFeedbacks)
            }
        }

        func delete(id: UUID) {
            lock.withLock {
                feedbacks.removeAll { $0.id == id }
            }
        }

        func observe(videoID: UUID) -> AsyncStream<[Feedback]> {
            AsyncStream { [weak self] continuation in
                guard let self else {
                    continuation.finish()
                    return
                }
                self.lock.withLock {
                    self.continuations[videoID] = continuation
                }
                continuation.onTermination = { [weak self] _ in
                    self?.lock.withLock {
                        self?.continuations.removeValue(forKey: videoID)
                    }
                }
            }
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .onOpenURL { url in
                    if url.scheme == "flymate" {
                        if let deepLink = DeepLinkParser.parse(url: url) {
                            store.send(.deepLink(deepLink))
                        }
                    } else {
                        _ = KakaoSignInClient.handleOpenURL(url)
                    }
                }
        }
    }
}
