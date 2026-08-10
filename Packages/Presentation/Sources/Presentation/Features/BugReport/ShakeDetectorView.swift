import CoreMotion
import SwiftUI
import UIKit

struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: @MainActor () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        ShakeDetectorViewController(onShake: onShake)
    }

    func updateUIViewController(
        _ uiViewController: ShakeDetectorViewController,
        context: Context
    ) {
        uiViewController.onShake = onShake
    }
}

final class ShakeDetectorViewController: UIViewController {
    var onShake: @MainActor () -> Void
    private let motionManager = CMMotionManager()
    private var highAccelerationCount = 0
    private var firstHighAccelerationAt = Date.distantPast
    private var lastShakeAt = Date.distantPast

    private enum Constants {
        static let updateInterval: TimeInterval = 0.05
        static let accelerationThreshold = 2.3
        static let requiredHighAccelerationCount = 2
        static let highAccelerationWindow: TimeInterval = 0.45
        static let shakeCooldown: TimeInterval = 1.5
    }

    init(onShake: @escaping @MainActor () -> Void) {
        self.onShake = onShake
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        startMotionDetection()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        motionManager.stopAccelerometerUpdates()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        reportShakeIfNeeded()
    }

    private func startMotionDetection() {
        guard motionManager.isAccelerometerAvailable,
              !motionManager.isAccelerometerActive else {
            return
        }

        motionManager.accelerometerUpdateInterval = Constants.updateInterval
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let acceleration = data?.acceleration else { return }
            let magnitude = sqrt(
                acceleration.x * acceleration.x
                + acceleration.y * acceleration.y
                + acceleration.z * acceleration.z
            )
            self.processAcceleration(magnitude, at: Date())
        }
    }

    private func processAcceleration(_ magnitude: Double, at date: Date) {
        guard magnitude >= Constants.accelerationThreshold else { return }

        if date.timeIntervalSince(firstHighAccelerationAt) > Constants.highAccelerationWindow {
            highAccelerationCount = 0
            firstHighAccelerationAt = date
        }
        highAccelerationCount += 1

        guard highAccelerationCount >= Constants.requiredHighAccelerationCount else { return }
        highAccelerationCount = 0
        reportShakeIfNeeded(at: date)
    }

    private func reportShakeIfNeeded(at date: Date = Date()) {
        guard date.timeIntervalSince(lastShakeAt) >= Constants.shakeCooldown else { return }
        lastShakeAt = date
        onShake()
    }
}
