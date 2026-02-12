# iOS Security Reference

Detailed implementation patterns for OWASP Top 10, Mobile Top 10, and CWE mitigations. Load when implementing specific security controls.

---

## OWASP Mobile Top 10 (2024) — iOS mitigations

### M1: Improper Credential Usage

- Store credentials in Keychain, never UserDefaults or files
- Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for sensitive items

```swift
func saveToKeychain(key: String, data: Data) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.saveFailed(status)
    }
}
```

### M2: Inadequate Supply Chain Security

- Verify dependencies with Swift Package Manager checksums
- Review third-party SDK permissions and data collection
- Keep dependencies updated; audit with `swift package audit` (if available) or manual review

### M3: Insecure Authentication/Authorization

- Use ASWebAuthenticationSession for OAuth flows
- Validate tokens server-side; don't trust client-only validation
- Implement proper session timeout and refresh logic

```swift
class AuthManager {
    func validateSession() async throws -> Bool {
        guard let token = try? KeychainManager.getToken(),
              !token.isExpired else {
            return false
        }
        // Validate with server
        return try await api.validateToken(token)
    }
}
```

### M4: Insufficient Input/Output Validation

- Validate deep link parameters before use:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let host = components.host,
          allowedHosts.contains(host) else {
        return false
    }

    // Validate and sanitize query parameters
    guard let params = components.queryItems,
          let action = params.first(where: { $0.name == "action" })?.value,
          allowedActions.contains(action) else {
        return false
    }

    return handleDeepLink(action: action, params: params)
}
```

### M5: Insecure Communication

- Keep ATS enabled; document any exceptions in Info.plist
- Implement certificate pinning for sensitive endpoints:

```swift
class PinningDelegate: NSObject, URLSessionDelegate {
    let pinnedCertificates: Set<Data>

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverCertData = SecCertificateCopyData(certificate) as Data
        if pinnedCertificates.contains(serverCertData) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

### M6: Inadequate Privacy Controls

- Declare all data collection in Privacy Manifest (PrivacyInfo.xcprivacy)
- Request minimum necessary permissions
- Use appropriate OSLog privacy levels:

```swift
import OSLog

let logger = Logger(subsystem: "com.app.example", category: "auth")

// Good: masks sensitive data
logger.info("User logged in: \(userId, privacy: .private)")

// Bad: exposes sensitive data
logger.info("User token: \(token)") // Never do this
```

### M7: Insufficient Binary Protections

- Enable all hardening flags in Xcode (PIE, ARC, stack canaries)
- Use `@inline(never)` for security-critical functions if needed
- Consider jailbreak detection for high-security apps:

```swift
func isDeviceCompromised() -> Bool {
    // Check for common jailbreak indicators
    let suspiciousPaths = [
        "/Applications/Cydia.app",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/"
    ]

    for path in suspiciousPaths {
        if FileManager.default.fileExists(atPath: path) {
            return true
        }
    }

    // Check if app can write outside sandbox
    let testPath = "/private/test_jb_\(UUID().uuidString)"
    do {
        try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(atPath: testPath)
        return true
    } catch {
        return false
    }
}
```

### M8: Security Misconfiguration

- Disable debug logging in release builds
- Remove test credentials and endpoints
- Configure proper backup exclusion:

```swift
var url = getDocumentsDirectory().appendingPathComponent("sensitive.db")
var resourceValues = URLResourceValues()
resourceValues.isExcludedFromBackup = true
try url.setResourceValues(resourceValues)
```

### M9: Insecure Data Storage

- Keychain for credentials (see M1)
- Encrypted Core Data for sensitive local data:

```swift
let container = NSPersistentContainer(name: "Model")
let storeDescription = container.persistentStoreDescriptions.first
storeDescription?.setOption(
    FileProtectionType.complete as NSObject,
    forKey: NSPersistentStoreFileProtectionKey
)
```

- Clear sensitive data from memory when done:

```swift
func clearSensitiveData(_ data: inout Data) {
    data.resetBytes(in: 0..<data.count)
}
```

### M10: Insufficient Cryptography

- Use Apple's CryptoKit for modern cryptography:

```swift
import CryptoKit

// Symmetric encryption
func encrypt(data: Data, key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.seal(data, using: key)
    return sealedBox.combined!
}

func decrypt(data: Data, key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.SealedBox(combined: data)
    return try AES.GCM.open(sealedBox, using: key)
}

// Key derivation
func deriveKey(from password: String, salt: Data) -> SymmetricKey {
    let passwordData = Data(password.utf8)
    let derivedKey = HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: passwordData),
        salt: salt,
        outputByteCount: 32
    )
    return derivedKey
}
```

---

## CWE mitigations — iOS patterns

### CWE-20: Input Validation

```swift
struct DeepLinkValidator {
    static let allowedSchemes = ["myapp", "https"]
    static let allowedHosts = ["app.example.com"]

    static func validate(_ url: URL) -> Bool {
        guard let scheme = url.scheme, allowedSchemes.contains(scheme),
              let host = url.host, allowedHosts.contains(host) else {
            return false
        }
        return true
    }
}
```

### CWE-79: Injection (WebView)

```swift
// Bad: loads arbitrary content
webView.loadHTMLString(userContent, baseURL: nil)

// Good: sanitize or avoid user HTML entirely
let sanitized = userContent
    .replacingOccurrences(of: "<script>", with: "", options: .caseInsensitive)
    .replacingOccurrences(of: "</script>", with: "", options: .caseInsensitive)
// Better: use native UI instead of WebView for user content
```

### CWE-200: Information Exposure

```swift
// Safe error handling
enum AppError: LocalizedError {
    case networkFailure
    case unauthorized
    case serverError

    var errorDescription: String? {
        switch self {
        case .networkFailure: return "Unable to connect. Please try again."
        case .unauthorized: return "Please sign in to continue."
        case .serverError: return "Something went wrong. Please try again."
        }
    }
}

// Never expose internal details
catch {
    logger.error("Internal error: \(error, privacy: .private)")
    throw AppError.serverError // User sees generic message
}
```

### CWE-295: Certificate Validation

```swift
// Never do this
let session = URLSession(configuration: .default, delegate: TrustAllDelegate(), delegateQueue: nil)

// Always validate certificates properly (see M5 pinning example above)
```

### CWE-312: Cleartext Storage

```swift
// Bad
UserDefaults.standard.set(apiToken, forKey: "token")

// Good
try KeychainManager.save(key: "token", data: apiToken.data(using: .utf8)!)
```

### CWE-319: Cleartext Transmission

- ATS prevents this by default; never add exceptions without justification
- If exception required, document in security review and add compensating controls

---

## Biometric Authentication

```swift
import LocalAuthentication

func authenticateWithBiometrics() async throws -> Bool {
    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        throw AuthError.biometricsUnavailable
    }

    return try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: "Authenticate to access your account"
    )
}
```

---

## Quick checklist

| Concern         | Check                                            |
| --------------- | ------------------------------------------------ |
| Secrets storage | Keychain, not UserDefaults                       |
| Network         | ATS enabled, no exceptions without justification |
| Deep links      | Scheme, host, and params validated               |
| Notifications   | Payload treated as untrusted                     |
| Logging         | OSLog with privacy levels; no PII                |
| Errors          | Generic user messages; details logged privately  |
| Biometrics      | LAContext with proper policy                     |
| Crypto          | CryptoKit, not custom implementations            |
| Backups         | Sensitive files excluded                         |
| Privacy         | Manifest accurate and complete                   |
