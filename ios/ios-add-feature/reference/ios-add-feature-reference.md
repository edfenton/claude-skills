# iOS Add Feature Reference

Templates and patterns for scaffolding features.

---

## ViewModel Template

```swift
// Features/Settings/SettingsViewModel.swift
import Foundation
import os

@MainActor
final class SettingsViewModel: ObservableObject {

  // MARK: - Published State

  @Published private(set) var items: [SettingsItem] = []
  @Published private(set) var isLoading = false
  @Published var error: SettingsError?

  // MARK: - Dependencies

  private let persistenceStore: PersistenceStore
  private let logger = AppLogger.features

  // MARK: - Init

  init(persistenceStore: PersistenceStore) {
    self.persistenceStore = persistenceStore
  }

  // MARK: - Intents

  func load() async {
    guard !isLoading else { return }

    isLoading = true
    error = nil

    do {
      items = try await persistenceStore.fetchSettings()
      logger.info("Loaded \(self.items.count) settings")
    } catch is CancellationError {
      logger.debug("Load cancelled")
    } catch {
      logger.error("Load failed: \(error.localizedDescription, privacy: .public)")
      self.error = .loadFailed
    }

    isLoading = false
  }

  func updateSetting(_ item: SettingsItem, value: Any) async {
    do {
      try await persistenceStore.updateSetting(item.id, value: value)
      await load() // Refresh
      logger.info("Setting updated: \(item.id, privacy: .public)")
    } catch {
      logger.error("Update failed: \(error.localizedDescription, privacy: .public)")
      self.error = .updateFailed
    }
  }

  func dismissError() {
    error = nil
  }
}

// MARK: - Errors

enum SettingsError: LocalizedError, Identifiable {
  case loadFailed
  case updateFailed

  var id: String { localizedDescription }

  var userMessage: String {
    switch self {
    case .loadFailed:
      return "Unable to load settings. Please try again."
    case .updateFailed:
      return "Unable to save. Please try again."
    }
  }

  var errorDescription: String? { userMessage }
}
```

---

## View Template

```swift
// Features/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
  @StateObject private var viewModel: SettingsViewModel

  init(viewModel: SettingsViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Settings")
    }
    .task {
      await viewModel.load()
    }
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
      ContentUnavailableView(
        "No Settings",
        systemImage: "gear",
        description: Text("Settings will appear here.")
      )
    } else {
      settingsList
    }
  }

  private var settingsList: some View {
    List {
      ForEach(viewModel.items) { item in
        SettingsRow(item: item) { newValue in
          Task {
            await viewModel.updateSetting(item, value: newValue)
          }
        }
      }
    }
  }
}

#Preview {
  SettingsView(viewModel: SettingsViewModel(persistenceStore: InMemoryPersistenceStore()))
}
```

---

## Row Template

```swift
// Features/Settings/SettingsRow.swift
import SwiftUI

struct SettingsRow: View {
  let item: SettingsItem
  let onChange: (Any) -> Void

  var body: some View {
    switch item.type {
    case .toggle:
      Toggle(item.title, isOn: Binding(
        get: { item.value as? Bool ?? false },
        set: { onChange($0) }
      ))
      .accessibilityLabel(item.title)

    case .text:
      HStack {
        Text(item.title)
        Spacer()
        Text(item.value as? String ?? "")
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)

    case .navigation:
      NavigationLink(item.title) {
        // Detail view
      }
    }
  }
}
```

---

## Detail View Template

```swift
// Features/Settings/SettingsDetailView.swift
import SwiftUI

struct SettingsDetailView: View {
  @StateObject private var viewModel: SettingsDetailViewModel
  @Environment(\.dismiss) private var dismiss

  init(viewModel: SettingsDetailViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    Form {
      Section {
        // Detail content
      }
    }
    .navigationTitle(viewModel.item.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          Task {
            await viewModel.save()
            dismiss()
          }
        }
        .disabled(!viewModel.hasChanges)
      }
    }
    .task {
      await viewModel.load()
    }
  }
}
```

---

## Form View Template

```swift
// Features/Profile/ProfileFormView.swift
import SwiftUI

struct ProfileFormView: View {
  @StateObject private var viewModel: ProfileFormViewModel
  @Environment(\.dismiss) private var dismiss

  init(viewModel: ProfileFormViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Personal Information") {
          TextField("Name", text: $viewModel.name)
            .textContentType(.name)

          TextField("Email", text: $viewModel.email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
        }

        Section("Preferences") {
          Toggle("Notifications", isOn: $viewModel.notificationsEnabled)
        }
      }
      .navigationTitle(viewModel.isEditing ? "Edit Profile" : "New Profile")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              await viewModel.save()
              dismiss()
            }
          }
          .disabled(!viewModel.isValid || viewModel.isSaving)
        }
      }
    }
  }
}

// MARK: - ViewModel

@MainActor
final class ProfileFormViewModel: ObservableObject {
  @Published var name = ""
  @Published var email = ""
  @Published var notificationsEnabled = true
  @Published private(set) var isSaving = false

  let isEditing: Bool
  private let existingProfile: Profile?
  private let persistenceStore: PersistenceStore

  var isValid: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty &&
    email.contains("@")
  }

  init(profile: Profile? = nil, persistenceStore: PersistenceStore) {
    self.existingProfile = profile
    self.isEditing = profile != nil
    self.persistenceStore = persistenceStore

    if let profile {
      self.name = profile.name
      self.email = profile.email
      self.notificationsEnabled = profile.notificationsEnabled
    }
  }

  func save() async {
    isSaving = true
    defer { isSaving = false }

    let profile = Profile(
      id: existingProfile?.id ?? UUID().uuidString,
      name: name.trimmingCharacters(in: .whitespaces),
      email: email.lowercased(),
      notificationsEnabled: notificationsEnabled
    )

    do {
      try await persistenceStore.saveProfile(profile)
    } catch {
      // Handle error
    }
  }
}
```

