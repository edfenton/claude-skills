# iOS Coding Standards Reference

Detailed patterns and examples. Load when implementing specific features.

---

## Project Structure Example

```
MyApp/
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   └── HomeRow.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── SettingsViewModel.swift
│   └── Onboarding/
│       ├── OnboardingView.swift
│       ├── OnboardingViewModel.swift
│       └── OnboardingPage.swift
├── UIComponents/
│   ├── PrimaryButton.swift
│   ├── LoadingOverlay.swift
│   └── ErrorBanner.swift
├── Services/
│   ├── Persistence/
│   │   ├── PersistenceStore.swift
│   │   └── SwiftDataStore.swift
│   ├── Notifications/
│   │   ├── NotificationService.swift
│   │   └── NotificationRouter.swift
│   ├── Logging/
│   │   └── AppLogger.swift
│   └── Config/
│       └── Environment.swift
├── Infrastructure/
│   ├── Router.swift
│   ├── CompositionRoot.swift
│   └── AppDelegate.swift
└── Models/
    └── (SwiftData models)
```

---

## ViewModel Template

```swift
import Foundation
import os

@MainActor
final class FeatureViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: AppError?

    // MARK: - Dependencies

    private let persistenceStore: PersistenceStore
    private let logger: Logger

    // MARK: - Init

    init(persistenceStore: PersistenceStore, logger: Logger = AppLogger.features) {
        self.persistenceStore = persistenceStore
        self.logger = logger
    }

    // MARK: - Intents

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            items = try await persistenceStore.fetchItems()
            logger.info("Loaded \(self.items.count) items")
        } catch is CancellationError {
            logger.debug("Load cancelled")
        } catch {
            logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
            self.error = .loadFailed
        }

        isLoading = false
    }

    func didTapSave(_ item: Item) async {
        do {
            try await persistenceStore.save(item)
            logger.info("Item saved")
        } catch {
            logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
            self.error = .saveFailed
        }
    }

    func didTapDelete(_ item: Item) async {
        do {
            try await persistenceStore.delete(item)
            items.removeAll { $0.id == item.id }
            logger.info("Item deleted")
        } catch {
            logger.error("Delete failed: \(error.localizedDescription, privacy: .public)")
            self.error = .deleteFailed
        }
    }

    func dismissError() {
        error = nil
    }
}
```

---

## SwiftUI View Template

```swift
import SwiftUI

struct FeatureView: View {
    @StateObject private var viewModel: FeatureViewModel

    init(persistenceStore: PersistenceStore) {
        _viewModel = StateObject(wrappedValue: FeatureViewModel(persistenceStore: persistenceStore))
    }

    var body: some View {
        content
            .task { await viewModel.load() }
            .alert(item: $viewModel.error) { error in
                Alert(
                    title: Text("Error"),
                    message: Text(error.userMessage),
                    dismissButton: .default(Text("OK")) {
                        viewModel.dismissError()
                    }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
        } else if viewModel.items.isEmpty {
            emptyState
        } else {
            itemList
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Items",
            systemImage: "tray",
            description: Text("Add your first item to get started.")
        )
    }

    private var itemList: some View {
        List(viewModel.items) { item in
            ItemRow(item: item)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.didTapDelete(item) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }
}
```

---

## Persistence Boundary

### Protocol

```swift
import Foundation

protocol PersistenceStore: Sendable {
    func fetchItems() async throws -> [Item]
    func save(_ item: Item) async throws
    func delete(_ item: Item) async throws
    func deleteAll() async throws
}
```

### SwiftData Implementation

```swift
import Foundation
import SwiftData

actor SwiftDataStore: PersistenceStore {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    func fetchItems() async throws -> [Item] {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<ItemModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    @MainActor
    func save(_ item: Item) async throws {
        let context = modelContainer.mainContext
        let model = ItemModel(from: item)
        context.insert(model)
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
    func deleteAll() async throws {
        let context = modelContainer.mainContext
        try context.delete(model: ItemModel.self)
        try context.save()
    }
}
```

### In-Memory Test Double

```swift
actor InMemoryPersistenceStore: PersistenceStore {
    private var items: [Item] = []

    func fetchItems() async throws -> [Item] {
        items
    }

    func save(_ item: Item) async throws {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func delete(_ item: Item) async throws {
        items.removeAll { $0.id == item.id }
    }

    func deleteAll() async throws {
        items.removeAll()
    }

    // Test helpers
    func seed(_ items: [Item]) {
        self.items = items
    }
}
```

---

## Notification Service

