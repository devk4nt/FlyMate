import SwiftUI
import ComposableArchitecture
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
                Self.registerLiveDependencies(&$0)
                let supabaseClient = SupabaseClientProvider.shared.client
                let testEmail = ProcessInfo.processInfo.environment["TEST_EMAIL"] ?? "test@flymate.app"
                let testPassword = ProcessInfo.processInfo.environment["TEST_PASSWORD"] ?? "testpassword123"
                $0.authClient.debugSignIn = {
                    try? await supabaseClient.auth.signOut()
                    _ = try await supabaseClient.auth.signIn(
                        email: testEmail,
                        password: testPassword
                    )
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
            deleteAccount: { try await authRepo.deleteAccount() },
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
            updateNotificationSettings: { try await userRepo.updateNotificationSettings(enabled: $0) }
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
    }

    #if DEBUG
    private static func registerMockDependencies(_ dependencies: inout DependencyValues) {
        let previewUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let previewUser = User(
            id: previewUserID,
            email: "preview@flymate.app",
            name: "Preview User",
            provider: .apple,
            createdAt: Date()
        )

        let mockStudyID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let mockStudy = Study(
            id: mockStudyID,
            name: "iOS 면접 스터디",
            description: "Swift & iOS 면접 준비 스터디",
            ownerID: previewUserID,
            inviteCode: "ABC123",
            maxMembers: 6,
            members: [
                StudyMember(
                    id: UUID(),
                    userID: previewUserID,
                    userName: "Preview User",
                    role: .owner,
                    joinedAt: Date()
                )
            ],
            createdAt: Date(),
            notice: "매주 월요일 오후 8시 모의 면접을 진행합니다."
        )

        // Auth
        dependencies.authClient = AuthClient(
            currentUser: { previewUser },
            signInWithApple: { _, _ in previewUser },
            signInWithKakao: { _ in previewUser },
            signOut: {},
            deleteAccount: {},
            observeAuthState: { AsyncStream { continuation in continuation.yield(previewUser) } }
        )

        // Study
        dependencies.studyClient = StudyClient(
            fetchMyStudies: { [mockStudy] },
            fetchStudy: { _ in mockStudy },
            createStudy: { request in
                Study(
                    id: UUID(),
                    name: request.name,
                    description: request.description,
                    ownerID: previewUserID,
                    inviteCode: "NEW123",
                    maxMembers: request.maxMembers,
                    members: [
                        StudyMember(
                            id: UUID(),
                            userID: previewUserID,
                            userName: "Preview User",
                            role: .owner,
                            joinedAt: Date()
                        )
                    ],
                    createdAt: Date()
                )
            },
            requestJoinStudy: { _ in
                JoinRequest(
                    id: UUID(),
                    studyID: mockStudyID,
                    studyName: "iOS 면접 스터디",
                    userID: previewUserID,
                    userName: "Preview User",
                    status: .pending,
                    createdAt: Date()
                )
            },
            leaveStudy: { _ in },
            deleteStudy: { _ in },
            removeMember: { _, _ in },
            fetchInviteCodeInfo: { code in
                InviteCode(
                    code: code,
                    studyID: mockStudyID,
                    studyName: "iOS 면접 스터디",
                    createdAt: Date(),
                    expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60),
                    isActive: true
                )
            },
            updateNotice: { _, _ in },
            fetchPendingRequests: { _ in [] },
            approveJoinRequest: { _ in },
            rejectJoinRequest: { _ in },
            cancelJoinRequest: { _ in },
            fetchMemberStats: { studyID, userID in
                MemberStats(
                    userID: userID,
                    studyID: studyID,
                    feedbackGivenCount: 12,
                    feedbackReceivedCount: 8,
                    videosUploadedCount: 5,
                    joinedAt: Date().addingTimeInterval(-30 * 24 * 60 * 60)
                )
            }
        )

        // Video
        dependencies.videoClient = VideoClient(
            fetchVideos: { studyID, _ in
                [
                    Video(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
                        studyID: studyID,
                        uploaderID: previewUserID,
                        uploaderName: "Preview User",
                        title: "자기소개 면접 연습",
                        videoURL: URL(string: "https://example.com/video1.mp4")!,
                        durationSeconds: 180,
                        feedbackCount: 3,
                        createdAt: Date().addingTimeInterval(-86400)
                    ),
                    Video(
                        id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                        studyID: studyID,
                        uploaderID: previewUserID,
                        uploaderName: "Preview User",
                        title: "기술 면접 모의",
                        videoURL: URL(string: "https://example.com/video2.mp4")!,
                        durationSeconds: 240,
                        feedbackCount: 1,
                        createdAt: Date()
                    ),
                ]
            },
            fetchVideo: { id in
                Video(
                    id: id,
                    studyID: mockStudyID,
                    uploaderID: previewUserID,
                    uploaderName: "Preview User",
                    title: "Mock Video",
                    videoURL: URL(string: "https://example.com/video.mp4")!,
                    durationSeconds: 120,
                    createdAt: Date()
                )
            },
            uploadVideo: { request, progress in
                for p in [0.3, 0.6, 0.9, 1.0] as [Double] {
                    try await Task.sleep(for: .milliseconds(300))
                    progress(p)
                }
                return Video(
                    id: UUID(),
                    studyID: request.studyID,
                    uploaderID: previewUserID,
                    uploaderName: "Preview User",
                    title: request.title,
                    videoURL: URL(string: "https://example.com/uploaded.mp4")!,
                    durationSeconds: 60,
                    createdAt: Date()
                )
            },
            deleteVideo: { _ in }
        )

        // Feedback
        let mockVideoID1 = UUID(uuidString: "00000000-0000-0000-0000-000000000100")!
        let mockVideoID2 = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let reviewerID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!

        let feedbackStore = MockFeedbackStore(initialFeedbacks: [
            Feedback(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
                videoID: mockVideoID1,
                studyID: mockStudyID,
                authorID: reviewerID,
                authorName: "김면접",
                content: "자기소개 도입부가 인상적이에요. 다만 경력 설명 부분에서 좀 더 구체적인 수치를 넣으면 좋겠습니다.",
                timestampSeconds: 35,
                createdAt: Date().addingTimeInterval(-7200)
            ),
            Feedback(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
                videoID: mockVideoID1,
                studyID: mockStudyID,
                authorID: reviewerID,
                authorName: "김면접",
                content: "마무리 멘트가 자연스럽고 좋습니다!",
                timestampSeconds: 150,
                createdAt: Date().addingTimeInterval(-3600)
            ),
            Feedback(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                videoID: mockVideoID2,
                studyID: mockStudyID,
                authorID: reviewerID,
                authorName: "김면접",
                content: "Swift Concurrency 설명할 때 Actor 예시를 추가하면 더 설득력 있을 것 같아요.",
                timestampSeconds: 90,
                createdAt: Date().addingTimeInterval(-1800)
            ),
        ])

        dependencies.feedbackClient = FeedbackClient(
            fetchFeedbacks: { videoID in
                feedbackStore.feedbacks(for: videoID)
            },
            createFeedback: { request in
                let feedback = Feedback(
                    id: UUID(),
                    videoID: request.videoID,
                    studyID: mockStudyID,
                    authorID: previewUserID,
                    authorName: "Preview User",
                    content: request.content,
                    timestampSeconds: request.timestampSeconds,
                    createdAt: Date()
                )
                feedbackStore.add(feedback)
                return feedback
            },
            fetchReceived: { userID, _ in
                feedbackStore.received(by: userID)
            },
            fetchGiven: { userID, _ in
                feedbackStore.given(by: userID)
            },
            observeFeedbacks: { videoID in
                feedbackStore.observe(videoID: videoID)
            },
            deleteFeedback: { id in
                feedbackStore.delete(id: id)
            }
        )

        // Feedback Comment (Mock)
        dependencies.feedbackCommentClient = FeedbackCommentClient(
            fetchComments: { _ in [] },
            fetchLatestComments: { _ in [:] },
            createComment: { request in
                FeedbackComment(
                    id: UUID(),
                    feedbackID: request.feedbackID,
                    studyID: mockStudyID,
                    authorID: previewUserID,
                    authorName: "Preview User",
                    content: request.content,
                    mentionedUserIDs: request.mentionedUserIDs,
                    createdAt: Date()
                )
            },
            deleteComment: { _ in }
        )

        // User
        dependencies.userClient = UserClient(
            fetchUser: { _ in previewUser },
            updateProfile: { _ in previewUser },
            registerDeviceToken: { _ in },
            removeDeviceToken: { _ in },
            updateNotificationSettings: { _ in }
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
        let mockNotifications: [AppNotification] = [
            AppNotification(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000300")!,
                recipientID: previewUserID,
                type: .feedbackOnMyVideo,
                title: "새 피드백이 달렸어요",
                body: "김면접님이 \"자기소개 면접 연습\" 영상에 피드백을 남겼습니다.",
                referenceVideoID: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!,
                referenceFeedbackID: UUID(uuidString: "00000000-0000-0000-0000-000000000200")!,
                isRead: false,
                createdAt: Date().addingTimeInterval(-1800)
            ),
            AppNotification(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
                recipientID: previewUserID,
                type: .mentionedInFeedback,
                title: "피드백에서 태그되었어요",
                body: "김면접님이 피드백에서 회원님을 태그했습니다.",
                referenceVideoID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                referenceFeedbackID: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                isRead: true,
                createdAt: Date().addingTimeInterval(-7200)
            ),
        ]
        dependencies.notificationClient = NotificationClient(
            fetchNotifications: { _, _ in mockNotifications },
            fetchUnreadCount: { _ in mockNotifications.filter { !$0.isRead }.count },
            markAsRead: { _ in },
            markAllAsRead: { _ in },
            observeNotifications: { _ in AsyncStream { continuation in continuation.finish() } }
        )

        // Report
        dependencies.reportClient = ReportClient(
            createReport: { request in
                Report(
                    id: UUID(),
                    reporterID: previewUserID,
                    targetType: request.targetType,
                    targetID: request.targetID,
                    reason: request.reason,
                    detail: request.detail,
                    createdAt: Date()
                )
            },
            checkAlreadyReported: { _, _ in false }
        )
    }

    private final class MockFeedbackStore: @unchecked Sendable {
        private let lock = NSLock()
        private var feedbacks: [Feedback]
        private var continuations: [UUID: AsyncStream<[Feedback]>.Continuation] = [:]

        init(initialFeedbacks: [Feedback]) {
            self.feedbacks = initialFeedbacks
        }

        func feedbacks(for videoID: UUID) -> [Feedback] {
            lock.withLock {
                feedbacks.filter { $0.videoID == videoID }
            }
        }

        func received(by userID: UUID) -> [Feedback] {
            lock.withLock {
                feedbacks.filter { $0.authorID != userID }
            }
        }

        func given(by userID: UUID) -> [Feedback] {
            lock.withLock {
                feedbacks.filter { $0.authorID == userID }
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