---

## Test Template

```swift
// Tests/UnitTests/SettingsViewModelTests.swift
import Testing
@testable import AppName

@MainActor
struct SettingsViewModelTests {

  private let sut: SettingsViewModel
  private let mockStore: MockPersistenceStore

  init() {
    mockStore = MockPersistenceStore()
    sut = SettingsViewModel(persistenceStore: mockStore)
  }

  // MARK: - Load

  @Test func load_whenStoreEmpty_setsEmptyItems() async {
    // Given
    mockStore.settingsToReturn = []

    // When
    await sut.load()

    // Then
    #expect(sut.items.isEmpty)
    #expect(!sut.isLoading)
    #expect(sut.error == nil)
  }

  @Test func load_whenStoreHasItems_setsItems() async {
    // Given
    mockStore.settingsToReturn = [
      SettingsItem(id: "1", title: "Notifications", type: .toggle, value: true),
      SettingsItem(id: "2", title: "Theme", type: .text, value: "Dark"),
    ]

    // When
    await sut.load()

    // Then
    #expect(sut.items.count == 2)
    #expect(!sut.isLoading)
  }

  @Test func load_whenStoreFails_setsError() async {
    // Given
    mockStore.shouldFail = true

    // When
    await sut.load()

    // Then
    #expect(sut.error == .loadFailed)
  }

  // MARK: - Update

  @Test func updateSetting_callsStore() async {
    // Given
    let item = SettingsItem(id: "1", title: "Test", type: .toggle, value: false)
    mockStore.settingsToReturn = [item]
    await sut.load()

    // When
    await sut.updateSetting(item, value: true)

    // Then
    #expect(mockStore.lastUpdatedId == "1")
    #expect(mockStore.lastUpdatedValue as? Bool == true)
  }

  // MARK: - Error

  @Test func dismissError_clearsError() async {
    // Given
    mockStore.shouldFail = true
    await sut.load()
    #expect(sut.error != nil)

    // When
    sut.dismissError()

    // Then
    #expect(sut.error == nil)
  }
}

// MARK: - Mock

final class MockPersistenceStore: PersistenceStore {
  var settingsToReturn: [SettingsItem] = []
  var shouldFail = false
  var lastUpdatedId: String?
  var lastUpdatedValue: Any?

  func fetchSettings() async throws -> [SettingsItem] {
    if shouldFail { throw NSError(domain: "test", code: 1) }
    return settingsToReturn
  }

  func updateSetting(_ id: String, value: Any) async throws {
    if shouldFail { throw NSError(domain: "test", code: 1) }
    lastUpdatedId = id
    lastUpdatedValue = value
  }

  // Other protocol requirements...
}
```

---

## DependencyContainer Integration

```swift
// Infrastructure/DependencyContainer.swift - add factory method

extension DependencyContainer {
  func makeSettingsViewModel() -> SettingsViewModel {
    SettingsViewModel(persistenceStore: persistenceStore)
  }

  func makeSettingsDetailViewModel(item: SettingsItem) -> SettingsDetailViewModel {
    SettingsDetailViewModel(item: item, persistenceStore: persistenceStore)
  }
}
```

---

## Navigation Integration

```swift
// Add to your navigation/router

enum Route: Hashable {
  case settings
  case settingsDetail(SettingsItem)
  // ...
}

// In your root view or navigation handler
.navigationDestination(for: Route.self) { route in
  switch route {
  case .settings:
    SettingsView(viewModel: dependencies.makeSettingsViewModel())
  case .settingsDetail(let item):
    SettingsDetailView(viewModel: dependencies.makeSettingsDetailViewModel(item: item))
  }
}
```

---

## Quick Reference

| Component | Location | Naming |
|-----------|----------|--------|
| View | `Features/<Feature>/<Feature>View.swift` | `<Feature>View` |
| ViewModel | `Features/<Feature>/<Feature>ViewModel.swift` | `<Feature>ViewModel` |
| Row | `Features/<Feature>/<Feature>Row.swift` | `<Feature>Row` |
| Tests | `Tests/UnitTests/<Feature>ViewModelTests.swift` | `<Feature>ViewModelTests` |
| Factory | `DependencyContainer.swift` | `make<Feature>ViewModel()` |
