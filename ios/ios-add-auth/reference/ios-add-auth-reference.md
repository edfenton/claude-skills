# iOS Add Auth Reference

Authentication implementation with Sign in with Apple, biometrics, and Keychain.

---

## Auth State

```swift
// Services/Auth/AuthState.swift
import Foundation

enum AuthState: Equatable {
  case unknown
  case unauthenticated
  case authenticated(User)

  var isAuthenticated: Bool {
    if case .authenticated = self { return true }
    return false
  }

  var user: User? {
    if case .authenticated(let user) = self { return user }
    return nil
  }
}
```

---

## User Model

```swift
// Models/User.swift
import Foundation

struct User: Codable, Equatable, Identifiable {
  let id: String
  let email: String?
  let fullName: PersonNameComponents?
  let createdAt: Date

  var displayName: String {
    if let fullName {
      return PersonNameComponentsFormatter.localizedString(from: fullName, style: .default)
    }
    return email ?? "User"
  }

  init(id: String, email: String?, fullName: PersonNameComponents?, createdAt: Date = Date()) {
    self.id = id
    self.email = email
    self.fullName = fullName
    self.createdAt = createdAt
  }
}
```

---

## Keychain Manager

```swift
// Services/Auth/KeychainManager.swift
import Foundation
import Security
import os

final class KeychainManager {
  static let shared = KeychainManager()

  private let logger = AppLogger.auth
  private let service = Bundle.main.bundleIdentifier ?? "com.app"

  private init() {}

  // MARK: - Token Storage

  func saveToken(_ token: String, for key: String) throws {
    let data = Data(token.utf8)

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]

    // Delete existing
    SecItemDelete(query as CFDictionary)

    // Add new
    var newItem = query
    newItem[kSecValueData as String] = data
    newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    let status = SecItemAdd(newItem as CFDictionary, nil)

    guard status == errSecSuccess else {
      logger.error("Failed to save to Keychain: \(status)")
      throw KeychainError.saveFailed(status)
    }

    logger.debug("Token saved to Keychain for key: \(key, privacy: .public)")
  }

  func getToken(for key: String) throws -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data,
            let token = String(data: data, encoding: .utf8) else {
        return nil
      }
      return token

    case errSecItemNotFound:
      return nil

    default:
      logger.error("Failed to read from Keychain: \(status)")
      throw KeychainError.readFailed(status)
    }
  }

  func deleteToken(for key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]

    let status = SecItemDelete(query as CFDictionary)

    guard status == errSecSuccess || status == errSecItemNotFound else {
      logger.error("Failed to delete from Keychain: \(status)")
      throw KeychainError.deleteFailed(status)
    }

    logger.debug("Token deleted from Keychain for key: \(key, privacy: .public)")
  }

  func deleteAll() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]

    let status = SecItemDelete(query as CFDictionary)

    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.deleteFailed(status)
    }
  }

  // MARK: - User Storage

  func saveUser(_ user: User) throws {
    let data = try JSONEncoder().encode(user)

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "current_user",
    ]

    SecItemDelete(query as CFDictionary)

    var newItem = query
    newItem[kSecValueData as String] = data
    newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    let status = SecItemAdd(newItem as CFDictionary, nil)

    guard status == errSecSuccess else {
      throw KeychainError.saveFailed(status)
    }
  }

  func getUser() throws -> User? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: "current_user",
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data else { return nil }
      return try JSONDecoder().decode(User.self, from: data)

    case errSecItemNotFound:
      return nil

    default:
      throw KeychainError.readFailed(status)
    }
  }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
  case saveFailed(OSStatus)
  case readFailed(OSStatus)
  case deleteFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .saveFailed(let status):
      return "Failed to save to Keychain (status: \(status))"
    case .readFailed(let status):
      return "Failed to read from Keychain (status: \(status))"
    case .deleteFailed(let status):
      return "Failed to delete from Keychain (status: \(status))"
    }
  }
}
```

---

## Biometric Auth Manager

