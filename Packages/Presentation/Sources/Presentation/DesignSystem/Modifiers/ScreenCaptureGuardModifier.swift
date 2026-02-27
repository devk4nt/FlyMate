import SwiftUI
import UIKit

// MARK: - Screen Capture Guard Modifier

/// 화면 녹화가 감지되면 차단 오버레이를 표시하는 ViewModifier.
/// `PlayerUIView`의 secure container와 함께 사용하여 스크린샷과 녹화 모두 차단합니다.
struct ScreenCaptureGuardModifier: ViewModifier {
    @State private var isCaptured = Self.isScreenBeingCaptured

    func body(content: Content) -> some View {
        content
            .overlay {
                if isCaptured {
                    screenRecordingBlockingOverlay
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)
            ) { _ in
                isCaptured = Self.isScreenBeingCaptured
            }
    }

    private var screenRecordingBlockingOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: FMSpacing.md) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("화면 녹화 중에는\n영상을 볼 수 없습니다")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private static var isScreenBeingCaptured: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .screen
            .isCaptured ?? false
    }
}

// MARK: - View Extension

extension View {
    /// 영상 재생 화면에 스크린 캡처 보호를 적용합니다.
    /// 화면 녹화 감지 시 차단 오버레이를 표시합니다.
    func screenCaptureGuarded() -> some View {
        modifier(ScreenCaptureGuardModifier())
    }
}
