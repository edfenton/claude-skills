import Foundation
import os

@MainActor
final class HomeViewModel: ObservableObject {

  // MARK: - Published State

  @Published private(set) var items: [ExampleItem] = []
  @Published private(set) var isLoading = false
  @Published var error: AppError?

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

  func addItem(title: String) async {
    let trimmed = title.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    let item = ExampleItem(title: trimmed)

    do {
      try await persistenceStore.save(item)
      items.insert(item, at: 0)
      logger.info("Item added")
    } catch {
      logger.error("Add failed: \(error.localizedDescription, privacy: .public)")
      self.error = .saveFailed
    }
  }

  func deleteItem(_ item: ExampleItem) async {
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

// MARK: - App Errors

enum AppError: LocalizedError, Identifiable {
  case loadFailed
  case saveFailed
  case deleteFailed

  var id: String { localizedDescription }

  var userMessage: String {
    switch self {
    case .loadFailed:
      return "Unable to load items. Please try again."
    case .saveFailed:
      return "Unable to save. Please try again."
    case .deleteFailed:
      return "Unable to delete. Please try again."
    }
  }

  var errorDescription: String? { userMessage }
}
