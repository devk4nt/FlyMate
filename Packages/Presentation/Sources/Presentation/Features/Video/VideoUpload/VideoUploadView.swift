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
        Form {
            Section("영상 정보") {
                FMTextField(
                    title: "제목",
                    placeholder: "영상 제목을 입력하세요",
                    text: $store.title.sending(\.titleChanged)
                )

                // 영상 선택 영역
                VStack(spacing: FMSpacing.sm) {
                    if store.selectedVideoData != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(FMColors.success)
                            Text("영상이 선택되었습니다")
                                .font(FMTypography.body)
                            Spacer()
                            Text(store.videoDuration.minuteSecondFormatted)
                                .font(FMTypography.caption1)
                                .foregroundStyle(FMColors.secondaryLabel)
                        }

                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .videos,
                            photoLibrary: .shared()
                        ) {
                            Text("다른 영상 선택")
                                .font(FMTypography.callout)
                                .foregroundStyle(FMColors.accent)
                        }
                    } else {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .videos,
                            photoLibrary: .shared()
                        ) {
                            VStack(spacing: FMSpacing.xs) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: FMSizing.IconSize.lg))
                                Text("영상 선택")
                                    .font(FMTypography.callout)
                            }
                            .foregroundStyle(FMColors.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(FMColors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md))
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text("촬영 포인트")
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.label)
                    TextEditor(text: $store.focusPoints.sending(\.focusPointsChanged))
                        .font(FMTypography.body)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                }
            } header: {
                Text("촬영 포인트")
            } footer: {
                Text("영상에서 중점적으로 촬영한 부분을 설명해주세요")
                    .font(FMTypography.caption2)
            }

            Section {
                VStack(alignment: .leading, spacing: FMSpacing.xs) {
                    Text("피드백 요청사항")
                        .font(FMTypography.callout)
                        .foregroundStyle(FMColors.label)
                    TextEditor(text: $store.feedbackRequest.sending(\.feedbackRequestChanged))
                        .font(FMTypography.body)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                }
            } header: {
                Text("피드백 요청")
            } footer: {
                Text("스터디원에게 받고 싶은 피드백을 작성해주세요")
                    .font(FMTypography.caption2)
            }

            if case .uploading = store.uploadState {
                Section("업로드 중") {
                    VStack(spacing: FMSpacing.xs) {
                        ProgressView(value: store.uploadProgress)
                        Text("\(Int(store.uploadProgress * 100))%")
                            .font(FMTypography.caption1)
                            .foregroundStyle(FMColors.secondaryLabel)
                    }
                }
            }

            if let error = store.error {
                Section {
                    Text(error.errorDescription ?? "오류가 발생했습니다.")
                        .foregroundStyle(FMColors.destructive)
                        .font(FMTypography.callout)
                }
            }
        }
        .navigationTitle("영상 업로드")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    store.send(.cancelTapped)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                FMButton(
                    title: "업로드",
                    style: .text,
                    isLoading: store.uploadState == .uploading,
                    isEnabled: store.isValid
                ) {
                    store.send(.uploadTapped)
                }
            }
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
