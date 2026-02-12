import SwiftUI
import SwiftData

@main
struct AppNameApp: App {
  @StateObject private var dependencies = DependencyContainer()

  var body: some Scene {
    WindowGroup {
      HomeView(viewModel: dependencies.makeHomeViewModel())
        .environmentObject(dependencies.notificationService)
    }
    .modelContainer(dependencies.modelContainer)
  }
}
