import Foundation
import os
@preconcurrency import UserNotifications

@MainActor
final class NotificationService: NSObject, ObservableObject {

  @Published private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined
  @Published private(set) var deviceToken: String?

  private let logger = AppLogger.notifications
  private let environment = AppEnvironment.current

  override init() {
    super.init()
    UNUserNotificationCenter.current().delegate = self
  }

  // MARK: - Permission

  func requestPermission() async -> Bool {
    // In debug without signing, simulate success
    if environment.isDebug, !isSigningAvailable {
      logger.info("[STUB] Permission request simulated as granted")
      permissionStatus = .authorized
      return true
    }

    do {
      let granted = try await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .badge, .sound])
      await updatePermissionStatus()
      logger.info("Notification permission: \(granted ? "granted" : "denied")")
      return granted
    } catch {
      logger.error("Permission request failed: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }

  func updatePermissionStatus() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    permissionStatus = settings.authorizationStatus
  }

  // MARK: - Token Registration

  nonisolated func didRegisterForRemoteNotifications(deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()

    Task { @MainActor in
      self.deviceToken = token
    }

    let isDebug = AppEnvironment.current.isDebug
    if isDebug {
      Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.appname", category: "notifications")
        .info("[STUB] Would send token to server: \(token.prefix(16), privacy: .public)...")
      // TODO: Implement actual token registration when backend ready
    } else {
      Task {
        await registerTokenWithServer(token)
      }
    }
  }

  nonisolated func didFailToRegisterForRemoteNotifications(error: Error) {
    Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.appname", category: "notifications")
      .error("Token registration failed: \(error.localizedDescription, privacy: .public)")
  }

  // MARK: - Local Notifications (for testing)

  func scheduleTestNotification(title: String, body: String, delay: TimeInterval = 5) {
    guard environment.isDebug else { return }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: trigger
    )

    let logger = self.logger
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        logger.error("Failed to schedule test notification: \(error.localizedDescription, privacy: .public)")
      } else {
        logger.info("Test notification scheduled for \(delay)s")
      }
    }
  }

  // MARK: - Private

  private var isSigningAvailable: Bool {
    // Check if we have a valid provisioning profile
    Bundle.main.object(forInfoDictionaryKey: "ProvisioningProfile") != nil
  }

  private func registerTokenWithServer(_ token: String) async {
    // TODO: Implement when backend ready
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let userInfo = response.notification.request.content.userInfo

    guard let payload = NotificationPayload(userInfo: userInfo) else {
      return
    }

    await NotificationRouter.shared.route(payload)
  }
}
