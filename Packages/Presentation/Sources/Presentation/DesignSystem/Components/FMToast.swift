import SwiftUI

/// A toast notification view with message, type, and auto-dismiss behavior.
public struct FMToast: View {
    public enum ToastType: Sendable {
        case success
        case error
        case info

        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var tintColor: Color {
            switch self {
            case .success: return FMColors.success
            case .error: return FMColors.destructive
            case .info: return FMColors.accent
            }
        }
    }

    private let message: String
    private let type: ToastType
    private let duration: TimeInterval
    private let onDismiss: (() -> Void)?

    @State private var isVisible = false

    public init(
        message: String,
        type: ToastType,
        duration: TimeInterval = 3.0,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.type = type
        self.duration = duration
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if isVisible {
            HStack(spacing: FMSpacing.xs) {
                Image(systemName: type.iconName)
                    .foregroundStyle(type.tintColor)

                Text(message)
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.label)
                    .lineLimit(2)
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.vertical, FMSpacing.sm)
            .background(FMColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(type.accessibilityPrefix): \(message)")
        }
    }

    /// Shows the toast and schedules auto-dismiss.
    public func show() -> some View {
        self.onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = true
            }
            scheduleAutoDismiss()
        }
    }

    private func scheduleAutoDismiss() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = false
            }
            onDismiss?()
        }
    }
}

// MARK: - Toast Modifier

/// A ViewModifier that overlays a toast notification on the view.
public struct FMToastModifier: ViewModifier {
    @Binding private var isPresented: Bool
    private let message: String
    private let type: FMToast.ToastType
    private let duration: TimeInterval

    public init(
        isPresented: Binding<Bool>,
        message: String,
        type: FMToast.ToastType,
        duration: TimeInterval = 3.0
    ) {
        self._isPresented = isPresented
        self.message = message
        self.type = type
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    FMToast(
                        message: message,
                        type: type,
                        duration: duration,
                        onDismiss: { isPresented = false }
                    )
                    .show()
                    .padding(.top, FMSpacing.xl)
                }
            }
    }
}

extension View {
    /// Presents a toast notification overlay.
    /// - Parameters:
    ///   - isPresented: Binding controlling toast visibility.
    ///   - message: The message to display.
    ///   - type: The toast type (success, error, info).
    ///   - duration: Auto-dismiss duration in seconds.
    public func fmToast(
        isPresented: Binding<Bool>,
        message: String,
        type: FMToast.ToastType,
        duration: TimeInterval = 3.0
    ) -> some View {
        modifier(
            FMToastModifier(
                isPresented: isPresented,
                message: message,
                type: type,
                duration: duration
            )
        )
    }
}

// MARK: - Accessibility Helper

extension FMToast.ToastType {
    var accessibilityPrefix: String {
        switch self {
        case .success: return "성공"
        case .error: return "오류"
        case .info: return "안내"
        }
    }
}

#Preview {
    VStack {
        FMToast(message: "저장되었습니다.", type: .success)
            .show()
        FMToast(message: "오류가 발생했습니다.", type: .error)
            .show()
        FMToast(message: "새 알림이 있습니다.", type: .info)
            .show()
    }
    .padding()
}
