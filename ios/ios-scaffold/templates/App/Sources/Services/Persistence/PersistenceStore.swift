import Foundation

protocol PersistenceStore: Sendable {
  func fetchItems() async throws -> [ExampleItem]
  func save(_ item: ExampleItem) async throws
  func delete(_ item: ExampleItem) async throws
  func deleteAll() async throws
}

// MARK: - In-Memory Test Double

actor InMemoryPersistenceStore: PersistenceStore {
  private var items: [ExampleItem] = []

  func fetchItems() async throws -> [ExampleItem] {
    items.sorted { $0.createdAt > $1.createdAt }
  }

  func save(_ item: ExampleItem) async throws {
    if let index = items.firstIndex(where: { $0.id == item.id }) {
      items[index] = item
    } else {
      items.append(item)
    }
  }

  func delete(_ item: ExampleItem) async throws {
    items.removeAll { $0.id == item.id }
  }

  func deleteAll() async throws {
    items.removeAll()
  }

  // Test helpers
  func seed(_ items: [ExampleItem]) {
    self.items = items
  }

  var count: Int {
    items.count
  }
}
