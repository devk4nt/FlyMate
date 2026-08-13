import AVFoundation
import SwiftUI
import UIKit

struct VideoPlayerView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool
    let seekTime: TimeInterval
    let isSeeking: Bool
    let isMuted: Bool
    let onCurrentTimeUpdate: (TimeInterval) -> Void
    let onDurationUpdate: (TimeInterval) -> Void
    let onPlaybackEnded: () -> Void
    let onSeekCompleted: () -> Void
    /// 다른 페이지가 재생을 시작해 이 플레이어가 강제 정지된 경우 — 상태 동기화용
    let onPausedByOtherPlayer: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        let coordinator = context.coordinator
        coordinator.setupPlayer(url: url, initialTime: seekTime, in: view)
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let player = coordinator.player else { return }

        if isPlaying {
            if player.rate == 0 {
                // 오프스크린 페이지는 SwiftUI 갱신이 보장되지 않아 상태만으로는
                // pause가 전달되지 않을 수 있다 — 재생 시작 시점에 직접 정지시킨다
                Coordinator.activePlayer?.pauseByOtherPlayer(except: coordinator)
                Coordinator.activePlayer = coordinator
                player.play()
            }
        } else {
            if player.rate != 0 {
                player.pause()
            }
        }

        player.isMuted = isMuted

        if isSeeking {
            let target = CMTime(seconds: seekTime, preferredTimescale: 600)
            player.seek(
                to: target,
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { [weak coordinator] finished in
                guard finished else { return }
                Task { @MainActor in
                    coordinator?.parent.onSeekCompleted()
                }
            }
        }
    }

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: Coordinator) {
        coordinator.cleanup()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, @unchecked Sendable {
        /// 앱 전역에서 재생 중인 플레이어는 항상 하나 — 마지막으로 play한 Coordinator
        @MainActor static weak var activePlayer: Coordinator?

        var parent: VideoPlayerView
        var player: AVPlayer?
        private var timeObserver: Any?
        private var statusObservation: NSKeyValueObservation?
        private var endObserver: NSObjectProtocol?

        init(parent: VideoPlayerView) {
            self.parent = parent
        }

        /// 다른 페이지가 재생을 시작할 때 호출 — 플레이어를 정지시키고 상태를 동기화한다
        @MainActor
        func pauseByOtherPlayer(except coordinator: Coordinator) {
            guard self !== coordinator, let player, player.rate != 0 else { return }
            player.pause()
            parent.onPausedByOtherPlayer()
        }

        @MainActor
        func setupPlayer(url: URL, initialTime: TimeInterval, in view: PlayerUIView) {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)

            let playerItem = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: playerItem)
            player.allowsExternalPlayback = false  // AirPlay로 영상 반출 차단
            self.player = player

            view.playerLayer.player = player
            view.playerLayer.videoGravity = .resizeAspect

            player.isMuted = parent.isMuted

            // Periodic time observer (0.25s interval)
            let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: interval,
                queue: .main
            ) { [weak self] time in
                guard let self else { return }
                let seconds = CMTimeGetSeconds(time)
                guard seconds.isFinite else { return }
                // 관찰 큐가 .main이므로 MainActor 격리가 보장됨
                MainActor.assumeIsolated {
                    self.parent.onCurrentTimeUpdate(seconds)
                }
            }

            // Observe player item status for duration + initial seek
            statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self, item.status == .readyToPlay else { return }
                let duration = CMTimeGetSeconds(item.duration)
                guard duration.isFinite else { return }
                Task { @MainActor in
                    self.parent.onDurationUpdate(duration)
                    if initialTime > 0 {
                        let target = CMTime(seconds: initialTime, preferredTimescale: 600)
                        self.player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                }
            }

            // Observe playback end
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                // 관찰 큐가 .main이므로 MainActor 격리가 보장됨
                MainActor.assumeIsolated {
                    self.parent.onPlaybackEnded()
                }
            }
        }

        func cleanup() {
            if let timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            timeObserver = nil
            statusObservation?.invalidate()
            statusObservation = nil
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            endObserver = nil
            player?.pause()
            player = nil
        }

        deinit {
            cleanup()
        }
    }
}

// MARK: - PlayerUIView

final class PlayerUIView: UIView {
    private let secureTextField: UITextField = {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        textField.isUserInteractionEnabled = false
        textField.backgroundColor = .clear
        return textField
    }()

    private let avPlayerView = AVPlayerContainerView()

    var playerLayer: AVPlayerLayer {
        avPlayerView.playerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        avPlayerView.backgroundColor = .clear
        avPlayerView.playerLayer.backgroundColor = UIColor.clear.cgColor
        setupSecureContainer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSecureContainer() {
        addSubview(secureTextField)
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: topAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: bottomAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let targetView: UIView
        if let secureView = secureTextField.subviews.first {
            secureView.isUserInteractionEnabled = true
            secureView.backgroundColor = .clear
            secureView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                secureView.topAnchor.constraint(equalTo: topAnchor),
                secureView.bottomAnchor.constraint(equalTo: bottomAnchor),
                secureView.leadingAnchor.constraint(equalTo: leadingAnchor),
                secureView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            targetView = secureView
        } else {
            targetView = self
        }

        targetView.addSubview(avPlayerView)
        avPlayerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avPlayerView.topAnchor.constraint(equalTo: targetView.topAnchor),
            avPlayerView.bottomAnchor.constraint(equalTo: targetView.bottomAnchor),
            avPlayerView.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
            avPlayerView.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
        ])
    }
}

private final class AVPlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }
}
