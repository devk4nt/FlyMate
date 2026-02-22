import SwiftUI
import ComposableArchitecture
import Core

public struct StudyManagementView: View {
    @Bindable var store: StoreOf<StudyManagementFeature>

    public init(store: StoreOf<StudyManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            switch store.studies {
            case .idle, .loading:
                ProgressView()

            case .loaded(let studies):
                if studies.isEmpty {
                    FMEmptyState(
                        systemImage: "person.3",
                        title: "참여 중인 스터디가 없습니다",
                        description: "스터디에 참여하면 여기서 관리할 수 있어요."
                    )
                } else {
                    List {
                        ForEach(studies) { study in
                            HStack {
                                VStack(alignment: .leading, spacing: FMSpacing.xxxs) {
                                    Text(study.name)
                                        .font(FMTypography.headline)
                                    Text("\(study.memberCount)명 참여 중")
                                        .font(FMTypography.caption1)
                                        .foregroundStyle(FMColors.secondaryLabel)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    store.send(.leaveStudyTapped(study.id))
                                } label: {
                                    Text("탈퇴")
                                        .font(FMTypography.callout)
                                }
                            }
                        }
                    }
                }

            case .failed(let error):
                FMErrorView(error: error) {
                    store.send(.onAppear)
                }
            }
        }
        .navigationTitle("스터디 관리")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .alert($store.scope(state: \.confirmAlert, action: \.confirmAlert))
    }
}
