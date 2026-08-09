import SwiftUI
import ComposableArchitecture

public struct FeedbackManagementView: View {
    @Bindable var store: StoreOf<FeedbackManagementFeature>

    public init(store: StoreOf<FeedbackManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                feedbackHeader
                    .padding(.horizontal, FMSpacing.md)
                    .padding(.top, FMSpacing.xxs)

                segmentControl
                    .padding(.horizontal, FMSpacing.md)
                    .padding(.vertical, FMSpacing.sm)

                switch store.selectedSegment {
                case .received:
                    FeedbackListView(
                        store: store.scope(state: \.received, action: \.received)
                    )
                case .given:
                    FeedbackListView(
                        store: store.scope(state: \.given, action: \.given)
                    )
                }
            }
            .background(FMColors.softCanvas)
            .navigationTitle("피드백")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var feedbackHeader: some View {
        HStack(spacing: FMSpacing.sm) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(FMColors.brandGradient, in: Circle())
                .shadow(color: FMColors.brandInk.opacity(0.14), radius: 7, y: 4)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("GROW TOGETHER")
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(FMColors.brandInk)

                Text("한마디가 다음 영상을 바꿔요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FMColors.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.vertical, FMSpacing.sm)
        .background(FMColors.background, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                .stroke(FMColors.airBlue.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var segmentControl: some View {
        HStack(spacing: FMSpacing.xs) {
            ForEach(FeedbackManagementFeature.State.Segment.allCases, id: \.self) { segment in
                Button {
                    store.send(.segmentChanged(segment), animation: .snappy)
                } label: {
                    Label(segment.rawValue, systemImage: segmentIcon(for: segment))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            store.selectedSegment == segment
                                ? FMColors.brandInk
                                : FMColors.secondaryLabel
                        )
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 38)
                        .background {
                            if store.selectedSegment == segment {
                                Capsule()
                                    .fill(FMColors.background)
                                    .shadow(color: FMColors.brandInk.opacity(0.1), radius: 8, y: 3)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.selectedSegment == segment ? .isSelected : [])
            }
        }
        .padding(4)
        .background(FMColors.airBlue.opacity(0.1), in: Capsule())
    }

    private func segmentIcon(for segment: FeedbackManagementFeature.State.Segment) -> String {
        switch segment {
        case .received:
            "tray.and.arrow.down.fill"
        case .given:
            "paperplane.fill"
        }
    }
}
