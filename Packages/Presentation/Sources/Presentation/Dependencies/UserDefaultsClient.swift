import Foundation
import ComposableArchitecture

public struct UserDefaultsClient: Sendable {
    public var boolForKey: @Sendable (String) -> Bool
    public var setBool: @Sendable (Bool, String) async -> Void
    public var integerForKey: @Sendable (String) -> Int
    public var setInteger: @Sendable (Int, String) async -> Void

    public init(
        boolForKey: @escaping @Sendable (String) -> Bool,
        setBool: @escaping @Sendable (Bool, String) async -> Void,
        integerForKey: @escaping @Sendable (String) -> Int,
        setInteger: @escaping @Sendable (Int, String) async -> Void
    ) {
        self.boolForKey = boolForKey
        self.setBool = setBool
        self.integerForKey = integerForKey
        self.setInteger = setInteger
    }
}

extension UserDefaultsClient: TestDependencyKey {
    public static let testValue = UserDefaultsClient(
        boolForKey: unimplemented("\(Self.self).boolForKey", placeholder: false),
        setBool: unimplemented("\(Self.self).setBool"),
        integerForKey: unimplemented("\(Self.self).integerForKey", placeholder: 0),
        setInteger: unimplemented("\(Self.self).setInteger")
    )
}

extension DependencyValues {
    public var userDefaultsClient: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
