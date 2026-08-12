import SwiftUI
import ComposableArchitecture
import Core

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
                case .pending:
                    VideoFeedView(
                        store: store.scope(state: \.pending, action: \.pending)
                    )
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
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
            .background(FMColors.softCanvas)
            .navigationTitle("피드백")
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(FMColors.softCanvas)
    }

    private var feedbackHeader: some View {
        FMCard {
            HStack(spacing: FMSpacing.sm) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: FMSizing.IconSize.sm, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: FMSizing.IconContainer.md, height: FMSizing.IconContainer.md)
                    .background(FMColors.brandGradient, in: Circle())

                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text("GROW TOGETHER")
                        .font(FMTypography.eyebrow)
                        .tracking(0.5)
                        .foregroundStyle(FMColors.decorativeBrand)

                    Text("한마디가 다음 영상을 바꿔요")
                        .font(FMTypography.authorName)
                        .foregroundStyle(FMColors.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var segmentControl: some View {
        HStack(spacing: FMSpacing.xs) {
            ForEach(FeedbackManagementFeature.State.Segment.allCases, id: \.self) { segment in
                Button {
                    store.send(.segmentChanged(segment), animation: .snappy)
                } label: {
                    HStack(spacing: FMSpacing.xxs) {
                        Label(segment.rawValue, systemImage: segmentIcon(for: segment))
                            .font(FMTypography.authorName)
                            .foregroundStyle(
                                store.selectedSegment == segment
                                    ? FMColors.selection
                                    : FMColors.secondaryLabel
                            )

                        if segment == .pending {
                            FMBadge(count: pendingCount)
                                .accessibilityLabel("피드백할 영상 \(pendingCount)개")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 38)
                    .background {
                        if store.selectedSegment == segment {
                            Capsule()
                                .fill(FMColors.background)
                                .shadow(color: FMShadow.floatingColor, radius: FMShadow.floatingRadius, y: FMShadow.floatingY)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.selectedSegment == segment ? .isSelected : [])
            }
        }
        .padding(4)
        .background(FMColors.accent.opacity(0.1), in: Capsule())
    }

    private var pendingCount: Int {
        guard case .loaded(let videos) = store.pending.loadingState else { return 0 }
        return videos.count
    }

    private func segmentIcon(for segment: FeedbackManagementFeature.State.Segment) -> String {
        switch segment {
        case .pending:
            "play.rectangle.on.rectangle.fill"
        case .received:
            "tray.and.arrow.down.fill"
        case .given:
            "paperplane.fill"
        }
    }
}