```swift
// Services/Auth/BiometricAuthManager.swift
import LocalAuthentication
import os

final class BiometricAuthManager {
  static let shared = BiometricAuthManager()

  private let logger = AppLogger.auth

  private init() {}

  // MARK: - Availability

  var biometryType: LABiometryType {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      return .none
    }
    return context.biometryType
  }

  var isAvailable: Bool {
    biometryType != .none
  }

  var biometryName: String {
    switch biometryType {
    case .faceID:
      return "Face ID"
    case .touchID:
      return "Touch ID"
    case .opticID:
      return "Optic ID"
    @unknown default:
      return "Biometrics"
    }
  }

  // MARK: - Authentication

  func authenticate(reason: String) async -> Result<Void, BiometricError> {
    let context = LAContext()
    context.localizedCancelTitle = "Use Password"

    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      let biometricError = mapError(error)
      logger.warning("Biometrics unavailable: \(biometricError.localizedDescription, privacy: .public)")
      return .failure(biometricError)
    }

    do {
      let success = try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: reason
      )

      if success {
        logger.info("Biometric authentication successful")
        return .success(())
      } else {
        return .failure(.authenticationFailed)
      }
    } catch let error as LAError {
      let biometricError = mapLAError(error)
      logger.warning("Biometric authentication failed: \(biometricError.localizedDescription, privacy: .public)")
      return .failure(biometricError)
    } catch {
      return .failure(.unknown)
    }
  }

  // MARK: - Error Mapping

  private func mapError(_ error: NSError?) -> BiometricError {
    guard let error = error as? LAError else {
      return .notAvailable
    }
    return mapLAError(error)
  }

  private func mapLAError(_ error: LAError) -> BiometricError {
    switch error.code {
    case .biometryNotAvailable:
      return .notAvailable
    case .biometryNotEnrolled:
      return .notEnrolled
    case .biometryLockout:
      return .lockedOut
    case .userCancel:
      return .userCancelled
    case .userFallback:
      return .userFallback
    case .authenticationFailed:
      return .authenticationFailed
    default:
      return .unknown
    }
  }
}

// MARK: - Errors

enum BiometricError: LocalizedError {
  case notAvailable
  case notEnrolled
  case lockedOut
  case userCancelled
  case userFallback
  case authenticationFailed
  case unknown

  var errorDescription: String? {
    switch self {
    case .notAvailable:
      return "Biometric authentication is not available on this device."
    case .notEnrolled:
      return "No biometrics enrolled. Please set up Face ID or Touch ID in Settings."
    case .lockedOut:
      return "Biometric authentication is locked. Please use your passcode."
    case .userCancelled:
      return "Authentication was cancelled."
    case .userFallback:
      return "User chose to use password instead."
    case .authenticationFailed:
      return "Authentication failed. Please try again."
    case .unknown:
      return "An unknown error occurred."
    }
  }

  var requiresPasscode: Bool {
    switch self {
    case .lockedOut, .userFallback:
      return true
    default:
      return false
    }
  }
}
```

---

## Sign in with Apple Manager

```swift
// Services/Auth/SignInWithAppleManager.swift
import AuthenticationServices
import os

final class SignInWithAppleManager: NSObject {
  private let logger = AppLogger.auth
  private var continuation: CheckedContinuation<ASAuthorization, Error>?

  func signIn() async throws -> ASAuthorization {
    return try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation

      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = [.fullName, .email]

      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = self
      controller.performRequests()
    }
  }

  func extractUser(from authorization: ASAuthorization) -> User? {
    guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      return nil
    }

    return User(
      id: credential.user,
      email: credential.email,
      fullName: credential.fullName
    )
  }

  // Check if existing Sign in with Apple credential is still valid
  func checkCredentialState(userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
    await withCheckedContinuation { continuation in
      ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
        continuation.resume(returning: state)
      }
    }
  }
}

// MARK: - ASAuthorizationControllerDelegate

extension SignInWithAppleManager: ASAuthorizationControllerDelegate {
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    logger.info("Sign in with Apple succeeded")
    continuation?.resume(returning: authorization)
    continuation = nil
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    logger.error("Sign in with Apple failed: \(error.localizedDescription, privacy: .public)")
    continuation?.resume(throwing: error)
    continuation = nil
  }
}
```

---

## Auth Service

```swift
// Services/Auth/AuthService.swift
import Foundation
import os

@MainActor
final class AuthService: ObservableObject {
  @Published private(set) var state: AuthState = .unknown

  private let keychain = KeychainManager.shared
  private let biometrics = BiometricAuthManager.shared
  private let appleSignIn = SignInWithAppleManager()
  private let logger = AppLogger.auth

  // MARK: - Initialization

  func initialize() async {
    // Check for existing session
    do {
      if let user = try keychain.getUser() {
        // Verify Apple credential still valid (if signed in with Apple)
        let credentialState = await appleSignIn.checkCredentialState(userID: user.id)

        switch credentialState {
        case .authorized:
          state = .authenticated(user)
          logger.info("Restored session for user: \(user.id, privacy: .private)")

        case .revoked, .notFound:
          logger.info("Session expired or revoked")
          try? keychain.deleteAll()
          state = .unauthenticated

        default:
          state = .authenticated(user)
        }
      } else {
        state = .unauthenticated
      }
    } catch {
      logger.error("Failed to restore session: \(error.localizedDescription, privacy: .public)")
      state = .unauthenticated
    }
  }

  // MARK: - Sign In

  func signInWithApple() async throws {
    let authorization = try await appleSignIn.signIn()

    guard let user = appleSignIn.extractUser(from: authorization) else {
      throw AuthError.invalidCredential
    }

    // Save user to Keychain
    try keychain.saveUser(user)

    // Extract and save identity token if backend validation needed
    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
       let tokenData = credential.identityToken,
       let token = String(data: tokenData, encoding: .utf8) {
      try keychain.saveToken(token, for: "identity_token")
    }

    state = .authenticated(user)
    logger.info("Signed in with Apple: \(user.id, privacy: .private)")
  }

  // MARK: - Biometric Unlock

  func unlockWithBiometrics() async -> Result<Void, BiometricError> {
    guard case .authenticated = state else {
      return .failure(.notAvailable)
    }

    return await biometrics.authenticate(reason: "Unlock the app")
  }

  // MARK: - Sign Out

  func signOut() {
    do {
      try keychain.deleteAll()
      state = .unauthenticated
      logger.info("Signed out")
    } catch {
      logger.error("Failed to clear Keychain: \(error.localizedDescription, privacy: .public)")
      // Still set state to unauthenticated
      state = .unauthenticated
    }
  }
}

// MARK: - Errors

enum AuthError: LocalizedError {
  case invalidCredential
  case networkError
  case serverError(String)

  var errorDescription: String? {
    switch self {
    case .invalidCredential:
      return "Invalid credentials received."
    case .networkError:
      return "Network error. Please check your connection."
    case .serverError(let message):
      return message
    }
  }
}
```

