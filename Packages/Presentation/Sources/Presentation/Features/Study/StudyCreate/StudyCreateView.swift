import SwiftUI
import ComposableArchitecture
import Core

public struct StudyCreateView: View {
    @Bindable var store: StoreOf<StudyCreateFeature>

    public init(store: StoreOf<StudyCreateFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            FMColors.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: FMSpacing.md) {
                    introHeader
                    studyInformationCard
                    memberCountCard
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
                .padding(.bottom, FMSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .navigationTitle("스터디 만들기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    store.send(.cancelTapped)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            FMButton(
                title: "스터디 만들기",
                isLoading: store.isSubmitting,
                isEnabled: store.isValid
            ) {
                store.send(.submitTapped)
            }
            .fmSheetBottomBar()
        }
        .fmSheetStyle()
        .alert(
            "오류",
            isPresented: Binding(
                get: { store.error != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            )
        ) {
            Button("확인") {
                store.send(.errorDismissed)
            }
        } message: {
            if let error = store.error {
                Text(error.localizedDescription)
            }
        }
    }

    private var introHeader: some View {
        HStack(spacing: FMSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous)
                    .fill(FMColors.brandGradient)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: FMSizing.IconContainer.hero, height: FMSizing.IconContainer.hero)
            .shadow(color: FMShadow.floatingColor, radius: FMShadow.floatingRadius, y: FMShadow.floatingY)

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text(store.isRecruitmentPrefilled ? "스터디방을 열어 참여자를 맞이하세요" : "새로운 팀을 시작해요")
                    .font(FMTypography.title2)
                    .foregroundStyle(FMColors.label)

                Text(
                    store.isRecruitmentPrefilled
                        ? "모집 글 정보를 미리 채웠어요. 확인 후 바로 시작할 수 있어요."
                        : "영상을 공유하고 피드백과 알림을 한곳에서 관리하세요."
                )
                    .font(FMTypography.callout)
                    .foregroundStyle(FMColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, FMSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var studyInformationCard: some View {
        formCard(title: "스터디 정보", step: "01") {
            FMTextField(
                title: "스터디 이름",
                placeholder: "예: 항공사 면접 스피치 스터디",
                text: $store.name.sending(\.nameChanged),
                characterLimit: AppConstants.maxStudyNameLength
            )

            VStack(alignment: .leading, spacing: FMSpacing.xs) {
                Text("스터디 소개")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)

                ZStack(alignment: .topLeading) {
                    if store.description.isEmpty {
                        Text("어떤 목표로 활동하는 스터디인지 알려주세요")
                            .font(FMTypography.body)
                            .foregroundStyle(FMColors.secondaryLabel.opacity(0.65))
                            .padding(.horizontal, FMSpacing.sm)
                            .padding(.vertical, FMSpacing.sm)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $store.description.sending(\.descriptionChanged))
                        .font(FMTypography.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 112)
                        .padding(FMSpacing.xs)
                }
                .fmInputSurface()
            }
        }
    }

    private var memberCountCard: some View {
        formCard(title: "함께할 인원", step: "02") {
            HStack(spacing: FMSpacing.md) {
                ZStack {
                    Circle()
                        .fill(FMColors.iconAccent.opacity(0.1))

                    Image(systemName: "person.2.fill")
                        .foregroundStyle(FMColors.iconAccent)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                    Text("최대 인원")
                        .font(FMTypography.headline)
                    Text("운영자를 포함한 전체 인원이에요")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)
                }

                Spacer()

                Text("\(store.maxMembers)명")
                    .font(FMTypography.title3)
                    .foregroundStyle(FMColors.badgeForeground)
                    .monospacedDigit()
                    .frame(minWidth: 38)

                Stepper(
                    "최대 인원",
                    value: $store.maxMembers.sending(\.maxMembersChanged),
                    in: 2...AppConstants.maxStudyMembers
                )
                .labelsHidden()
                .accessibilityLabel("최대 인원 \(store.maxMembers)명")
            }
        }
    }

    private func formCard<Content: View>(
        title: String,
        step: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        FMCard {
            VStack(alignment: .leading, spacing: FMSpacing.md) {
                HStack {
                    Text(title)
                        .font(FMTypography.headline)
                        .foregroundStyle(FMColors.label)

                    Spacer()

                    Text(step)
                        .font(FMTypography.feedMetaEmphasis)
                        .foregroundStyle(FMColors.badgeForeground)
                        .padding(.horizontal, FMSpacing.xs)
                        .padding(.vertical, FMSpacing.xxs)
                        .background(FMColors.badgeForeground.opacity(0.1))
                        .clipShape(Capsule())
                }

                content()
            }
        }
    }
}

#Preview {
    NavigationStack {
        StudyCreateView(
            store: Store(initialState: StudyCreateFeature.State()) {
                StudyCreateFeature()
            }
        )
    }
}
