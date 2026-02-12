# iOS Style Guide Reference

Detailed tokens, patterns, and implementation guidance. Load when building UI.

---

## Semantic Color Tokens (Swift)

### Color definitions

```swift
import SwiftUI

enum BrandColors {
    static let orange = Color(hex: 0xFF5E1A)

    enum Neutral {
        static let white = Color(hex: 0xFFFFFF)
        static let lightGray = Color(hex: 0xDAD9D9)
        static let darkGray = Color(hex: 0x282828)
        static let black = Color(hex: 0x000000)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
```

### Semantic tokens

```swift
enum SemanticColors {

    // MARK: - Light Mode

    enum Light {
        static let background = BrandColors.Neutral.white
        static let surface = BrandColors.Neutral.white
        static let surfaceElevated = BrandColors.Neutral.white
        static let textPrimary = BrandColors.Neutral.black
        static let textSecondary = BrandColors.Neutral.darkGray
        static let textMuted = BrandColors.Neutral.darkGray.opacity(0.6)
        static let border = BrandColors.Neutral.lightGray
        static let divider = BrandColors.Neutral.lightGray
        static let accent = BrandColors.orange
        static let onAccent = BrandColors.Neutral.black
    }

    // MARK: - Dark Mode

    enum Dark {
        static let background = BrandColors.Neutral.black
        static let surface = BrandColors.Neutral.darkGray
        static let surfaceElevated = BrandColors.Neutral.darkGray
        static let textPrimary = BrandColors.Neutral.white
        static let textSecondary = BrandColors.Neutral.lightGray
        static let textMuted = BrandColors.Neutral.lightGray.opacity(0.6)
        static let border = BrandColors.Neutral.darkGray
        static let divider = BrandColors.Neutral.darkGray
        static let accent = BrandColors.orange
        static let onAccent = BrandColors.Neutral.black
    }
}
```

### Environment-aware color

```swift
struct AppColors {
    @Environment(\.colorScheme) var colorScheme

    var background: Color {
        colorScheme == .dark ? SemanticColors.Dark.background : SemanticColors.Light.background
    }

    var surface: Color {
        colorScheme == .dark ? SemanticColors.Dark.surface : SemanticColors.Light.surface
    }

    var textPrimary: Color {
        colorScheme == .dark ? SemanticColors.Dark.textPrimary : SemanticColors.Light.textPrimary
    }

    var accent: Color {
        BrandColors.orange // Same in both modes
    }
}

// Usage in views
struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme

    private var colors: AppColors { AppColors() }

    var body: some View {
        Text("Hello")
            .foregroundStyle(colors.textPrimary)
            .background(colors.background)
    }
}
```

### Asset catalog approach (alternative)

```swift
// Define in Assets.xcassets with light/dark variants
extension Color {
    static let appBackground = Color("Background")
    static let appSurface = Color("Surface")
    static let appTextPrimary = Color("TextPrimary")
    static let appTextSecondary = Color("TextSecondary")
    static let appAccent = Color("Accent")
    static let appBorder = Color("Border")
}
```

---

## Typography

### System font usage

```swift
// Body and controls: San Francisco (system)
Text("Body text")
    .font(.body)

Text("Caption")
    .font(.caption)

// Headings: system with weight
Text("Heading")
    .font(.title)
    .fontWeight(.bold)

// Dynamic Type support (automatic with system fonts)
Text("Scales with user preference")
    .font(.body)
    .dynamicTypeSize(.large ... .accessibility3)
```

### Brand display font

```swift
// Custom font for display/hero text only
extension Font {
    static func brandDisplay(_ size: CGFloat) -> Font {
        .custom("YourBrandFont-Bold", size: size, relativeTo: .title)
    }

    static func brandHeadline(_ size: CGFloat) -> Font {
        .custom("YourBrandFont-Medium", size: size, relativeTo: .headline)
    }
}

// Usage
Text("Hero Title")
    .font(.brandDisplay(34))

Text("Section Heading")
    .font(.brandHeadline(20))
```

### Type scale

```swift
enum TypeScale {
    static let caption2: CGFloat = 11
    static let caption: CGFloat = 12
    static let footnote: CGFloat = 13
    static let subheadline: CGFloat = 15
    static let body: CGFloat = 17
    static let headline: CGFloat = 17  // semibold
    static let title3: CGFloat = 20
    static let title2: CGFloat = 22
    static let title: CGFloat = 28
    static let largeTitle: CGFloat = 34
}
```

---

## Liquid Glass Implementation

### Navigation bar with glass

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                content
            }
            .navigationTitle("Home")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
