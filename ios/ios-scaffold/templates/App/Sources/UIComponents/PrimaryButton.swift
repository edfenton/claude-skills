import SwiftUI

struct PrimaryButton: View {
  let title: String
  let action: () -> Void
  var isLoading: Bool = false
  var isDisabled: Bool = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isLoading {
          ProgressView()
            .progressViewStyle(.circular)
            .tint(.white)
        }
        Text(title)
          .fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: 44)
      .background(isDisabled ? Color.gray : Color.accentColor)
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .disabled(isDisabled || isLoading)
    .accessibilityLabel(title)
    .accessibilityHint(isLoading ? "Loading" : "")
  }
}

#Preview {
  VStack(spacing: 16) {
    PrimaryButton(title: "Save", action: {})
    PrimaryButton(title: "Loading...", action: {}, isLoading: true)
    PrimaryButton(title: "Disabled", action: {}, isDisabled: true)
  }
  .padding()
}
