import SwiftUI
import UIKit

/// 시스템 트림 UI(UIVideoEditorController) 래퍼 — 최대 길이 초과 영상을 잘라서 업로드할 수 있게 한다.
struct VideoTrimmerView: UIViewControllerRepresentable {
    let videoURL: URL
    let maximumDuration: TimeInterval
    let onComplete: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIVideoEditorController {
        let editor = UIVideoEditorController()
        editor.videoPath = videoURL.path
        editor.videoMaximumDuration = maximumDuration
        editor.videoQuality = .typeIFrame1280x720
        editor.delegate = context.coordinator
        return editor
    }

    func updateUIViewController(_ uiViewController: UIVideoEditorController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
        private let onComplete: (URL) -> Void
        private let onCancel: () -> Void
        private var didFinish = false // delegate가 중복 호출될 수 있어 1회만 처리

        init(onComplete: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func videoEditorController(
            _ editor: UIVideoEditorController,
            didSaveEditedVideoToPath editedVideoPath: String
        ) {
            guard !didFinish else { return }
            didFinish = true
            onComplete(URL(fileURLWithPath: editedVideoPath))
        }

        func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
            guard !didFinish else { return }
            didFinish = true
            onCancel()
        }

        func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: Error) {
            guard !didFinish else { return }
            didFinish = true
            onCancel() // ponytail: 실패도 취소로 처리 — 재선택 유도로 충분
        }
    }
}
