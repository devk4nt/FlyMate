import SwiftUI
import PhotosUI
import AVFoundation
import ComposableArchitecture
import Core

public struct VideoUploadView: View {
    @Bindable var store: StoreOf<VideoUploadFeature>
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessingVideo = false

    public init(store: StoreOf<VideoUploadFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            FMColors.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: FMSpacing.md) {
                    uploadHeader
                    videoSelectionCard
                    titleCard
                    coachingNotesCard

                    if case .uploading = store.uploadState {
                        uploadProgressCard
                    }

                    if let error = store.error {
                        errorCard(error)
                    }
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
                .padding(.bottom, FMSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .navigationTitle("영상 업로드")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FMButton(
                title: "영상 업로드",
                isLoading: store.uploadState == .uploading,
                isEnabled: store.isValid
            ) {
                store.send(.uploadTapped)
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.sm)
            .padding(.bottom, FMSpacing.xs)
            .background(.ultraThinMaterial)
        }
        .overlay {
            if isProcessingVideo {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: FMSpacing.sm) {
                        ProgressView()
                            .controlSize(.large)
                        Text("영상 처리 중...")
                            .font(FMTypography.callout)
                            .foregroundStyle(.white)
                    }
                    .padding(FMSpacing.lg)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
                }
            }
        }
        .alert(
            "업로드 실패",
            isPresented: Binding(
                get: {
                    if case .failed = store.uploadState { return true }
                    return false
                },
                set: { newValue in
                    if !newValue { store.send(.dismissUploadError) }
                }
            )
        ) {
            Button("확인") {
                store.send(.dismissUploadError)
            }
        } message: {
            if case .failed(let error) = store.uploadState {
                Text(error.errorDescription ?? "오류가 발생했습니다.")
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            processSelectedVideo(newItem)
        }
        .disabled(isProcessingVideo)
    }

    private var uploadHeader: some View {
        HStack(spacing: FMSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                    .fill(FMColors.featureGradient)

                Image(systemName: "video.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .shadow(color: FMColors.secondary.opacity(0.25), radius: 12, y: 6)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("연습 영상을 공유해요")
                    .font(FMTypography.title2)
                    .foregroundStyle(FMColors.label)

                Text("3분 이내 영상을 올리고 구체적인 피드백을 받아보세요.")
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, FMSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var videoSelectionCard: some View {
        let hasSelectedVideo = store.selectedVideoData != nil
        let durationText = store.videoDuration.minuteSecondFormatted
        let thumbnailImage = store.selectedThumbnailData
            .flatMap(UIImage.init(data:))
            .map { Image(uiImage: $0) }

        return uploadCard(title: "영상 선택", step: "01") {
            PhotosPicker(
                selection: $selectedItem,
                matching: .videos,
                photoLibrary: .shared()
            ) {
                ZStack {
                    if let thumbnailImage {
                        thumbnailImage
                            .resizable()
                            .scaledToFill()
                    } else {
                        FMColors.brandGradient
                            .opacity(0.14)

                        VStack(spacing: FMSpacing.sm) {
                            ZStack {
                                Circle()
                                    .fill(FMColors.primary.opacity(0.12))

                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(FMColors.primary)
                            }
                            .frame(width: 58, height: 58)

                            VStack(spacing: FMSpacing.xxs) {
                                Text("보관함에서 영상 선택")
                                    .font(FMTypography.headline)
                                    .foregroundStyle(FMColors.label)

                                Text("MOV 또는 MP4 · 최대 3분 · 50MB")
                                    .font(FMTypography.caption1)
                                    .foregroundStyle(FMColors.secondaryLabel)
                            }
                        }
                    }

                    if hasSelectedVideo {
                        Color.black.opacity(0.18)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous)
                        .stroke(
                            !hasSelectedVideo
                                ? FMColors.primary.opacity(0.28)
                                : FMColors.success.opacity(0.65),
                            style: StrokeStyle(lineWidth: 1.5, dash: !hasSelectedVideo ? [7] : [])
                        )
                }
            }
            .buttonStyle(.plain)

            if hasSelectedVideo {
                HStack {
                    Label("영상 선택 완료", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(FMColors.success)

                    Spacer()

                    Label(durationText, systemImage: "clock.fill")
                        .foregroundStyle(FMColors.secondaryLabel)
                }
                .font(FMTypography.feedMetaEmphasis)
            }
        }
    }

    private var titleCard: some View {
        uploadCard(title: "영상 정보", step: "02") {
            FMTextField(
                title: "제목",
                placeholder: "예: 대한항공 1분 자기소개 연습",
                text: $store.title.sending(\.titleChanged)
            )
        }
    }

    private var coachingNotesCard: some View {
        uploadCard(title: "코칭 노트", step: "03 · 선택") {
            noteEditor(
                title: "촬영 포인트",
                placeholder: "표정, 시선 처리 등 중점적으로 연습한 부분",
                text: $store.focusPoints.sending(\.focusPointsChanged),
                systemImage: "scope"
            )

            Divider()

            noteEditor(
                title: "피드백 요청",
                placeholder: "스터디원에게 구체적으로 묻고 싶은 내용",
                text: $store.feedbackRequest.sending(\.feedbackRequestChanged),
                systemImage: "bubble.left.and.text.bubble.right"
            )
        }
    }

    private var uploadProgressCard: some View {
        VStack(alignment: .leading, spacing: FMSpacing.sm) {
            HStack {
                Label("업로드 중", systemImage: "arrow.up.circle.fill")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.primary)

                Spacer()

                Text("\(Int(store.uploadProgress * 100))%")
                    .font(FMTypography.feedMetaEmphasis)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .monospacedDigit()
            }

            ProgressView(value: store.uploadProgress)
                .tint(FMColors.primary)
        }
        .padding(FMSpacing.md)
        .background(FMColors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
    }

    private func errorCard(_ error: AppError) -> some View {
        Label(
            error.errorDescription ?? "오류가 발생했습니다.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(FMTypography.callout)
        .foregroundStyle(FMColors.destructive)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(FMSpacing.md)
        .background(FMColors.destructiveSurface)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
    }

    private func noteEditor(
        title: String,
        placeholder: String,
        text: Binding<String>,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.xs) {
            Label(title, systemImage: systemImage)
                .font(FMTypography.authorName)
                .foregroundStyle(FMColors.label)

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.secondaryLabel.opacity(0.65))
                        .padding(.horizontal, FMSpacing.sm)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(FMTypography.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 88)
                    .padding(FMSpacing.xs)
            }
            .background(FMColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
        }
    }

    private func uploadCard<Content: View>(
        title: String,
        step: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.md) {
            HStack {
                Text(title)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Spacer()

                Text(step)
                    .font(FMTypography.feedMetaEmphasis)
                    .foregroundStyle(FMColors.primary)
                    .padding(.horizontal, FMSpacing.xs)
                    .padding(.vertical, FMSpacing.xxs)
                    .background(FMColors.primary.opacity(0.1))
                    .clipShape(Capsule())
            }

            content()
        }
        .padding(FMSpacing.md)
        .background(FMColors.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                .stroke(FMColors.border.opacity(0.2), lineWidth: 0.5)
        }
        .shadow(color: FMShadow.cardColor, radius: 10, y: 4)
    }

    private func processSelectedVideo(_ item: PhotosPickerItem) {
        isProcessingVideo = true

        Task {
            do {
                guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
                    await MainActor.run {
                        isProcessingVideo = false
                        store.send(.videoProcessingFailed(.business(.invalidVideoFormat)))
                    }
                    return
                }

                let url = movie.url
                defer { try? FileManager.default.removeItem(at: url) }
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)

                let compressedURL = try await compressVideo(asset: asset)
                let videoData = try Data(contentsOf: compressedURL)
                try? FileManager.default.removeItem(at: compressedURL)

                if videoData.count > AppConstants.maxVideoFileSizeBytes {
                    await MainActor.run {
                        isProcessingVideo = false
                        store.send(.videoProcessingFailed(.business(.videoTooLarge)))
                    }
                    return
                }

                let thumbnailData = await generateThumbnail(from: asset)

                await MainActor.run {
                    isProcessingVideo = false
                    store.send(.videoSelected(videoData, thumbnailData: thumbnailData, duration: durationSeconds))
                }
            } catch {
                await MainActor.run {
                    isProcessingVideo = false
                    let appError = error as? AppError ?? .unexpected(error.localizedDescription)
                    store.send(.videoProcessingFailed(appError))
                }
            }
        }
    }

    private func compressVideo(asset: AVURLAsset) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // ponytail: MediumQuality(~320p, 3분 ≈ 15MB) — 표정 디테일이 부족하다는 피드백이 오면
        // AVAssetWriter로 720p/1.8Mbps 커스텀 인코딩 (프리셋 960x540은 50MB 한도 초과 위험)
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw AppError.business(.invalidVideoFormat)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        guard exportSession.status == .completed else {
            if let error = exportSession.error {
                throw AppError.unexpected(error.localizedDescription)
            }
            throw AppError.business(.invalidVideoFormat)
        }

        return outputURL
    }

    private func generateThumbnail(from asset: AVURLAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)

        let time = CMTime(seconds: 1, preferredTimescale: 600)
        do {
            let (image, _) = try await generator.image(at: time)
            let uiImage = UIImage(cgImage: image)
            return uiImage.jpegData(compressionQuality: 0.7)
        } catch {
            return nil
        }
    }
}

#Preview {
    NavigationStack {
        VideoUploadView(
            store: Store(
                initialState: VideoUploadFeature.State(studyID: UUID())
            ) {
                VideoUploadFeature()
            }
        )
    }
}

// MARK: - VideoTransferable

private struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}
