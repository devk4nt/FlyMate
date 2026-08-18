import AVKit
import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct QuickFeedbackHubView: View {
    private enum Constants {
        static let requestPreviewCount = 3
    }

    @Bindable var store: StoreOf<QuickFeedbackHubFeature>

    public init(store: StoreOf<QuickFeedbackHubFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: FMSpacing.lg) {
                switch store.dashboard {
                case .idle, .loading:
                    ForEach(0..<3, id: \.self) { _ in FMSkeletonView.card }
                case .failed(let error):
                    FMErrorView(error: error) { store.send(.refresh) }
                case .loaded(let dashboard):
                    pointCard(dashboard)
                    myRequestsSection(dashboard)
                    availableSection(dashboard.availableRequests)
                }
            }
            .frame(maxWidth: FMSizing.ContentWidth.regular)
            .frame(maxWidth: .infinity)
            .padding(FMSpacing.md)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .background(FMColors.softCanvas)
        .navigationTitle("빠른 피드백")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .refreshable { await store.send(.refresh).finish() }
        .sheet(item: $store.scope(state: \.review, action: \.review)) { reviewStore in
            NavigationStack { QuickFeedbackReviewView(store: reviewStore) }
        }
        .sheet(item: $store.scope(state: \.requestDetail, action: \.requestDetail)) { detailStore in
            NavigationStack { QuickFeedbackRequestDetailView(store: detailStore) }
        }
        .alert("빠른 피드백", isPresented: Binding(
            get: { store.error != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.error?.errorDescription ?? "오류가 발생했습니다.")
        }
        .overlay {
            if store.isClaiming {
                ProgressView("영상을 배정하는 중...")
                    .padding(FMSpacing.lg)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
            }
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

    private func pointCard(_ dashboard: QuickFeedbackDashboard) -> some View {
        FMCard {
            HStack(spacing: FMSpacing.md) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(FMColors.iconAccent)
                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text("내 피드백 포인트")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                    Text("\(dashboard.pointBalance)개")
                        .font(FMTypography.title2)
                        .foregroundStyle(FMColors.label)
                        .monospacedDigit()
                }
                Spacer()
                Button("영상 올리기") { store.send(.uploadTapped) }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        dashboard.pointBalance < AppConstants.quickFeedbackRequestPointCost
                            || dashboard.myRequests.contains { $0.status == .open }
                    )
                    .accessibilityHint("포인트 2개를 사용해 빠른 피드백을 요청합니다")
            }
        }
    }

    @ViewBuilder
    private func myRequestsSection(_ dashboard: QuickFeedbackDashboard) -> some View {
        if !dashboard.myRequests.isEmpty {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                HStack(spacing: FMSpacing.xs) {
                    Text("내 요청 기록")
                        .font(FMTypography.sectionTitle)

                    sectionCountBadge(dashboard.myRequests.count)

                    Spacer()

                    if dashboard.myRequests.count > Constants.requestPreviewCount {
                        NavigationLink {
                            QuickFeedbackRequestHistoryListView(
                                requests: dashboard.myRequests,
                                onRequestTapped: {
                                    store.send(.requestHistoryTapped($0))
                                },
                                onCloseRequestTapped: {
                                    store.send(.closeRequestTapped($0))
                                }
                            )
                        } label: {
                            Text("전체 보기")
                                .font(FMTypography.authorName)
                        }
                        .accessibilityLabel("내 요청 기록 \(dashboard.myRequests.count)개 전체 보기")
                        .accessibilityHint("내 빠른 피드백 요청 전체 목록으로 이동합니다")
                    }
                }
                ForEach(Array(dashboard.myRequests.prefix(Constants.requestPreviewCount))) { request in
                    QuickFeedbackRequestHistoryCard(
                        request: request,
                        onTapped: { store.send(.requestHistoryTapped(request.id)) },
                        onCloseTapped: { store.send(.closeRequestTapped(request.id)) }
                    )
                }
            }
        }
    }

    private func sectionCountBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(FMTypography.caption1.weight(.semibold))
            .foregroundStyle(FMColors.actionForeground)
            .monospacedDigit()
            .padding(.horizontal, FMSpacing.xs)
            .padding(.vertical, FMSpacing.xxxs)
            .background(FMColors.accent.opacity(0.1), in: Capsule())
            .accessibilityLabel("\(count)개")
    }

    private func availableSection(_ requests: [QuickFeedbackRequest]) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            HStack {
                Text("내가 도울 수 있는 영상")
                    .font(FMTypography.sectionTitle)
                Spacer()
                Text("\(requests.count)개")
                    .font(FMTypography.authorName)
                    .foregroundStyle(FMColors.secondaryLabel)
            }

            if requests.isEmpty {
                FMEmptyState(
                    systemImage: "checkmark.circle.fill",
                    title: "지금은 기다리는 영상이 없어요",
                    description: "새 요청이 생기면 여기에서 피드백할 수 있어요.",
                    layout: .card
                )
            } else {
                Button { store.send(.startFeedbackTapped) } label: {
                    FMCard(style: .feed) {
                        VStack(alignment: .leading, spacing: FMSpacing.sm) {
                            Label("대기 중인 영상 1개 받기", systemImage: "play.circle.fill")
                                .font(FMTypography.cardTitle)
                                .foregroundStyle(FMColors.label)
                            Text("시작하면 영상 하나가 30분 동안 임시 배정돼요. 제출을 마치면 포인트 1개를 받아요.")
                                .font(FMTypography.callout)
                                .foregroundStyle(FMColors.secondaryLabel)
                            if store.isClaiming {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.plain)
                .disabled(store.isClaiming)
                .accessibilityLabel("대기 중인 영상 하나 배정받기")
                .accessibilityHint("30분 동안 영상 하나를 임시 배정받고 피드백을 작성합니다")
            }
        }
    }

}

