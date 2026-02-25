import UIKit
import Core
import Presentation
import FirebaseCore
import FirebaseMessaging
import UserNotifications

extension Notification.Name {
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Cold start 시 옵저버 등록 전에 유실되는 페이로드를 버퍼링
    nonisolated(unsafe) static var pendingPushPayload: [String: String]?
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Kakao SDK 초기화
        KakaoSignInClient.initializeSDK()

        // Firebase 초기화
        FirebaseApp.configure()

        // FCM delegate 설정
        Messaging.messaging().delegate = self

        // 알림 센터 delegate 설정
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        FMLogger.info("APNs token registered: \(token)", category: .general)

        // APNs 토큰을 Firebase에 전달
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        FMLogger.error("Failed to register for remote notifications: \(error)", category: .general)
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: @preconcurrency MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        FMLogger.info("FCM token received: \(fcmToken.prefix(10))...", category: .general)
        NotificationCenter.default.post(
            name: .fcmTokenReceived,
            object: nil,
            userInfo: ["token": fcmToken]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: @preconcurrency UNUserNotificationCenterDelegate {
    /// 포그라운드에서 알림 수신 시 배너, 뱃지, 사운드 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    /// 알림 탭 시 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        var payload: [String: String] = [:]
        for (key, value) in userInfo {
            if let key = key as? String, let value = value as? String {
                payload[key] = value
            }
        }
        FMLogger.info("Push notification tapped: \(payload)", category: .general)
        AppDelegate.pendingPushPayload = payload
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: ["payload": payload]
        )
    }
}
