import Foundation
import ComposableArchitecture

public struct UserDefaultsClient: Sendable {
    public var boolForKey: @Sendable (String) -> Bool
    public var setBool: @Sendable (Bool, String) async -> Void

    public init(
        boolForKey: @escaping @Sendable (String) -> Bool,
        setBool: @escaping @Sendable (Bool, String) async -> Void
    ) {
        self.boolForKey = boolForKey
        self.setBool = setBool
    }
}

extension UserDefaultsClient: TestDependencyKey {
    public static let testValue = UserDefaultsClient(
        boolForKey: unimplemented("\(Self.self).boolForKey", placeholder: false),
        setBool: unimplemented("\(Self.self).setBool")
    )
}

extension DependencyValues {
    public var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
