import UIKit
import Core
import Presentation

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Kakao SDK 초기화
        KakaoSignInClient.initializeSDK()

        // TODO: Firebase 초기화
        // FirebaseApp.configure()

        // TODO: Crashlytics 설정
        // Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // TODO: 푸시 알림 (Firebase 설정 후 활성화)
        // UNUserNotificationCenter.current().requestAuthorization(
        //     options: [.alert, .badge, .sound]
        // ) { granted, error in
        //     if granted {
        //         DispatchQueue.main.async {
        //             application.registerForRemoteNotifications()
        //         }
        //     }
        // }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        FMLogger.info("APNs token registered: \(token)", category: .general)
        // TODO: FCM 토큰 등록
        // Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        FMLogger.error("Failed to register for remote notifications: \(error)", category: .general)
    }
}
