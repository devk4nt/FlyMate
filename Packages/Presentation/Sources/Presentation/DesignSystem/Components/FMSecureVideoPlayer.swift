import AVKit
import SwiftUI
import UIKit

/// 시스템 재생 컨트롤을 유지하면서 영상 영역의 스크린샷 캡처를 방지하는 플레이어입니다.
struct FMSecureVideoPlayer: UIViewControllerRepresentable {
    private let player: AVPlayer

    init(player: AVPlayer) {
        self.player = player
    }

    func makeUIViewController(context: Context) -> SecureVideoPlayerViewController {
        SecureVideoPlayerViewController(player: player)
    }

    func updateUIViewController(
        _ uiViewController: SecureVideoPlayerViewController,
        context: Context
    ) {
        uiViewController.player = player
    }
}

// MARK: - SecureVideoPlayerViewController

final class SecureVideoPlayerViewController: UIViewController {
    private let secureTextField: UITextField = {
        let textField = UITextField()
        textField.isSecureTextEntry = true
        textField.backgroundColor = .black
        return textField
    }()

    private let playerViewController = AVPlayerViewController()

    var player: AVPlayer {
        didSet {
            player.allowsExternalPlayback = false
            playerViewController.player = player
        }
    }

    init(player: AVPlayer) {
        self.player = player
        super.init(nibName: nil, bundle: nil)
        self.player.allowsExternalPlayback = false
        playerViewController.player = player
        playerViewController.showsPlaybackControls = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSecureContainer()
    }

    private func setupSecureContainer() {
        view.addSubview(secureTextField)
        secureTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secureTextField.topAnchor.constraint(equalTo: view.topAnchor),
            secureTextField.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            secureTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            secureTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let secureContainer = secureTextField.subviews.first ?? secureTextField
        secureContainer.isUserInteractionEnabled = true
        secureContainer.backgroundColor = .black

        addChild(playerViewController)
        secureContainer.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerViewController.view.topAnchor.constraint(equalTo: secureContainer.topAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: secureContainer.bottomAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: secureContainer.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: secureContainer.trailingAnchor),
        ])
        playerViewController.didMove(toParent: self)
    }
}
