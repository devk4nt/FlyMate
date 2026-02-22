import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct VideoDetailView: View {
    @Bindable var store: StoreOf<VideoDetailFeature>

    public init(store: StoreOf<VideoDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 영상 플레이어 영역
            videoPlayerArea

            // 피드백 목록
            feedbackSection
        }
        .navigationTitle(store.video.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.writeFeedbackTapped)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        .sheet(item: $store.scope(state: \.feedbackWrite, action: \.feedbackWrite)) { writeStore in
            NavigationStack {
                FeedbackWriteView(store: writeStore)
            }
            .presentationDetents([.medium])
        }
    }

    private var videoPlayerArea: some View {
        ZStack {
            // 플레이어 placeholder
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    VStack(spacing: FMSpacing.xs) {
                        Button {
                            if store.player.isPlaying {
                                store.send(.pause)
                            } else {
                                store.send(.play)
                            }
                        } label: {
                            Image(systemName: store.player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }

                        // 타임라인
                        HStack {
                            Text(store.player.currentTime.minuteSecondFormatted)
                                .font(FMTypography.caption2)
                                .foregroundStyle(.white)

                            Spacer()

                            Text(store.player.duration.minuteSecondFormatted)
                                .font(FMTypography.caption2)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, FMSpacing.md)
                    }
                }
        }
    }

    private var feedbackSection: some View {
        Group {
            switch store.feedbacks {
            case .idle, .loading:
                VStack {
                    ForEach(0..<3, id: \.self) { _ in
                        FMSkeletonView()
                            .frame(height: 60)
                    }
                }
                .padding(FMSpacing.md)

            case .loaded(let feedbacks):
                if feedbacks.isEmpty {
                    FMEmptyState(
                        systemImage: "bubble.left",
                        title: "아직 피드백이 없습니다",
                        description: "첫 번째 피드백을 남겨보세요."
                    ) {
                        store.send(.writeFeedbackTapped)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: FMSpacing.xs) {
                            ForEach(feedbacks) { feedback in
                                FeedbackRow(feedback: feedback)
                                    .onTapGesture {
                                        store.send(.feedbackTapped(feedback))
                                    }
                            }
                        }
                        .padding(FMSpacing.md)
                    }
                }

            case .failed(let error):
                FMErrorView(error: error) {}
            }
        }
    }
}

// MARK: - Feedback Row

private struct FeedbackRow: View {
    let feedback: Domain.Feedback

    var body: some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            // 타임스탬프 뱃지
            Text(feedback.timestampSeconds.minuteSecondFormatted)
                .font(FMTypography.caption1)
                .padding(.horizontal, FMSpacing.xs)
                .padding(.vertical, FMSpacing.xxxs)
                .background(FMColors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                HStack {
                    Text(feedback.authorName)
                        .font(FMTypography.caption1)
                        .fontWeight(.semibold)
                    Text(feedback.createdAt.relativeString)
                        .font(FMTypography.caption2)
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                Text(feedback.content)
                    .font(FMTypography.callout)
            }

            Spacer(minLength: 0)
        }
        .padding(FMSpacing.sm)
        .background(FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
    }
}
