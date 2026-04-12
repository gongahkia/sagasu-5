import Foundation
import OSLog

public extension Logger {
    static let sagasuSubsystem = "com.gongahkia.sagasu"

    static func sagasu(category: String) -> Logger {
        Logger(subsystem: sagasuSubsystem, category: category)
    }
}
