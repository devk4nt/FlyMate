import SwiftUI
import ARKit
import Core

/// ARKit 얼굴 추적 카메라 뷰 — 미소 blendShape 값을 스로틀해 `onSample`로 흘려보낸다.
/// 노드를 올리지 않으므로 ARSCNView는 전면 카메라 프리뷰로만 동작한다.
struct SmileMirrorView: UIViewRepresentable {
    let onSample: @Sendable (Double) -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session.delegate = context.coordinator
        view.session.run(ARFaceTrackingConfiguration())
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSample: onSample)
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private let onSample: @Sendable (Double) -> Void
        private var lastSampledAt: TimeInterval = 0

        init(onSample: @escaping @Sendable (Double) -> Void) {
            self.onSample = onSample
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first,
                  face.isTracked else { return }
            let now = Date.timeIntervalSinceReferenceDate
            guard now - lastSampledAt >= AppConstants.PracticeMirror.sampleInterval else { return }
            lastSampledAt = now

            let left = face.blendShapes[.mouthSmileLeft]?.doubleValue ?? 0
            let right = face.blendShapes[.mouthSmileRight]?.doubleValue ?? 0
            onSample((left + right) / 2)
        }
    }
}