private struct QuickFeedbackRequestHistoryListView: View {
    let requests: [QuickFeedbackRequest]
    let onRequestTapped: (UUID) -> Void
    let onCloseRequestTapped: (UUID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: FMSpacing.md) {
                ForEach(requests) { request in
                    QuickFeedbackRequestHistoryCard(
                        request: request,
                        onTapped: { onRequestTapped(request.id) },
                        onCloseTapped: { onCloseRequestTapped(request.id) }
                    )
                }
            }
            .padding(FMSpacing.md)
        }
        .background(FMColors.softCanvas)
        .navigationTitle("내 요청 전체")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct QuickFeedbackRequestHistoryCard: View {
    let request: QuickFeedbackRequest
    let onTapped: () -> Void
    let onCloseTapped: () -> Void

    var body: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                Button(action: onTapped) {
                    VStack(alignment: .leading, spacing: FMSpacing.sm) {
                        HStack {
                            Text(request.title).font(FMTypography.headline)
                            Spacer()
                            Text("\(request.feedbackCount)/\(request.targetFeedbackCount)")
                                .font(FMTypography.authorName)
                                .monospacedDigit()
                        }
                        HStack {
                            Label(request.focusArea.title, systemImage: "scope")
                            Spacer()
                            Text(request.createdAt.relativeString)
                        }
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                        ProgressView(
                            value: Double(request.feedbackCount),
                            total: Double(request.targetFeedbackCount)
                        )
                        .tint(FMColors.primary)
                        HStack {
                            Text(statusText)
                            Spacer()
                            Label("영상과 피드백 보기", systemImage: "chevron.right")
                        }
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("업로드한 영상과 받은 빠른 피드백을 확인합니다")
                if request.status == .open {
                    Button("요청 종료", action: onCloseTapped)
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.destructive)
                        .accessibilityHint("아직 받지 못한 피드백만큼 포인트를 돌려받습니다")
                }
            }
        }
    }

    private var statusText: String {
        switch request.status {
        case .open: "피드백을 기다리고 있어요"
        case .completed: "목표 피드백을 모두 받았어요"
        case .expired: "요청이 만료되었어요"
        case .closed: "요청을 종료했어요"
        }
    }
}

public struct QuickFeedbackRequestDetailView: View {
    @Bindable var store: StoreOf<QuickFeedbackRequestDetailFeature>
    @State private var player: AVPlayer

    public init(store: StoreOf<QuickFeedbackRequestDetailFeature>) {
        self.store = store
        _player = State(initialValue: AVPlayer(
            url: store.request.videoURL ?? URL(fileURLWithPath: "/dev/null")
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FMSpacing.lg) {
                if store.request.videoURL != nil {
                    FMSecureVideoPlayer(player: player)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
                        .screenCaptureGuarded()
                        .onDisappear { player.pause() }
                } else {
                    FMEmptyState(
                        systemImage: "video.slash",
                        title: "영상을 불러올 수 없어요",
                        description: "잠시 후 다시 확인해주세요.",
                        layout: .card
                    )
                }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text(store.request.title).font(FMTypography.title2)
                    Label(store.request.focusArea.title, systemImage: "scope")
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.secondaryLabel)
                    if let feedbackRequest = store.request.feedbackRequest {
                        Text(feedbackRequest)
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }

                Text("받은 빠른 피드백 \(store.reviews.count)개")
                    .font(FMTypography.sectionTitle)

                if store.reviews.isEmpty {
                    FMEmptyState(
                        systemImage: "bubble.left",
                        title: "아직 도착한 피드백이 없어요",
                        description: "피드백이 도착하면 이곳에서 확인할 수 있어요.",
                        layout: .card
                    )
                } else {
                    ForEach(store.reviews) { review in
                        reviewCard(review)
                    }
                }
            }
            .padding(FMSpacing.md)
        }
        .background(FMColors.softCanvas)
        .navigationTitle("요청 상세")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $store.scope(state: \.userActivity, action: \.userActivity)) { activityStore in
            MyActivitySheet(store: activityStore)
        }
        .sheet(item: $store.scope(state: \.report, action: \.report)) { reportStore in
            ReportView(store: reportStore)
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

    private func reviewCard(_ review: QuickFeedbackReview) -> some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.sm) {
                HStack {
                    FMUserProfileButton(
                        url: review.reviewerProfileURL,
                        name: review.reviewerName,
                        imageSize: .lg
                    ) {
                        store.send(.reviewerProfileTapped(review))
                    }
                    Spacer()
                    HStack(spacing: FMSpacing.xxs) {
                        Text(review.createdAt.relativeString)
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)

                        Menu {
                            Button(role: .destructive) {
                                store.send(.reportReviewTapped(review))
                            } label: {
                                Label("피드백 신고", systemImage: "exclamationmark.bubble")
                            }
                            Button(role: .destructive) {
                                store.send(.reportUserTapped(review))
                            } label: {
                                Label("사용자 신고", systemImage: "person.crop.circle.badge.exclamationmark")
                            }
                            Button(role: .destructive) {
                                store.send(.blockUserTapped(review))
                            } label: {
                                Label("사용자 차단", systemImage: "person.crop.circle.badge.xmark")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(FMColors.secondaryLabel)
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                        }
                        .accessibilityLabel("빠른 피드백 신고 및 차단 메뉴")
                    }
                }
                Label(review.focusArea.title, systemImage: "bubble.left.fill")
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.iconAccent)
                Text("좋았던 점").font(FMTypography.caption1).foregroundStyle(FMColors.secondaryLabel)
                Text(review.positiveText).font(FMTypography.body)
                Divider()
                Text("개선하면 좋을 점").font(FMTypography.caption1).foregroundStyle(FMColors.secondaryLabel)
                Text(review.improvementText).font(FMTypography.body)
            }
        }
    }
}

