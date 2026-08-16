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
                    LazyVStack(spacing: FMSpacing.md) {
                        ForEach(0..<3, id: \.self) { _ in
                            FMSkeletonView(height: 164)
                        }
                    }
                    .padding(.horizontal, FMSpacing.md)
                    .padding(.bottom, FMSpacing.xxl)
                }

            case .loaded(let feedbacks):
                if feedbacks.isEmpty {
                    FMEmptyState(
                        systemImage: store.listType == .received
                            ? "bubble.left.and.bubble.right.fill"
                            : "paperplane.fill",
                        title: store.listType == .received
                            ? "아직 받은 피드백이 없어요"
                            : "아직 작성한 피드백이 없어요",
                        description: store.listType == .received
                            ? "영상을 올리면 멤버들의 응원과 조언을 받을 수 있어요."
                            : "다른 멤버의 영상에서 따뜻한 첫 피드백을 남겨보세요.",
                        layout: .card
                    )
                    .padding(.horizontal, FMSpacing.md)

                } else {
                    ScrollView {
                        LazyVStack(spacing: FMSpacing.md) {
                            ForEach(feedbacks) { feedback in
                                FeedbackManagementRow(
                                    feedback: feedback,
                                    onEdit: store.listType == .given ? {
                                        store.send(.editFeedbackTapped(feedback))
                                    } : nil,
                                    onReportFeedback: store.listType == .received ? {
                                        store.send(.reportFeedbackTapped(feedback))
                                    } : nil,
                                    onReportUser: store.listType == .received ? {
                                        store.send(.reportUserTapped(feedback))
                                    } : nil,
                                    onBlockUser: store.listType == .received ? {
                                        store.send(.blockUserTapped(feedback))
                                    } : nil
                                )
                                .contentShape(Rectangle())
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
                        .padding(.horizontal, FMSpacing.md)
                        .padding(.bottom, FMSpacing.xxl)
                    }
                    .refreshable {
                        await store.send(.refresh).finish()
                    }
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.refresh)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FMColors.softCanvas)
        .onAppear { store.send(.onAppear) }
        .sheet(item: $store.scope(state: \.report, action: \.report)) { reportStore in
            ReportView(store: reportStore)
        }
        .sheet(item: $store.scope(state: \.edit, action: \.edit)) { editStore in
            NavigationStack {
                FeedbackEditView(store: editStore)
            }
        }
        .alert($store.scope(state: \.blockAlert, action: \.blockAlert))
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
    var onEdit: (() -> Void)?
    var onReportFeedback: (() -> Void)?
    var onReportUser: (() -> Void)?
    var onBlockUser: (() -> Void)?

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
                .foregroundColor(FMColors.selection)
                .fontWeight(.semibold)
            currentIndex = range.upperBound
        }

        if currentIndex < content.endIndex {
            result = result + Text(content[currentIndex...])
        }

        return result
    }

    var body: some View {
        FMCard(style: .feed) {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
            HStack(spacing: FMSpacing.sm) {
                FMProfileImage(
                    url: feedback.authorProfileURL,
                    name: feedback.authorName,
                    size: .lg
                )

                VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                    Text(feedback.authorName)
                        .font(FMTypography.authorName)
                        .foregroundStyle(FMColors.label)

                    Text(feedback.createdAt.relativeString)
                        .font(FMTypography.feedMeta)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Spacer(minLength: 0)

                if onEdit != nil || onReportFeedback != nil || onReportUser != nil || onBlockUser != nil {
                    Menu {
                        if let onEdit {
                            Button {
                                onEdit()
                            } label: {
                                Label("수정하기", systemImage: "pencil")
                            }
                        }
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
                        if let onBlockUser {
                            Button(role: .destructive) {
                                onBlockUser()
                            } label: {
                                Label("사용자 차단", systemImage: "person.crop.circle.badge.xmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.secondaryLabel)
                            .frame(width: 36, height: 36)
                            .background(FMColors.softCanvas, in: Circle())
                            .contentShape(Circle())
                    }
                    .accessibilityLabel(onEdit != nil ? "더보기 메뉴" : "신고 메뉴")
                }
            }

            HStack(alignment: .top, spacing: FMSpacing.sm) {
                Capsule()
                    .fill(FMColors.selection)
                    .frame(width: 3)

                highlightedContent(feedback.content)
                    .font(FMTypography.feedBody)
                    .foregroundStyle(FMColors.label)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: FMSpacing.sm) {
                Label(
                    "영상 \(feedback.timestampSeconds.minuteSecondFormatted)",
                    systemImage: "play.fill"
                )
                .font(FMTypography.feedMetaEmphasis)
                .foregroundStyle(FMColors.badgeForeground)
                .padding(.horizontal, FMSpacing.sm)
                .padding(.vertical, FMSpacing.xs)
                .background(FMColors.badgeForeground.opacity(0.12), in: Capsule())

                if feedback.commentCount > 0 {
                    Label("답글 \(feedback.commentCount)", systemImage: "bubble.left.fill")
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(FMTypography.badgeStrong)
                    .foregroundStyle(FMColors.iconAccent)
                    .frame(width: 30, height: 30)
                    .background(FMColors.iconAccent.opacity(0.1), in: Circle())
            }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feedback.authorName)의 피드백, \(feedback.content), 영상 \(feedback.timestampSeconds.minuteSecondFormatted), 답글 \(feedback.commentCount)개")
        .accessibilityHint("영상의 해당 시점에서 피드백을 확인하려면 이중 탭하세요")
    }
}
