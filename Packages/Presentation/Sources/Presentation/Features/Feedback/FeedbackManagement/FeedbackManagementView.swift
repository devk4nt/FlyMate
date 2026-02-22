import SwiftUI
import ComposableArchitecture

public struct FeedbackManagementView: View {
    @Bindable var store: StoreOf<FeedbackManagementFeature>

    public init(store: StoreOf<FeedbackManagementFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 세그먼트 컨트롤
                Picker("", selection: $store.selectedSegment.sending(\.segmentChanged)) {
                    ForEach(FeedbackManagementFeature.State.Segment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(FMSpacing.md)

                // 선택된 탭 내용
                switch store.selectedSegment {
                case .received:
                    FeedbackListView(
                        store: store.scope(state: \.received, action: \.received)
                    )
                case .given:
                    FeedbackListView(
                        store: store.scope(state: \.given, action: \.given)
                    )
                }
            }
            .navigationTitle("피드백")
        }
    }
}
