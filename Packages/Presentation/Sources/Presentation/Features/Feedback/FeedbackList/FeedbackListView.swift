import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct FeedbackListView: View {
    let store: StoreOf<FeedbackListFeature>

    public init(store: StoreOf<FeedbackListFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.loadingState {
            case .idle, .loading:
                ScrollView {
                    LazyVStack(spacing: FMSpacing.sm) {
                        ForEach(0..<5, id: \.self) { _ in
                            FMSkeletonView()
                                .frame(height: 80)
                        }
                    }
                    .padding(FMSpacing.md)
                }

            case .loaded(let feedbacks):
                if feedbacks.isEmpty {
                    FMEmptyState(
                        systemImage: store.listType == .received
                            ? "bubble.left.and.bubble.right"
                            : "pencil.and.outline",
                        title: store.listType == .received
                            ? "받은 피드백이 없습니다"
                            : "작성한 피드백이 없습니다",
                        description: store.listType == .received
                            ? "영상을 올리면 피드백을 받을 수 있어요."
                            : "다른 멤버의 영상에 피드백을 남겨보세요."
                    )

                } else {
                    ScrollView {
                        LazyVStack(spacing: FMSpacing.sm) {
                            ForEach(feedbacks) { feedback in
                                FeedbackManagementRow(feedback: feedback)
                                    .onTapGesture {
                                        store.send(.feedbackTapped(feedback))
                                    }
                                    .onAppear {
                                        if feedback == feedbacks.last {
                                            store.send(.loadMore)
                                        }
                                    }
                            }

                            if store.feedbacks.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding(FMSpacing.md)
                    }
                    .refreshable {
                        store.send(.refresh)
                    }
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.refresh)
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }
}

// MARK: - Feedback Management Row

struct FeedbackManagementRow: View {
    let feedback: Domain.Feedback

    var body: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                HStack {
                    Text(feedback.authorName)
                        .font(FMTypography.caption1)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(feedback.createdAt.relativeString)
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Text(feedback.content)
                    .font(FMTypography.callout)
                    .lineLimit(3)

                HStack {
                    Label(
                        feedback.timestampSeconds.minuteSecondFormatted,
                        systemImage: "clock"
                    )
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.accent)
                }
            }
        }
    }
}
