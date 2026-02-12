# iOS Stack Reference

Versions, project setup, and implementation patterns.

---

## Target versions

| Requirement           | Version            |
| --------------------- | ------------------ |
| iOS deployment target | 26.0               |
| Swift                 | 6.2                |
| Xcode                 | 26                 |
| SwiftData             | iOS 26.0 (included) |

Adjust deployment target based on user base requirements.

---

## Environment configuration

### Environment enum

```swift
// Services/Config/Environment.swift
import Foundation

enum Environment: String, CaseIterable {
    case local
    case nonProd
    case prod

    static var current: Environment {
        #if LOCAL
        return .local
        #elseif NONPROD
        return .nonProd
        #else
        return .prod
        #endif
    }

    var apiBaseURL: URL {
        switch self {
        case .local:
            return URL(string: "http://localhost:3000/api")!
        case .nonProd:
            return URL(string: "https://api.nonprod.example.com")!
        case .prod:
            return URL(string: "https://api.example.com")!
        }
    }

    var isDebug: Bool {
        self != .prod
    }

    var logLevel: LogLevel {
        switch self {
        case .local: return .debug
        case .nonProd: return .info
        case .prod: return .warning
        }
    }
}
```

### Build configuration setup

In Xcode project settings:

1. **Create configurations:**
   - Debug-Local
   - Debug-NonProd
   - Release-NonProd
   - Release-Prod

2. **Add Swift flags per configuration:**

```
   Debug-Local:     LOCAL DEBUG
   Debug-NonProd:   NONPROD DEBUG
   Release-NonProd: NONPROD
   Release-Prod:    (none)
```

3. **Create schemes:**
   - MyApp-Local (Debug-Local)
   - MyApp-NonProd (Debug-NonProd / Release-NonProd)
   - MyApp-Prod (Release-Prod)

---

## Persistence boundary

### Protocol

```swift
// Services/Persistence/PersistenceStore.swift
import Foundation

protocol PersistenceStore: Sendable {
    // Items
    func fetchItems() async throws -> [Item]
    func fetchItem(id: String) async throws -> Item?
    func save(_ item: Item) async throws
    func delete(_ item: Item) async throws

    // Bulk operations
    func deleteAllItems() async throws

    // Sync metadata (for future server sync)
    func lastSyncDate() async -> Date?
    func setLastSyncDate(_ date: Date) async
}
```

### SwiftData implementation

```swift
// Services/Persistence/SwiftDataStore.swift
import Foundation
import SwiftData

actor SwiftDataStore: PersistenceStore {
    private let modelContainer: ModelContainer

    init(inMemory: Bool = false) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.modelContainer = try ModelContainer(
            for: ItemModel.self,
            configurations: config
        )
    }

    @MainActor
    func fetchItems() async throws -> [Item] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<ItemModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    @MainActor
    func save(_ item: Item) async throws {
        let context = modelContainer.mainContext

        // Check for existing
        let id = item.id
        let descriptor = FetchDescriptor<ItemModel>(
            predicate: #Predicate { $0.id == id }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.update(from: item)
        } else {
            let model = ItemModel(from: item)
            context.insert(model)
        }

        try context.save()
    }

    @MainActor
    func delete(_ item: Item) async throws {
        let context = modelContainer.mainContext
        let id = item.id
        let descriptor = FetchDescriptor<ItemModel>(
            predicate: #Predicate { $0.id == id }
        )

        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }

    @MainActor
    func deleteAllItems() async throws {
        let context = modelContainer.mainContext
        try context.delete(model: ItemModel.self)
        try context.save()
    }

    // Sync metadata stored in UserDefaults (not sensitive)
    func lastSyncDate() async -> Date? {
        UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    func setLastSyncDate(_ date: Date) async {
        UserDefaults.standard.set(date, forKey: "lastSyncDate")
    }
}
```

### SwiftData model

```swift
// Models/ItemModel.swift
import Foundation
import SwiftData

@Model
final class ItemModel {
    @Attribute(.unique) var id: String
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, content: String) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    convenience init(from domain: Item) {
        self.init(id: domain.id, title: domain.title, content: domain.content)
    }

    func toDomain() -> Item {
        Item(id: id, title: title, content: content, createdAt: createdAt)
    }

    func update(from domain: Item) {
        self.title = domain.title
        self.content = domain.content
        self.updatedAt = Date()
    }
}
```

### Domain model

```swift
// Models/Item.swift
import Foundation

struct Item: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var content: String
    let createdAt: Date

    init(id: String = UUID().uuidString, title: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }
}
```

---

## Push notification stubbing

### Stubbed notification service

