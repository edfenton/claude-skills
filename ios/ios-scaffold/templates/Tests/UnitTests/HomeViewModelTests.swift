@testable import AppName
import Testing

@MainActor
struct HomeViewModelTests {
  private let sut: HomeViewModel
  private let mockStore: InMemoryPersistenceStore

  init() {
    self.mockStore = InMemoryPersistenceStore()
    self.sut = HomeViewModel(persistenceStore: self.mockStore)
  }

  // MARK: - Load

  @Test func load_whenStoreEmpty_setsEmptyItems() async {
    // When
    await self.sut.load()

    // Then
    #expect(self.sut.items.isEmpty)
    #expect(!self.sut.isLoading)
    #expect(self.sut.error == nil)
  }

  @Test func load_whenStoreHasItems_setsItems() async {
    // Given
    let items = [
      ExampleItem(title: "First"),
      ExampleItem(title: "Second")
    ]
    await mockStore.seed(items)

    // When
    await self.sut.load()

    // Then
    #expect(self.sut.items.count == 2)
    #expect(!self.sut.isLoading)
  }

  // MARK: - Add

  @Test func addItem_withValidTitle_addsToItems() async {
    // When
    await self.sut.addItem(title: "New Item")

    // Then
    #expect(self.sut.items.count == 1)
    #expect(self.sut.items.first?.title == "New Item")
    let storeCount = await mockStore.count
    #expect(storeCount == 1)
  }

  @Test func addItem_withEmptyTitle_doesNotAdd() async {
    // When
    await self.sut.addItem(title: "")
    await self.sut.addItem(title: "   ")

    // Then
    #expect(self.sut.items.isEmpty)
    let storeCount = await mockStore.count
    #expect(storeCount == 0)
  }

  @Test func addItem_trimsWhitespace() async {
    // When
    await self.sut.addItem(title: "  Trimmed  ")

    // Then
    #expect(self.sut.items.first?.title == "Trimmed")
  }

  // MARK: - Delete

  @Test func deleteItem_removesFromItems() async {
    // Given
    let item = ExampleItem(title: "To Delete")
    await mockStore.seed([item])
    await self.sut.load()
    #expect(self.sut.items.count == 1)

    // When
    await self.sut.deleteItem(item)

    // Then
    #expect(self.sut.items.isEmpty)
    let storeCount = await mockStore.count
    #expect(storeCount == 0)
  }

  // MARK: - Error Handling

  @Test func dismissError_clearsError() {
    // Given
    self.sut.error = .loadFailed

    // When
    self.sut.dismissError()

    // Then
    #expect(self.sut.error == nil)
  }
}
