import Foundation
import SwiftData

@MainActor
final class DependencyContainer: ObservableObject {
  let modelContainer: ModelContainer
  let persistenceStore: PersistenceStore
  let notificationService: NotificationService

  init() {
    // SwiftData
    do {
      let config = ModelConfiguration(isStoredInMemoryOnly: false)
      self.modelContainer = try ModelContainer(
        for: ExampleItemModel.self,
        configurations: config
      )
      self.persistenceStore = SwiftDataStore(modelContainer: modelContainer)
    } catch {
      fatalError("Failed to initialize persistence: \(error)")
    }

    // Services
    self.notificationService = NotificationService()
  }

  // MARK: - Factory Methods

  func makeHomeViewModel() -> HomeViewModel {
    HomeViewModel(persistenceStore: persistenceStore)
  }
}
