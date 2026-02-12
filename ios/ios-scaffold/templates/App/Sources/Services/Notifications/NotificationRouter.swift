import Foundation
import os

// MARK: - Notification Payload

struct NotificationPayload: Equatable {
  enum PayloadType: String {
    case newItem
    case reminder
    case update
  }

  let type: PayloadType
  let targetId: String?

  init?(userInfo: [AnyHashable: Any]) {
    // Treat all values as untrusted input
    guard let typeString = userInfo["type"] as? String,
          let type = PayloadType(rawValue: typeString) else {
      return nil
    }

    self.type = type

    // Validate targetId if present
    if let targetId = userInfo["targetId"] as? String,
       targetId.count <= 100,
       targetId.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) {
      self.targetId = targetId
    } else {
      self.targetId = nil
    }
  }

  // For testing
  init(type: PayloadType, targetId: String? = nil) {
    self.type = type
    self.targetId = targetId
  }
}

// MARK: - Notification Router

@MainActor
final class NotificationRouter {
  static let shared = NotificationRouter()

  private let logger = AppLogger.notifications

  private init() {}

  func route(_ payload: NotificationPayload) async {
    logger.info("Routing notification: \(payload.type.rawValue, privacy: .public)")

    switch payload.type {
    case .newItem:
      await handleNewItem(targetId: payload.targetId)
    case .reminder:
      await handleReminder(targetId: payload.targetId)
    case .update:
      await handleUpdate()
    }
  }

  // MARK: - Route Handlers

  private func handleNewItem(targetId: String?) async {
    // TODO: Navigate to item detail if targetId provided
    logger.debug("Handle newItem, targetId: \(targetId ?? "nil", privacy: .private)")
  }

  private func handleReminder(targetId: String?) async {
    // TODO: Navigate to reminder
    logger.debug("Handle reminder, targetId: \(targetId ?? "nil", privacy: .private)")
  }

  private func handleUpdate() async {
    // TODO: Refresh data or show update prompt
    logger.debug("Handle update")
  }
}
