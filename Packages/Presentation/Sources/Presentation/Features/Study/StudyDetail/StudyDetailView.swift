import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct StudyDetailView: View {
    let store: StoreOf<StudyDetailFeature>

    public init(store: StoreOf<StudyDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.videos {
            case .idle, .loading:
                ScrollView {
                    LazyVStack(spacing: FMSpacing.md) {
                        ForEach(0..<4, id: \.self) { _ in
                            FMSkeletonView()
                                .frame(height: 200)
                        }
                    }
                    .padding(FMSpacing.md)
                }

            case .loaded(let videos):
                if videos.isEmpty {
                    FMEmptyState(
                        systemImage: "video.badge.plus",
                        title: "아직 영상이 없습니다",
                        description: "면접 연습 영상을 업로드해보세요."
                    ) {
                        store.send(.uploadVideoTapped(studyID: store.study.id))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: FMSpacing.md) {
                            // 스터디 정보 헤더
                            studyInfoHeader

                            // 영상 목록
                            ForEach(videos) { video in
                                videoCard(video)
                                    .onTapGesture {
                                        store.send(.videoTapped(video))
                                    }
                                    .onAppear {
                                        if video == videos.last {
                                            store.send(.loadMoreVideos)
                                        }
                                    }
                            }

                            if store.videosPagination.isLoadingMore {
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
        .navigationTitle(store.study.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.uploadVideoTapped(studyID: store.study.id))
                } label: {
                    Image(systemName: "video.badge.plus")
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var studyInfoHeader: some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            Text(store.study.description)
                .font(FMTypography.body)
                .foregroundStyle(FMColors.secondaryLabel)

            HStack {
                Label("\(store.study.memberCount)명", systemImage: "person.2")
                    .font(FMTypography.caption1)

                Spacer()

                Button {
                    store.send(.copyInviteCode)
                } label: {
                    Label("초대 코드 복사", systemImage: "doc.on.doc")
                        .font(FMTypography.caption1)
                }
            }
        }
        .padding(FMSpacing.md)
        .background(FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
    }

    private func videoCard(_ video: Domain.Video) -> some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                // 썸네일 영역
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm)
                    .fill(FMColors.secondaryBackground)
                    .frame(height: 160)
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                Text(video.title)
                    .font(FMTypography.headline)

                HStack {
                    Text(video.uploaderName)
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)

                    Spacer()

                    Text(video.durationSeconds.minuteSecondFormatted)
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)

                    if video.feedbackCount > 0 {
                        FMBadge(count: video.feedbackCount)
                    }
                }
            }
        }
    }
}
