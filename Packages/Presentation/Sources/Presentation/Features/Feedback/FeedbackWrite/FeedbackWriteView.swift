import SwiftUI
import ComposableArchitecture
import Core
import Domain

public struct FeedbackWriteView: View {
    @Bindable var store: StoreOf<FeedbackWriteFeature>

    public init(store: StoreOf<FeedbackWriteFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: FMSpacing.md) {
            // 타임스탬프 표시
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(FMColors.accent)
                Text(store.timestampSeconds.minuteSecondFormatted)
                    .font(FMTypography.headline)
                Spacer()
            }
            .padding(.horizontal, FMSpacing.md)

            // 피드백 입력
            VStack(alignment: .trailing, spacing: FMSpacing.xxs) {
                ZStack(alignment: .bottom) {
                    FMMentionTextEditor(
                        text: $store.content.sending(\.contentChanged)
                    )
                    .frame(minHeight: 120)
                    .padding(FMSpacing.xs)
                    .background(FMColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))

                    if store.showMentionSuggestions {
                        mentionSuggestionsView
                    }
                }

                Text("\(store.content.count)/\(AppConstants.maxFeedbackLength)")
                    .font(FMTypography.caption2)
                    .foregroundStyle(
                        store.content.count > AppConstants.maxFeedbackLength
                            ? FMColors.destructive
                            : FMColors.secondaryLabel
                    )
            }
            .padding(.horizontal, FMSpacing.md)

            if let error = store.error {
                Text(error.errorDescription ?? "오류가 발생했습니다.")
                    .font(FMTypography.caption1)
                    .foregroundStyle(FMColors.destructive)
                    .padding(.horizontal, FMSpacing.md)
            }

            Spacer()
        }
        .padding(.top, FMSpacing.md)
        .navigationTitle("피드백 작성")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { store.send(.cancelTapped) }
            }
            ToolbarItem(placement: .confirmationAction) {
                FMButton(
                    title: "등록",
                    style: .text,
                    isLoading: store.isSubmitting,
                    isEnabled: store.isValid
                ) {
                    store.send(.submitTapped)
                }
            }
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Mention Suggestions

    private var mentionSuggestionsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // @전체 옵션
                    Button {
                        store.send(.mentionAllTapped)
                    } label: {
                        HStack(spacing: FMSpacing.sm) {
                            Image(systemName: "person.3.fill")
                                .font(FMTypography.caption1)
                                .foregroundStyle(FMColors.accent)
                                .frame(width: 28, height: 28)

                            Text("전체 (@전체)")
                                .font(FMTypography.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(FMColors.label)

                            Spacer()
                        }
                        .padding(.horizontal, FMSpacing.sm)
                        .padding(.vertical, FMSpacing.xs)
                    }

                    Divider()

                    // 개별 멤버 목록
                    ForEach(store.filteredMembers) { member in
                        Button {
                            store.send(.mentionSuggestionTapped(member))
                        } label: {
                            HStack(spacing: FMSpacing.sm) {
                                memberProfileImage(member)

                                Text(member.userName)
                                    .font(FMTypography.callout)
                                    .foregroundStyle(FMColors.label)

                                Spacer()
                            }
                            .padding(.horizontal, FMSpacing.sm)
                            .padding(.vertical, FMSpacing.xs)
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .background(FMColors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: FMSpacing.CornerRadius.sm))
        .shadow(color: .black.opacity(0.1), radius: 4, y: -2)
        .padding(.horizontal, FMSpacing.xxs)
        .padding(.bottom, FMSpacing.xxs)
    }

    private func memberProfileImage(_ member: StudyMember) -> some View {
        FMProfileImage(url: member.profileImageURL, name: member.userName, size: .sm)
    }
}

