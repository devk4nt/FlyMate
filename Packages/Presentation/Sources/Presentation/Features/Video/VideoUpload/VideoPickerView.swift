import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 시스템 영상 피커(UIImagePickerController) 래퍼 — 최대 길이 초과 영상은 선택 시점에 트림을 강제한다.
struct VideoPickerView: UIViewControllerRepresentable {
    let maximumDuration: TimeInterval
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoMaximumDuration = maximumDuration
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let mediaURL = info[.mediaURL] as? URL else {
                onCancel()
                return
            }

            // 피커가 정리되기 전에 임시 파일을 앱 소유 경로로 옮긴다
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(mediaURL.pathExtension)
            do {
                try FileManager.default.moveItem(at: mediaURL, to: tempURL)
                onPick(tempURL)
            } catch {
                do {
                    try FileManager.default.copyItem(at: mediaURL, to: tempURL)
                    onPick(tempURL)
                } catch {
                    onCancel()
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