---

## Sign In View

```swift
// Features/Auth/SignInView.swift
import SwiftUI
import AuthenticationServices

struct SignInView: View {
  @EnvironmentObject private var authService: AuthService
  @State private var isLoading = false
  @State private var error: Error?

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      // Logo / Welcome
      VStack(spacing: 16) {
        Image(systemName: "app.fill")
          .font(.system(size: 80))
          .foregroundStyle(.accent)

        Text("Welcome")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text("Sign in to continue")
          .font(.body)
          .foregroundStyle(.secondary)
      }

      Spacer()

      // Sign in with Apple button
      SignInWithAppleButton(.signIn) { request in
        request.requestedScopes = [.fullName, .email]
      } onCompletion: { result in
        handleSignInResult(result)
      }
      .signInWithAppleButtonStyle(.black)
      .frame(height: 50)
      .cornerRadius(12)
      .disabled(isLoading)

      // Loading indicator
      if isLoading {
        ProgressView()
      }

      Spacer()
        .frame(height: 50)
    }
    .padding(.horizontal, 24)
    .alert("Sign In Failed", isPresented: .constant(error != nil)) {
      Button("OK") { error = nil }
    } message: {
      if let error {
        Text(error.localizedDescription)
      }
    }
  }

  private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .success:
      Task {
        isLoading = true
        do {
          try await authService.signInWithApple()
        } catch {
          self.error = error
        }
        isLoading = false
      }

    case .failure(let error):
      // Ignore user cancellation
      if (error as? ASAuthorizationError)?.code != .canceled {
        self.error = error
      }
    }
  }
}

#Preview {
  SignInView()
    .environmentObject(AuthService())
}
```

---

## Authenticated Container

```swift
// Features/Auth/AuthenticatedContainer.swift
import SwiftUI

struct AuthenticatedContainer<Content: View>: View {
  @EnvironmentObject private var authService: AuthService
  @ViewBuilder let content: () -> Content

  var body: some View {
    Group {
      switch authService.state {
      case .unknown:
        ProgressView("Loading...")

      case .unauthenticated:
        SignInView()

      case .authenticated:
        content()
      }
    }
    .task {
      await authService.initialize()
    }
  }
}

// Usage in App:
// AuthenticatedContainer {
//   MainTabView()
// }
// .environmentObject(authService)
```

---

## Info.plist Entries

```xml
<!-- Required for Face ID -->
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to quickly and securely unlock the app.</string>
```

---

## DependencyContainer Integration

```swift
// Infrastructure/DependencyContainer.swift

@MainActor
final class DependencyContainer: ObservableObject {
  let authService: AuthService

  init() {
    self.authService = AuthService()
    // ... other services
  }
}
```

---

## App Entry Point

```swift
// AppEntry/AppNameApp.swift
import SwiftUI

@main
struct AppNameApp: App {
  @StateObject private var dependencies = DependencyContainer()

  var body: some Scene {
    WindowGroup {
      AuthenticatedContainer {
        HomeView(viewModel: dependencies.makeHomeViewModel())
      }
      .environmentObject(dependencies.authService)
    }
  }
}
```

---

## Testing Auth

```swift
// Mock for tests
final class MockAuthService: AuthService {
  var mockState: AuthState = .unauthenticated

  override var state: AuthState {
    mockState
  }

  override func initialize() async {
    // No-op for tests
  }

  override func signInWithApple() async throws {
    mockState = .authenticated(User(id: "test", email: "test@example.com", fullName: nil))
  }

  override func signOut() {
    mockState = .unauthenticated
  }
}
```