```

### Tab bar with glass

```swift
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .background(.ultraThinMaterial)
    }
}
```

### Sheet/modal with glass

```swift
struct DetailSheet: View {
    var body: some View {
        VStack {
            // Content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
```

### Hero card with glass overlay

```swift
struct HeroCard: View {
    let image: Image
    let title: String

    var body: some View {
        image
            .resizable()
            .aspectRatio(16/9, contentMode: .fill)
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

### Material types

```swift
// Available materials (lightest to most opaque)
.ultraThinMaterial    // Subtle, most transparent
.thinMaterial         // Light blur
.regularMaterial      // Standard (most common)
.thickMaterial        // More opaque
.ultraThickMaterial   // Least transparent

// Prefer .regularMaterial for most cases
// Use .ultraThinMaterial for overlays where content behind should be visible
// Use .thickMaterial when legibility is critical
```

### When NOT to use glass

```swift
// ❌ Bad: Glass on dense list
List(items) { item in
    ItemRow(item: item)
        .background(.regularMaterial) // Don't do this
}

// ✅ Good: Solid background for lists
List(items) { item in
    ItemRow(item: item)
}
.scrollContentBackground(.hidden)
.background(Color.appBackground)

// ❌ Bad: Glass behind text input
TextField("Enter text", text: $text)
    .background(.thinMaterial) // Don't do this

// ✅ Good: Solid surface for inputs
TextField("Enter text", text: $text)
    .textFieldStyle(.roundedBorder)
```

---

## Adaptive Layouts

### Size class detection

```swift
struct AdaptiveView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var body: some View {
        if horizontalSizeClass == .compact {
            // iPhone portrait, iPad split view (narrow)
            CompactLayout()
        } else {
            // iPad full screen, iPhone landscape (large)
            RegularLayout()
        }
    }
}
```

### ViewThatFits for adaptive content

```swift
struct AdaptiveStack<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits {
            HStack { content }
            VStack { content }
        }
    }
}
```

### iPad sidebar pattern

```swift
struct MainView: View {
    @State private var selectedItem: Item?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(items, selection: $selectedItem) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .navigationTitle("Items")
        } detail: {
            // Detail
            if let item = selectedItem {
                ItemDetailView(item: item)
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "sidebar.left"
                )
            }
        }
    }
}
```

### Responsive grid

```swift
struct ResponsiveGrid: View {
    @Environment(\.horizontalSizeClass) var sizeClass

    private var columns: [GridItem] {
        let count = sizeClass == .compact ? 2 : 4
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { item in
                ItemCard(item: item)
            }
        }
        .padding()
    }
}
```

---

## Motion and Animation

### Appropriate transitions

```swift
// State change with spring animation
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
    isExpanded.toggle()
}

// Navigation transitions (system handles appropriately)
NavigationLink(value: item) {
    ItemRow(item: item)
}

// Sheet presentation (system spring)
.sheet(isPresented: $showSheet) {
    DetailSheet()
}
```

### Respecting reduced motion

```swift
struct AnimatedView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isVisible = false

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : (reduceMotion ? 0 : 20))
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    isVisible = true
                }
            }
    }
}
```

### Standard timing

```swift
enum AnimationTiming {
    static let fast = Animation.easeOut(duration: 0.15)
    static let normal = Animation.easeOut(duration: 0.25)
    static let slow = Animation.easeOut(duration: 0.35)

    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let springBouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
}
```

---

## Spacing and Shape

### Spacing scale

```swift
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### Corner radius

```swift
enum CornerRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 24
    static let full: CGFloat = .infinity  // Capsule
}

// Usage
RoundedRectangle(cornerRadius: CornerRadius.lg)
```

### Minimum tap targets

```swift
// Always ensure 44pt minimum
Button(action: action) {
    Image(systemName: "plus")
        .frame(minWidth: 44, minHeight: 44)
}

// Content hugging with tappable area
Button(action: action) {
    Text("Small Text")
}
.frame(minHeight: 44)
.contentShape(Rectangle())
```

---

## Accessibility

### Dynamic Type support

```swift
// Ensure layouts adapt
Text("Heading")
    .font(.title)
    .minimumScaleFactor(0.5)
    .lineLimit(2)

// Limit extreme scaling if needed
Text("Content")
    .dynamicTypeSize(.large ... .accessibility2)
```

### Accessibility labels

```swift
Button(action: toggleFavorite) {
    Image(systemName: isFavorite ? "heart.fill" : "heart")
}
.accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

Image("product-photo")
    .accessibilityLabel("Red running shoes, side view")
```

### Reduce transparency

```swift
struct AdaptiveSurface: View {
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency

    var body: some View {
        content
            .background(
                reduceTransparency
                    ? AnyShapeStyle(Color.appSurface)
                    : AnyShapeStyle(.regularMaterial)
            )
    }
}
```

---

## Quick Reference

| Element               | Token/Value                                    |
| --------------------- | ---------------------------------------------- |
| Brand accent          | `BrandColors.orange` / `#FF5E1A`               |
| Primary background    | `SemanticColors.Light/Dark.background`         |
| Primary text          | `SemanticColors.Light/Dark.textPrimary`        |
| Default corner radius | `CornerRadius.lg` / `12pt`                     |
| Standard animation    | `.easeOut(duration: 0.25)`                     |
| Spring animation      | `.spring(response: 0.3, dampingFraction: 0.7)` |
| Min tap target        | `44pt × 44pt`                                  |
| Navigation glass      | `.ultraThinMaterial`                           |
| Sheet glass           | `.regularMaterial`                             |
