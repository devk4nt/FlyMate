import SwiftUI
import ComposableArchitecture

public struct StudyNavigationView: View {
    @Bindable var store: StoreOf<StudyNavigationFeature>

    public init(store: StoreOf<StudyNavigationFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            StudyListView(
                store: store.scope(state: \.studyList, action: \.studyList)
            )
        } destination: { store in
            switch store.case {
            case .studyDetail(let detailStore):
                StudyDetailView(store: detailStore)
            case .videoFeed(let feedStore):
                VideoFeedView(store: feedStore)
                    .toolbar(.hidden, for: .tabBar)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
            case .videoUpload(let uploadStore):
                VideoUploadView(store: uploadStore)
            case .memberManagement(let memberStore):
                MemberManagementView(store: memberStore)
            case .joinRequestManagement(let requestStore):
                JoinRequestManagementView(store: requestStore)
            }
        }
    }
}
