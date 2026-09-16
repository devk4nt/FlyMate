import Foundation
import ComposableArchitecture
import Domain

public struct InterviewInsightClient: Sendable {
    public var generateInsight: @Sendable (InterviewInsightRequest) async throws -> InterviewInsight

    public init(
        generateInsight: @escaping @Sendable (InterviewInsightRequest) async throws -> InterviewInsight
    ) {
        self.generateInsight = generateInsight
    }
}

extension InterviewInsightClient: TestDependencyKey {
    public static let testValue = InterviewInsightClient(
        generateInsight: unimplemented("\(Self.self).generateInsight")
    )
}

extension DependencyValues {
    public var interviewInsightClient: InterviewInsightClient {
        get { self[InterviewInsightClient.self] }
        set { self[InterviewInsightClient.self] = newValue }
    }
}
