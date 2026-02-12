import Foundation
import SwiftData

actor SwiftDataStore: PersistenceStore {
  private let modelContainer: ModelContainer

  init(modelContainer: ModelContainer) {
    self.modelContainer = modelContainer
  }

  @MainActor
  func fetchItems() async throws -> [ExampleItem] {
    let context = modelContainer.mainContext
    let descriptor = FetchDescriptor<ExampleItemModel>(
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    let models = try context.fetch(descriptor)
    return models.map { $0.toDomain() }
  }

  @MainActor
  func save(_ item: ExampleItem) async throws {
    let context = modelContainer.mainContext
    let id = item.id

    let descriptor = FetchDescriptor<ExampleItemModel>(
      predicate: #Predicate { $0.id == id }
    )

    if let existing = try context.fetch(descriptor).first {
      existing.update(from: item)
    } else {
      let model = ExampleItemModel(from: item)
      context.insert(model)
    }

    try context.save()
  }

  @MainActor
  func delete(_ item: ExampleItem) async throws {
    let context = modelContainer.mainContext
    let id = item.id

    let descriptor = FetchDescriptor<ExampleItemModel>(
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
    try context.delete(model: ExampleItemModel.self)
    try context.save()
  }
}
