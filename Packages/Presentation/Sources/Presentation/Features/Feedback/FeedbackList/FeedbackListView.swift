import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct FeedbackListView: View {
    @Bindable var store: StoreOf<FeedbackListFeature>

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
                                FeedbackManagementRow(
                                    feedback: feedback,
                                    onReportFeedback: {
                                        store.send(.reportFeedbackTapped(feedback))
                                    },
                                    onReportUser: {
                                        store.send(.reportUserTapped(feedback))
                                    }
                                )
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
        .sheet(item: $store.scope(state: \.report, action: \.report)) { reportStore in
            ReportView(store: reportStore)
        }
        .fmToast(
            isPresented: Binding(
                get: { store.showToast },
                set: { _ in store.send(.dismissToast) }
            ),
            message: store.toastMessage,
            type: .info
        )
    }
}

// MARK: - Feedback Management Row

struct FeedbackManagementRow: View {
    let feedback: Domain.Feedback
    var onReportFeedback: (() -> Void)?
    var onReportUser: (() -> Void)?

    private func highlightedContent(_ content: String) -> Text {
        let pattern = "@\\S+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(content)
        }

        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        guard !matches.isEmpty else { return Text(content) }

        var result = Text("")
        var currentIndex = content.startIndex

        for match in matches {
            guard let range = Range(match.range, in: content) else { continue }

            if currentIndex < range.lowerBound {
                result = result + Text(content[currentIndex..<range.lowerBound])
            }
            result = result + Text(content[range])
                .foregroundColor(FMColors.accent)
                .fontWeight(.semibold)
            currentIndex = range.upperBound
        }

        if currentIndex < content.endIndex {
            result = result + Text(content[currentIndex...])
        }

        return result
    }

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

                    if onReportFeedback != nil || onReportUser != nil {
                        Menu {
                            if let onReportFeedback {
                                Button(role: .destructive) {
                                    onReportFeedback()
                                } label: {
                                    Label("피드백 신고", systemImage: "exclamationmark.bubble")
                                }
                            }
                            if let onReportUser {
                                Button(role: .destructive) {
                                    onReportUser()
                                } label: {
                                    Label("사용자 신고", systemImage: "person.crop.circle.badge.exclamationmark")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(FMTypography.body)
                                .foregroundStyle(FMColors.secondaryLabel)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("신고 메뉴")
                    }
                }

                highlightedContent(feedback.content)
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