public struct QuickFeedbackReviewView: View {
    @Bindable var store: StoreOf<QuickFeedbackReviewFeature>
    @State private var player: AVPlayer

    public init(store: StoreOf<QuickFeedbackReviewFeature>) {
        self.store = store
        _player = State(initialValue: AVPlayer(url: store.claimed.request.videoURL ?? URL(fileURLWithPath: "/dev/null")))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FMSpacing.lg) {
                FMSecureVideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
                    .screenCaptureGuarded()
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }

                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    FMUserProfileButton(
                        url: store.claimed.request.uploaderProfileURL,
                        name: store.claimed.request.uploaderName,
                        imageSize: .md
                    ) {
                        store.send(.uploaderProfileTapped)
                    }

                    Text(store.claimed.request.title).font(FMTypography.title2)
                    if let request = store.claimed.request.feedbackRequest {
                        Text(request).font(FMTypography.callout).foregroundStyle(FMColors.secondaryLabel)
                    }
                }

                focusPicker
                editor(title: "좋았던 점", text: $store.positiveText.sending(\.positiveTextChanged))
                editor(title: "개선하면 좋을 점", text: $store.improvementText.sending(\.improvementTextChanged))
                Text("각 항목을 20자 이상 작성하면 피드백 포인트 1개를 받아요.")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
            .padding(FMSpacing.md)
        }
        .navigationTitle("피드백 작성")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        store.send(.reportRequestTapped)
                    } label: {
                        Label("영상 신고", systemImage: "exclamationmark.bubble")
                    }
                    Button(role: .destructive) {
                        store.send(.reportUploaderTapped)
                    } label: {
                        Label("사용자 신고", systemImage: "person.crop.circle.badge.exclamationmark")
                    }
                    Button(role: .destructive) {
                        store.send(.blockUploaderTapped)
                    } label: {
                        Label("사용자 차단", systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("영상 신고 및 사용자 차단 메뉴")
            }
        }
        .sheet(item: $store.scope(state: \.userActivity, action: \.userActivity)) { activityStore in
            MyActivitySheet(store: activityStore)
        }
        .sheet(item: $store.scope(state: \.report, action: \.report)) { reportStore in
            ReportView(store: reportStore)
        }
        .alert($store.scope(state: \.blockAlert, action: \.blockAlert))
        .safeAreaInset(edge: .bottom) {
            FMButton(title: "피드백 제출", isLoading: store.isSubmitting, isEnabled: store.isValid) {
                store.send(.submitTapped)
            }
            .padding(FMSpacing.md)
            .background(.ultraThinMaterial)
        }
        .alert("제출 실패", isPresented: Binding(
            get: { store.error != nil },
            set: { if !$0 { store.send(.errorDismissed) } }
        )) {
            Button("확인") { store.send(.errorDismissed) }
        } message: {
            Text(store.error?.errorDescription ?? "오류가 발생했습니다.")
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

    private var focusPicker: some View {
        Picker("피드백 항목", selection: $store.focusArea.sending(\.focusAreaSelected)) {
            ForEach(QuickFeedbackFocusArea.allCases, id: \.self) { area in
                Text(area.title).tag(area)
            }
        }
        .pickerStyle(.menu)
    }

    private func editor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            Text(title).font(FMTypography.headline)
            TextEditor(text: text)
                .frame(minHeight: 110)
                .padding(FMSpacing.xs)
                .fmInputSurface()
        }
    }
}
