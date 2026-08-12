import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct RecruitCreateView: View {
    @Bindable var store: StoreOf<RecruitCreateFeature>

    private static let regions = [
        "서울", "경기", "인천", "부산", "대구", "광주", "대전", "울산", "세종",
        "강원", "충북", "충남", "전북", "전남", "경북", "경남", "제주",
    ]

    public init(store: StoreOf<RecruitCreateFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            FMColors.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: FMSpacing.md) {
                    basicInfoCard
                    meetingCard
                    scheduleCard
                    recruitConditionCard
                    contactCard
                    privacyNotice
                }
                .padding(.horizontal, FMSpacing.md)
                .padding(.top, FMSpacing.xs)
                .padding(.bottom, FMSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .navigationTitle(store.isEditMode ? "모집 글 수정" : "스터디원 모집")
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
                title: store.isEditMode ? "수정 완료" : "등록하기",
                isLoading: store.isSubmitting,
                isEnabled: store.isValid
            ) {
                store.send(.submitTapped)
            }
            .padding(.horizontal, FMSpacing.md)
            .padding(.top, FMSpacing.sm)
            .padding(.bottom, FMSpacing.xs)
            .background(.ultraThinMaterial)
            .accessibilityIdentifier("스터디_작성_등록")
        }
        .alert(
            "작성을 그만둘까요?",
            isPresented: Binding(
                get: { store.showDiscardAlert },
                set: { if !$0 { store.send(.discardCancelled) } }
            )
        ) {
            Button("계속 작성", role: .cancel) {
                store.send(.discardCancelled)
            }
            Button("그만두기", role: .destructive) {
                store.send(.discardConfirmed)
            }
        } message: {
            Text("입력한 내용은 저장되지 않아요.")
        }
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

    // MARK: - Cards

    private var basicInfoCard: some View {
        formCard(title: "기본 정보") {
            FMTextField(
                title: "스터디 제목",
                placeholder: "예: 국내 항공사 영상면접 스터디원 모집",
                text: $store.title,
                characterLimit: AppConstants.maxRecruitTitleLength
            )
            .accessibilityIdentifier("스터디_작성_제목")

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("분야")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)

                Picker("분야", selection: $store.field) {
                    Text("선택해주세요").tag(RecruitField?.none)
                    ForEach(RecruitField.allCases, id: \.self) { field in
                        Text(field.displayText).tag(RecruitField?.some(field))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("스터디_작성_분야")
            }

            VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                Text("스터디 소개")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.secondaryLabel)

                TextEditor(text: $store.description)
                    .font(FMTypography.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 112)
                    .padding(FMSpacing.xs)
                    .background(FMColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.md, style: .continuous))
                    .accessibilityLabel("스터디 소개")
                    .accessibilityIdentifier("스터디_작성_소개")
            }
        }
    }

    private var meetingCard: some View {
        formCard(title: "진행 방식") {
            Picker("진행 방식", selection: $store.meetingType) {
                ForEach(RecruitMeetingType.allCases, id: \.self) { type in
                    Text(type.displayText).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("스터디_작성_진행방식")

            if store.needsRegion {
                VStack(alignment: .leading, spacing: FMSpacing.xxs) {
                    Text("활동 지역")
                        .font(FMTypography.caption1)
                        .foregroundStyle(FMColors.secondaryLabel)

                    Picker("활동 지역", selection: $store.region) {
                        Text("선택해주세요").tag("")
                        ForEach(Self.regions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("스터디_작성_지역")
                }
            }
        }
    }

    private var scheduleCard: some View {
        formCard(title: "일정") {
            FMTextField(
                title: "활동 일정 (요일·시간·주기)",
                placeholder: "예: 매주 화·목 20시, 주 2회",
                text: $store.schedule
            )
            .accessibilityIdentifier("스터디_작성_일정")

            DatePicker(
                "시작 예정일",
                selection: $store.startDate,
                displayedComponents: .date
            )
            .font(FMTypography.body)
            .accessibilityIdentifier("스터디_작성_시작일")

            Toggle("종료 예정일 설정", isOn: $store.hasEndDate)
                .font(FMTypography.body)

            if store.hasEndDate {
                DatePicker(
                    "종료 예정일",
                    selection: $store.endDate,
                    in: store.startDate...,
                    displayedComponents: .date
                )
                .font(FMTypography.body)
            }
        }
    }

    private var recruitConditionCard: some View {
        formCard(title: "모집 조건") {
            HStack {
                Text("모집 인원")
                    .font(FMTypography.body)

                Spacer()

                Text("\(store.maxMembers)명")
                    .font(FMTypography.headline)
                    .foregroundStyle(FMColors.primary)
                    .monospacedDigit()

                Stepper(
                    "모집 인원",
                    value: $store.maxMembers,
                    in: 1...AppConstants.maxRecruitMembers
                )
                .labelsHidden()
                .accessibilityLabel("모집 인원 \(store.maxMembers)명")
                .accessibilityIdentifier("스터디_작성_모집인원")
            }

            DatePicker(
                "모집 마감일",
                selection: $store.deadline,
                displayedComponents: .date
            )
            .font(FMTypography.body)
            .accessibilityIdentifier("스터디_작성_마감일")

            if !store.isDateOrderValid {
                Text("마감일은 시작 예정일보다 이전이어야 해요.")
                    .font(FMTypography.caption2)
                    .foregroundStyle(FMColors.destructive)
            }

            FMTextField(
                title: "참여 조건",
                placeholder: "예: 승무원 준비 6개월 이상, 주 1회 영상 업로드 가능",
                text: $store.requirement
            )
            .accessibilityIdentifier("스터디_작성_참여조건")
        }
    }

    private var contactCard: some View {
        formCard(title: "참여 방법") {
            FMTextField(
                title: "참여·문의 방법",
                placeholder: "예: 댓글로 문의해주세요",
                text: $store.contactMethod
            )
            .accessibilityIdentifier("스터디_작성_문의방법")

            FMTextField(
                title: "오픈채팅 링크 (선택)",
                placeholder: "https://open.kakao.com/...",
                text: $store.linkText,
                errorMessage: store.isLinkValid ? nil : "http(s)로 시작하는 링크만 등록할 수 있어요"
            )
            .keyboardType(.URL)
            .accessibilityIdentifier("스터디_작성_링크")
        }
    }

    private var privacyNotice: some View {
        Label("전화번호, 이메일 등 개인정보는 본문에 적지 말아주세요.", systemImage: "exclamationmark.shield")
            .font(FMTypography.caption1)
            .foregroundStyle(FMColors.secondaryLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Styling Helpers

    private func formCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: FMSpacing.md) {
            Text(title)
                .font(FMTypography.headline)
                .foregroundStyle(FMColors.label)

            content()
        }
        .padding(FMSpacing.md)
        .background(FMColors.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.lg, style: .continuous))
    }
}
