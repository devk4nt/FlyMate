import SwiftUI
import ComposableArchitecture
import Core

public struct VideoUploadView: View {
    @Bindable var store: StoreOf<VideoUploadFeature>

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
                    } else {
                        Button {
                            #if DEBUG
                            let mockData = Data(repeating: 0, count: 1024)
                            store.send(.videoSelected(mockData, duration: 120))
                            #else
                            // TODO: PhotosPicker 연동
                            #endif
                        } label: {
                            VStack(spacing: FMSpacing.xs) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 32))
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
    }
}