```swift
// Services/Notifications/NotificationService.swift
import Foundation
import UserNotifications
import os

final class NotificationService: NSObject, ObservableObject {

    @Published private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "notifications")
    private let environment = Environment.current

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        // In local/non-prod without signing, simulate success
        if environment.isDebug && !isSigningAvailable {
            logger.info("[STUB] Permission request simulated as granted")
            await MainActor.run { permissionStatus = .authorized }
            return true
        }

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await updatePermissionStatus()
            return granted
        } catch {
            logger.error("Permission request failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    func updatePermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    // MARK: - Token registration

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()

        Task { @MainActor in
            self.deviceToken = token
        }

        if environment.isDebug {
            logger.info("[STUB] Would send token to server: \(token.prefix(16))...")
            // TODO: Implement actual token registration when backend ready
        } else {
            // Real implementation
            Task {
                await registerTokenWithServer(token)
            }
        }
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        logger.error("Token registration failed: \(error.localizedDescription)")
    }

    // MARK: - Private

    private var isSigningAvailable: Bool {
        // Check if we have a valid provisioning profile
        // This will be false until developer program membership is active
        Bundle.main.object(forInfoDictionaryKey: "ProvisioningProfile") != nil
    }

    private func registerTokenWithServer(_ token: String) async {
        // Implement when backend ready
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        logger.info("Notification received: \(userInfo.keys)")

        // Route to appropriate screen
        // NotificationRouter.shared.route(userInfo)
    }
}
```

### Local notification testing

```swift
// For testing notification flows without push
extension NotificationService {

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

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                self.logger.error("Failed to schedule test notification: \(error.localizedDescription)")
            } else {
                self.logger.info("Test notification scheduled for \(delay)s")
            }
        }
    }
}
```

---

## Network client scaffold

```swift
// Services/Network/APIClient.swift
import Foundation
import os

actor APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")

    init(environment: Environment = .current) {
        self.baseURL = environment.apiBaseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Generic request

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try endpoint.urlRequest(baseURL: baseURL)

        logger.debug("Request: \(endpoint.method.rawValue) \(endpoint.path)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        logger.debug("Response: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decode error: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }
}

// MARK: - Endpoint

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]?
    let body: Encodable?

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
    }

    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        return request
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "Server error (\(code))"
        case .decodingError:
            return "Failed to process response"
        }
    }
}
```

---

## Composition root

```swift
// Infrastructure/CompositionRoot.swift
import SwiftUI
import SwiftData

@MainActor
final class AppDependencies: ObservableObject {
    let persistenceStore: PersistenceStore
    let notificationService: NotificationService
    let apiClient: APIClient
    let environment: Environment

    init() {
        self.environment = Environment.current

        // Persistence
        do {
            self.persistenceStore = try SwiftDataStore()
        } catch {
            fatalError("Failed to initialize persistence: \(error)")
        }

        // Notifications
        self.notificationService = NotificationService()

        // Network
        self.apiClient = APIClient(environment: environment)
    }

    // Factory methods for view models
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(persistenceStore: persistenceStore)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(notificationService: notificationService)
    }
}

// Usage in App
@main
struct MyApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencies)
        }
    }
}
```

---

## Quality gates

### SwiftLint configuration

```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace
  - todo

opt_in_rules:
  - empty_count
  - explicit_init
  - first_where
  - overridden_super_call
  - private_outlet
  - redundant_nil_coalescing
  - sorted_imports

line_length:
  warning: 120
  error: 150

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 500
  error: 800

function_body_length:
  warning: 50
  error: 100

excluded:
  - Pods
  - .build
```

### Test requirements

```swift
// Minimum test coverage expectations:
// - All ViewModel public methods
// - PersistenceStore operations
// - API response parsing
// - Notification routing logic

// Example test structure
import Testing

@MainActor
struct HomeViewModelTests {
    private let sut: HomeViewModel
    private let mockStore: InMemoryPersistenceStore

    init() {
        self.mockStore = InMemoryPersistenceStore()
        self.sut = HomeViewModel(persistenceStore: mockStore)
    }

    @Test func load_fetchesItemsFromStore() async {
        // Given
        await mockStore.seed([Item(title: "Test", content: "Content")])

        // When
        await sut.load()

        // Then
        #expect(sut.items.count == 1)
    }
}
```

---

## Quick reference

| Question           | Answer                                    |
| ------------------ | ----------------------------------------- |
| Deployment target  | iOS 26.0                                  |
| UI framework       | SwiftUI                                   |
| Persistence        | SwiftData via `PersistenceStore` protocol |
| Architecture       | MVVM + service layer                      |
| Concurrency        | async/await, `@MainActor` for UI          |
| Dependencies       | Minimal, SPM only                         |
| Push notifications | Stubbed until signing                     |
| Environments       | local / nonProd / prod via build config   |
| Quality            | SwiftLint + required tests                |
