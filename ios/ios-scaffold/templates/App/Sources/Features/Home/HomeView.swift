import SwiftUI

struct HomeView: View {
  @StateObject private var viewModel: HomeViewModel
  @EnvironmentObject private var notificationService: NotificationService
  @State private var showingAddSheet = false

  init(viewModel: HomeViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      content
        .navigationTitle("Home")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button("", systemImage: "plus") {
              showingAddSheet = true
            }
            .accessibilityLabel("Add item")
          }
        }
        .sheet(isPresented: $showingAddSheet) {
          AddItemSheet(onSave: { title in
            Task { await viewModel.addItem(title: title) }
          })
        }
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
    .overlay(alignment: .bottom) {
      if AppEnvironment.current.isDebug {
        EnvironmentBadge()
      }
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
      description: Text("Tap + to add your first item.")
    )
  }

  private var itemList: some View {
    List {
      ForEach(viewModel.items) { item in
        ItemRow(item: item)
      }
      .onDelete { indexSet in
        Task {
          for index in indexSet {
            await viewModel.deleteItem(viewModel.items[index])
          }
        }
      }
    }
  }
}

// MARK: - Supporting Views

private struct ItemRow: View {
  let item: ExampleItem

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(item.title)
        .font(.headline)
      Text(item.createdAt, style: .relative)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct AddItemSheet: View {
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  let onSave: (String) -> Void

  var body: some View {
    NavigationStack {
      Form {
        TextField("Title", text: $title)
      }
      .navigationTitle("New Item")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            onSave(title)
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .presentationDetents([.medium])
  }
}

private struct EnvironmentBadge: View {
  var body: some View {
    Text(AppEnvironment.current.rawValue.uppercased())
      .font(.caption2)
      .fontWeight(.bold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.orange.opacity(0.8))
      .foregroundStyle(.white)
      .clipShape(Capsule())
      .padding(.bottom, 8)
  }
}

#Preview {
  HomeView(viewModel: HomeViewModel(persistenceStore: InMemoryPersistenceStore()))
}
