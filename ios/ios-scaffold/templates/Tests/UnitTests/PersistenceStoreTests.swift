import Foundation
@testable import AppName
import SwiftData
import Testing

@MainActor
struct SwiftDataStoreTests {
  private let sut: SwiftDataStore
  private let container: ModelContainer

  init() throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    self.container = try ModelContainer(for: ExampleItemModel.self, configurations: config)
    self.sut = SwiftDataStore(modelContainer: self.container)
  }

  @Test func save_persistsItem() async throws {
    // Given
    let item = ExampleItem(title: "Test Item")

    // When
    try await sut.save(item)

    // Then
    let fetched = try await sut.fetchItems()
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "Test Item")
  }

  @Test func save_existingItem_updates() async throws {
    // Given
    var item = ExampleItem(title: "Original")
    try await sut.save(item)

    // When
    item.title = "Updated"
    try await self.sut.save(item)

    // Then
    let fetched = try await sut.fetchItems()
    #expect(fetched.count == 1)
    #expect(fetched.first?.title == "Updated")
  }

  @Test func delete_removesItem() async throws {
    // Given
    let item = ExampleItem(title: "To Delete")
    try await sut.save(item)

    // When
    try await self.sut.delete(item)

    // Then
    let fetched = try await sut.fetchItems()
    #expect(fetched.isEmpty)
  }

  @Test func deleteAll_removesAllItems() async throws {
    // Given
    try await self.sut.save(ExampleItem(title: "One"))
    try await self.sut.save(ExampleItem(title: "Two"))
    try await self.sut.save(ExampleItem(title: "Three"))

    // When
    try await self.sut.deleteAll()

    // Then
    let fetched = try await sut.fetchItems()
    #expect(fetched.isEmpty)
  }

  @Test func fetchItems_returnsSortedByCreatedAt() async throws {
    // Given
    let first = ExampleItem(title: "First", createdAt: Date().addingTimeInterval(-100))
    let second = ExampleItem(title: "Second", createdAt: Date().addingTimeInterval(-50))
    let third = ExampleItem(title: "Third", createdAt: Date())

    try await sut.save(first)
    try await self.sut.save(second)
    try await self.sut.save(third)

    // When
    let fetched = try await sut.fetchItems()

    // Then (should be reverse chronological)
    #expect(fetched.map(\.title) == ["Third", "Second", "First"])
  }
}
