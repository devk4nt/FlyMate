import SwiftUI
import UIKit

extension View {
    /// 입력창 밖 영역을 탭하면 키보드를 내린다.
    /// Button 등 자식 뷰의 제스처가 우선되므로 기존 인터랙션에는 영향이 없다.
    public func dismissKeyboardOnTap() -> some View {
        contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
    }
}
