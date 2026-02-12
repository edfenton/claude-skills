import Foundation

enum AppEnvironment: String, CaseIterable {
  case nonProd = "non-prod"
  case prod

  static var current: AppEnvironment {
    // Read from xcconfig via Info.plist
    guard let value = Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
          let environment = AppEnvironment(rawValue: value) else {
      // Default to non-prod if not configured
      return .nonProd
    }
    return environment
  }

  var isDebug: Bool {
    self == .nonProd
  }

  // swiftlint:disable:next force_unwrapping
  private static let nonProdURL = URL(string: "https://api.nonprod.example.com")!
  // swiftlint:disable:next force_unwrapping
  private static let prodURL = URL(string: "https://api.example.com")!

  var apiBaseURL: URL {
    switch self {
    case .nonProd:
      Self.nonProdURL
    case .prod:
      Self.prodURL
    }
  }

  var logLevel: LogLevel {
    switch self {
    case .nonProd:
      .debug
    case .prod:
      .info
    }
  }
}

enum LogLevel: Int, Comparable {
  case debug = 0
  case info = 1
  case warning = 2
  case error = 3

  static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
