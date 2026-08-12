import Foundation
import MessageUI
import SwiftUI
import UIKit
import Core
import Domain

struct BugReportDraft: Identifiable {
    let id = UUID()
    let screenshotData: Data?
    let userID: String
    let account: String
    let appVersion: String
    let deviceDescription: String

    @MainActor
    static func capture(user: User?) -> Self {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return Self(
            screenshotData: ScreenSnapshot.capture(),
            userID: user?.id.uuidString ?? "로그인하지 않음",
            account: user?.displayEmail ?? "로그인하지 않음",
            appVersion: "\(version) (\(build))",
            deviceDescription: "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
        )
    }

    func mailBody(detail: String) -> String {
        """
        안녕하세요. FlyMate 이용 중 발견한 문제를 신고합니다.

        문제 내용:
        \(detail)

        --------------------
        아래 정보는 문제 확인을 위해 자동으로 입력되었어요.
        앱 버전: \(appVersion)
        기기: \(deviceDescription)
        회원 ID: \(userID)
        계정: \(account)
        """
    }
}

struct BugReportView: View {
    let draft: BugReportDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var detail = ""
    @State private var screenshotData: Data?
    @State private var mailDraft: BugReportMailDraft?
    @State private var showsMailUnavailableAlert = false
    @FocusState private var isDetailFocused: Bool

    init(draft: BugReportDraft) {
        self.draft = draft
        _screenshotData = State(initialValue: draft.screenshotData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("불편을 겪은 상황과 기대했던 동작을 알려주세요. 면접 영상은 자동으로 첨부되지 않습니다.")
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Section("문제 내용") {
                    TextEditor(text: $detail)
                        .frame(minHeight: 140)
                        .focused($isDetailFocused)
                        .onChange(of: detail) { _, newValue in
                            if newValue.count > AppConstants.maxBugReportLength {
                                detail = String(newValue.prefix(AppConstants.maxBugReportLength))
                            }
                        }

                    Text("\(detail.count)/\(AppConstants.maxBugReportLength)")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Section("화면 첨부") {
                    if let screenshotData, let image = UIImage(data: screenshotData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(
                                cornerRadius: FMSpacing.CornerRadius.sm,
                                style: .continuous
                            ))
                            .accessibilityLabel("버그가 발생한 화면 스크린샷")

                        Button("스크린샷 첨부하지 않기", role: .destructive) {
                            self.screenshotData = nil
                        }
                    } else {
                        Label("첨부할 스크린샷이 없어요", systemImage: "photo.badge.exclamationmark")
                            .foregroundStyle(FMColors.secondaryLabel)
                    }

                    Text("개인정보가 보인다면 전송 전에 스크린샷을 제거해 주세요.")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Section("자동 포함 정보") {
                    LabeledContent("앱 버전", value: draft.appVersion)
                    LabeledContent("기기", value: draft.deviceDescription)
                    LabeledContent("계정", value: draft.account)
                }
            }
            .scrollContentBackground(.hidden)
            .background(FMColors.softCanvas)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationTitle("버그 신고")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                FMButton(title: "메일로 신고하기", isEnabled: canSubmit) {
                    prepareMail()
                }
                .padding(FMSpacing.md)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(!detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .sheet(item: $mailDraft) { mailDraft in
            MailComposeView(draft: mailDraft) { result in
                self.mailDraft = nil
                if result == .sent {
                    dismiss()
                }
            }
        }
        .alert("메일 앱을 열 수 없어요", isPresented: $showsMailUnavailableAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("메일 앱을 설정한 뒤 다시 시도해 주세요. 문의 주소는 \(AppConstants.supportEmail)입니다.")
        }
    }

    private var canSubmit: Bool {
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func prepareMail() {
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDetail.isEmpty else { return }

        let mailDraft = BugReportMailDraft(
            recipient: AppConstants.supportEmail,
            subject: "[FlyMate 버그 신고] \(draft.appVersion)",
            body: draft.mailBody(detail: trimmedDetail),
            screenshotData: screenshotData
        )

        if MFMailComposeViewController.canSendMail() {
            self.mailDraft = mailDraft
        } else {
            openFallbackMail(mailDraft)
        }
    }

    private func openFallbackMail(_ mailDraft: BugReportMailDraft) {
        guard let url = mailDraft.mailtoURL else {
            showsMailUnavailableAlert = true
            return
        }
        openURL(url) { accepted in
            if accepted {
                dismiss()
            } else {
                showsMailUnavailableAlert = true
            }
        }
    }
}

struct BugReportMailDraft: Identifiable {
    let id = UUID()
    let recipient: String
    let subject: String
    let body: String
    let screenshotData: Data?

    var mailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

private struct MailComposeView: UIViewControllerRepresentable {
    let draft: BugReportMailDraft
    let onFinish: @MainActor (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([draft.recipient])
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        if let screenshotData = draft.screenshotData {
            controller.addAttachmentData(
                screenshotData,
                mimeType: "image/jpeg",
                fileName: "flymate-bug-screenshot.jpg"
            )
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: @MainActor (MFMailComposeResult) -> Void

        init(onFinish: @escaping @MainActor (MFMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            // 델리게이트 콜백은 메인 스레드에서 호출됨 — non-Sendable인 self 대신
            // Sendable한 @MainActor 클로저만 캡처해 Swift 6 region isolation 에러 회피
            let onFinish = onFinish
            MainActor.assumeIsolated {
                controller.dismiss(animated: true) {
                    onFinish(result)
                }
            }
        }
    }
}

private enum ScreenSnapshot {
    @MainActor
    static func capture() -> Data? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: \.isKeyWindow) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = window.screen.scale
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        return image.jpegData(compressionQuality: 0.78)
    }
}
