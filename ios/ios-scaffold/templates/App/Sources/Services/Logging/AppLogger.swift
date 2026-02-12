import Foundation
import os

enum AppLogger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.app"

  static let features = Logger(subsystem: subsystem, category: "features")
  static let persistence = Logger(subsystem: subsystem, category: "persistence")
  static let notifications = Logger(subsystem: subsystem, category: "notifications")
  static let network = Logger(subsystem: subsystem, category: "network")
}

// Usage examples:
//
// AppLogger.features.debug("Debug info")                           // Dev only
// AppLogger.features.info("User action completed")                 // Normal events
// AppLogger.features.warning("Unexpected state: \(state)")         // Recoverable issues
// AppLogger.features.error("Operation failed: \(error, privacy: .private)") // Errors
//
// Privacy levels:
// - .public: Safe to log (non-sensitive)
// - .private: Redacted in production logs (default for interpolations)
// - .sensitive: Always redacted
