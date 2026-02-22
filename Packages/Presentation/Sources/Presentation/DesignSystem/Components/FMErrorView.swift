import SwiftUI
import Core

/// An error state view displaying an error message with a retry button.
/// Accepts an `AppError` from the Core module and renders the appropriate
/// icon, message, and retry action.
public struct FMErrorView: View {
    private let error: AppError
    private let retryAction: () -> Void

    public init(
        error: AppError,
        retryAction: @escaping () -> Void
    ) {
        self.error = error
        self.retryAction = retryAction
    }

    public var body: some View {
        VStack(spacing: FMSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            VStack(spacing: FMSpacing.xs) {
                Text(title)
                    .font(FMTypography.title3)
                    .foregroundStyle(FMColors.label)
                    .multilineTextAlignment(.center)

                Text(error.errorDescription ?? "알 수 없는 오류가 발생했습니다.")
                    .font(FMTypography.body)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            FMButton(
                title: "다시 시도",
                style: .primary,
                action: retryAction
            )
            .fixedSize(horizontal: true, vertical: false)
            .padding(.top, FMSpacing.xs)
        }
        .padding(FMSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch error {
        case .network:
            return "wifi.slash"
        case .business:
            return "exclamationmark.triangle.fill"
        case .unexpected:
            return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch error {
        case .network:
            return FMColors.warning
        case .business:
            return FMColors.destructive
        case .unexpected:
            return FMColors.destructive
        }
    }

    private var title: String {
        switch error {
        case .network:
            return "네트워크 오류"
        case .business:
            return "요청 실패"
        case .unexpected:
            return "예상치 못한 오류"
        }
    }
}

#Preview {
    VStack(spacing: FMSpacing.xxl) {
        FMErrorView(error: .network(.noConnection)) {}
        FMErrorView(error: .business(.studyFull)) {}
    }
}
