import Foundation
import SwiftData

@Model
final class ExampleItemModel {
  @Attribute(.unique) var id: String
  var title: String
  var createdAt: Date
  var updatedAt: Date

  init(id: String = UUID().uuidString, title: String) {
    self.id = id
    self.title = title
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  convenience init(from domain: ExampleItem) {
    self.init(id: domain.id, title: domain.title)
    self.createdAt = domain.createdAt
  }

  func toDomain() -> ExampleItem {
    ExampleItem(id: id, title: title, createdAt: createdAt)
  }

  func update(from domain: ExampleItem) {
    self.title = domain.title
    self.updatedAt = Date()
  }
}

// MARK: - Domain Model

struct ExampleItem: Identifiable, Equatable, Sendable {
  let id: String
  var title: String
  let createdAt: Date

  init(id: String = UUID().uuidString, title: String, createdAt: Date = Date()) {
    self.id = id
    self.title = title
    self.createdAt = createdAt
  }
}
