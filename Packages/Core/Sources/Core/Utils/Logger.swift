import Foundation
import OSLog

/// 앱 전역 로깅 유틸리티.
/// os.log 기반으로 카테고리별 로그를 남긴다.
public enum FMLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.flymate"

    public enum Category: String {
        case network
        case auth
        case video
        case feedback
        case study
        case notification
        case ui
        case general
    }

    private static func logger(for category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    public static func debug(_ message: String, category: Category = .general) {
        logger(for: category).debug("\(message)")
    }

    public static func info(_ message: String, category: Category = .general) {
        logger(for: category).info("\(message)")
    }

    public static func warning(_ message: String, category: Category = .general) {
        logger(for: category).warning("\(message)")
    }

    public static func error(_ message: String, category: Category = .general) {
        logger(for: category).error("\(message)")
    }
}