```swift
import Foundation
@preconcurrency import UserNotifications
import os

@MainActor
final class NotificationService: NSObject, ObservableObject {

    @Published private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined

    private let logger = AppLogger.notifications

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
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

    @MainActor
    func updatePermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    // MARK: - Token Registration

    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        logger.info("Device token registered")
        // Send to server...
    }

    func didFailToRegisterForRemoteNotifications(error: Error) {
        logger.error("Token registration failed: \(error.localizedDescription, privacy: .public)")
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

        // Validate payload before routing
        guard let payload = NotificationPayload(userInfo: userInfo) else {
            logger.warning("Invalid notification payload")
            return
        }

        logger.info("Notification opened: \(payload.type.rawValue, privacy: .public)")
        await NotificationRouter.shared.route(payload)
    }
}
```

### Notification Payload Validation

```swift
struct NotificationPayload {
    enum PayloadType: String {
        case newMessage
        case reminder
        case update
    }

    let type: PayloadType
    let targetId: String?

    init?(userInfo: [AnyHashable: Any]) {
        // Treat all values as untrusted
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
}
```

---

## Error Handling

```swift
enum AppError: LocalizedError, Identifiable {
    case loadFailed
    case saveFailed
    case deleteFailed
    case networkUnavailable
    case unauthorized

    var id: String { localizedDescription }

    var userMessage: String {
        switch self {
        case .loadFailed:
            return "Unable to load data. Please try again."
        case .saveFailed:
            return "Unable to save. Please try again."
        case .deleteFailed:
            return "Unable to delete. Please try again."
        case .networkUnavailable:
            return "No internet connection. Please check your network."
        case .unauthorized:
            return "Please sign in to continue."
        }
    }

    var errorDescription: String? { userMessage }
}
```

---

## Logging Setup

```swift
import os

enum AppLogger {
    static let features = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "features")
    static let persistence = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "persistence")
    static let notifications = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "notifications")
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
}

// Usage
logger.debug("Debug info")                                    // Development only
logger.info("User action completed")                          // Normal events
logger.warning("Unexpected state: \(state, privacy: .public)")// Recoverable issues
logger.error("Operation failed: \(error, privacy: .private)") // Errors (mask details)
```

---

## Testing Patterns

### ViewModel Unit Test

```swift
import Testing
@testable import MyApp

@MainActor
struct FeatureViewModelTests {

    private let sut: FeatureViewModel
    private let mockStore: InMemoryPersistenceStore

    init() {
        mockStore = InMemoryPersistenceStore()
        sut = FeatureViewModel(persistenceStore: mockStore)
    }

    @Test func load_setsItemsFromStore() async {
        // Given
        let items = [Item(id: "1", name: "Test")]
        await mockStore.seed(items)

        // When
        await sut.load()

        // Then
        #expect(sut.items == items)
        #expect(!sut.isLoading)
        #expect(sut.error == nil)
    }

    @Test func load_setsLoadingState() async {
        // Given
        #expect(!sut.isLoading)

        // When
        let loadTask = Task { await sut.load() }

        // Then (during load)
        try? await Task.sleep(nanoseconds: 10_000_000) // Small delay
        // Note: Better to use async expectations in real tests

        await loadTask.value
        #expect(!sut.isLoading)
    }

    @Test func didTapDelete_removesItem() async {
        // Given
        let item = Item(id: "1", name: "Test")
        await mockStore.seed([item])
        await sut.load()
        #expect(sut.items.count == 1)

        // When
        await sut.didTapDelete(item)

        // Then
        #expect(sut.items.isEmpty)
    }
}
```

### Persistence Store Test

```swift
import Foundation
import SwiftData
import Testing
@testable import MyApp

@MainActor
struct SwiftDataStoreTests {

    private let sut: SwiftDataStore
    private let container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: ItemModel.self, configurations: config)
        sut = SwiftDataStore(modelContainer: container)
    }

    @Test func save_persistsItem() async throws {
        // Given
        let item = Item(id: "1", name: "Test")

        // When
        try await sut.save(item)

        // Then
        let fetched = try await sut.fetchItems()
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test")
    }

    @Test func delete_removesItem() async throws {
        // Given
        let item = Item(id: "1", name: "Test")
        try await sut.save(item)

        // When
        try await sut.delete(item)

        // Then
        let fetched = try await sut.fetchItems()
        #expect(fetched.isEmpty)
    }
}
```

---

## Quick Reference

| Item          | Location                               |
| ------------- | -------------------------------------- |
| Feature code  | `Features/<FeatureName>/`              |
| Shared UI     | `UIComponents/`                        |
| Persistence   | `Services/Persistence/`                |
| Notifications | `Services/Notifications/`              |
| Logging       | `Services/Logging/`                    |
| Config/env    | `Services/Config/`                     |
| Routing       | `Infrastructure/Router.swift`          |
| Composition   | `Infrastructure/CompositionRoot.swift` |
