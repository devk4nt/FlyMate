import SwiftUI
import PhotosUI
import ComposableArchitecture
import Kingfisher
import Core

public struct ProfileEditView: View {
    @Bindable var store: StoreOf<ProfileEditFeature>
    @State private var selectedPhotoItem: PhotosPickerItem?

    public init(store: StoreOf<ProfileEditFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: FMSpacing.lg) {
                profileHeader
                profileInformationCard

                if let error = store.error {
                    errorCard(message: error.errorDescription ?? "오류가 발생했습니다.")
                }
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.sm)
            .padding(.bottom, FMSpacing.xxxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FMColors.canvas)
        .navigationTitle("프로필 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { store.send(.cancelTapped) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            saveArea
        }
    }

    private var profileHeader: some View {
        VStack(spacing: FMSpacing.sm) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack(alignment: .bottomTrailing) {
                    avatarImage
                        .frame(width: 92, height: 92)
                        .clipShape(Circle())
                        .shadow(color: FMColors.primary.opacity(0.24), radius: 14, y: 7)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FMColors.primary)
                        .frame(width: 30, height: 30)
                        .background(FMColors.elevatedBackground)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(FMColors.canvas, lineWidth: 3)
                        }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로필 이미지 변경")
            .accessibilityHint("사진 보관함에서 새 프로필 이미지를 선택합니다.")
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                processSelectedImage(item)
            }

            VStack(spacing: FMSpacing.xxxs) {
                Text(store.name.isBlank ? store.currentUser.name : store.name)
                    .font(FMTypography.title2)
                    .foregroundStyle(FMColors.label)

                Text(store.currentUser.email)
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FMSpacing.md)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let data = store.selectedImageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let url = store.currentUser.profileImageURL {
            KFImage(url)
                .resizable()
                .placeholder { initialCircle }
                .aspectRatio(contentMode: .fill)
        } else {
            initialCircle
        }
    }

    private var initialCircle: some View {
        Circle()
            .fill(FMColors.brandGradient)
            .overlay {
                Text(profileInitial)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    private func processSelectedImage(_ item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            let resized = downscaled(image, maxDimension: AppConstants.profileImageMaxDimension)
            guard let jpegData = resized.jpegData(
                compressionQuality: AppConstants.profileImageCompressionQuality
            ) else { return }
            store.send(.imageSelected(jpegData))
        }
    }

    private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else { return image }
        let ratio = maxDimension / longestSide
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private var profileInformationCard: some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                sectionHeader(
                    icon: "person.text.rectangle",
                    title: "프로필 정보",
                    description: "다른 멤버에게 표시되는 이름이에요."
                )

                Divider()

                FMTextField(
                    title: "이름",
                    placeholder: "이름을 입력하세요",
                    text: $store.name.sending(\.nameChanged),
                    characterLimit: 30
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
        }
    }

    private func errorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: FMSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(FMColors.destructive)

            Text(message)
                .font(FMTypography.callout)
                .foregroundStyle(FMColors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(FMSpacing.md)
        .background(FMColors.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("오류: \(message)")
    }

    private var saveArea: some View {
        FMButton(
            title: "변경사항 저장",
            isLoading: store.isSubmitting,
            isEnabled: store.isValid && store.hasChanges
        ) {
            store.send(.saveTapped)
        }
        .padding(.horizontal, FMSpacing.md)
        .padding(.top, FMSpacing.xs)
        .padding(.bottom, FMSpacing.xs)
        .background(.ultraThinMaterial)
    }

    private func sectionHeader(icon: String, title: String, description: String) -> some View {
        HStack(spacing: FMSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FMColors.primary)
                .frame(width: 36, height: 36)
                .background(FMColors.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                Text(title)
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.label)

                Text(description)
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)
            }
        }
    }

    private var profileInitial: String {
        String((store.name.isBlank ? store.currentUser.name : store.name).prefix(1))
    }
}
