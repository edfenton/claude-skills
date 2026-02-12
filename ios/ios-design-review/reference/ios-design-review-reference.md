# iOS Design Review Reference

Screen discovery, evaluation checklists, and preview testing patterns.

---

## Screen discovery

### Find all views

```bash
# List all View files
find . -name "*View.swift" -path "*/Features/*"

# Count screens per feature
find . -name "*View.swift" -path "*/Features/*" | cut -d'/' -f4 | sort | uniq -c
```

### Expected structure

```
Features/
├── Home/
│   ├── HomeView.swift          # Main screen
│   ├── HomeViewModel.swift
│   └── HomeRow.swift           # Subview (review if complex)
├── Settings/
│   ├── SettingsView.swift      # Main screen
│   └── SettingsViewModel.swift
└── Profile/
    ├── ProfileView.swift       # Main screen
    ├── ProfileViewModel.swift
    └── EditProfileSheet.swift  # Sheet (review)
```

---

## Preview testing

### Multi-device preview

```swift
#Preview {
    HomeView()
}

#Preview("iPhone SE") {
    HomeView()
        .previewDevice("iPhone SE (3rd generation)")
}

#Preview("iPad") {
    HomeView()
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
}

#Preview("Landscape") {
    HomeView()
        .previewInterfaceOrientation(.landscapeLeft)
}
```

### Dynamic Type preview

```swift
#Preview("Large Text") {
    HomeView()
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Accessibility Size") {
    HomeView()
        .environment(\.dynamicTypeSize, .accessibility3)
}
```

### Accessibility previews

```swift
#Preview("Reduce Motion") {
    HomeView()
        .environment(\.accessibilityReduceMotion, true)
}

#Preview("Reduce Transparency") {
    HomeView()
        .environment(\.accessibilityReduceTransparency, true)
}

#Preview("High Contrast") {
    HomeView()
        .environment(\.colorSchemeContrast, .increased)
}
```

### Dark mode preview

```swift
#Preview("Dark Mode") {
    HomeView()
        .preferredColorScheme(.dark)
}
```

---

## Evaluation checklist

### Device adaptation

| Check                       | iPhone                 | iPad                                      |
| --------------------------- | ---------------------- | ----------------------------------------- |
| Layout uses available space | Focused, single column | Multi-column or sidebar where appropriate |
| Navigation pattern          | Stack or tab           | Split view or sidebar                     |
| Information density         | Mobile-appropriate     | Can show more at once                     |
| Touch targets               | ≥44pt                  | ≥44pt                                     |
| Orientation                 | Portrait primary       | Both orientations                         |

**Red flags:**

- iPad shows identical layout to iPhone (just bigger)
- No size class adaptation
- Landscape orientation broken or ignored

### Liquid Glass usage

| Location                | Appropriate?       |
| ----------------------- | ------------------ |
| Navigation bar          | ✅ Yes             |
| Tab bar                 | ✅ Yes             |
| Sheet/modal background  | ✅ Yes             |
| Floating action overlay | ✅ Yes             |
| Hero card overlay       | ✅ Yes (sparingly) |
| List rows               | ❌ No              |
| Form fields             | ❌ No              |
| Primary reading surface | ❌ No              |
| Behind dense text       | ❌ No              |
| Every surface           | ❌ No              |

**Red flags:**

- Glass applied to reading content
- Multiple glass layers stacked
- Glass doesn't adapt with reduce transparency

### Typography

| Check        | Pass criteria                                            |
| ------------ | -------------------------------------------------------- |
| Font choice  | System (San Francisco) for body; custom only for display |
| Hierarchy    | Clear heading → subhead → body progression               |
| Dynamic Type | Layouts don't break at accessibility sizes               |
| Line length  | Comfortable reading width (45-75 characters)             |
| Not banned   | No Inter, Roboto, Open Sans, etc. as primary             |

**Red flags:**

- All text same size/weight
- Fixed heights that clip text
- Custom font for body text (usually wrong)

### Spacing & ergonomics

| Check       | Pass criteria                         |
| ----------- | ------------------------------------- |
| Tap targets | ≥44×44pt for all interactive elements |
| Padding     | Consistent, generous                  |
| Alignment   | Intentional, follows grid             |
| Density     | Balanced—not cramped or sparse        |
| Safe areas  | Respects notch, home indicator        |

**Red flags:**

- Small icons without adequate hit area
- Inconsistent margins between screens
- Content under notch or home indicator

### Accessibility

| Check        | Pass criteria                           |
| ------------ | --------------------------------------- |
| VoiceOver    | All controls have labels                |
| Semantics    | Buttons are buttons, not tappable text  |
| Color        | Meaning not conveyed by color alone     |
| Contrast     | Text readable in both modes             |
| Motion       | Respects reduce motion preference       |
| Transparency | Respects reduce transparency preference |

**Red flags:**

- Image-only buttons without labels
- Status indicated only by color
- Animations ignore reduce motion

### "Not generic" bar

| Anti-pattern     | What to look for                            |
| ---------------- | ------------------------------------------- |
| Default SwiftUI  | Unstyled List, NavigationLink, Form         |
| Repetitive cards | Same card repeated without visual variation |
| No hierarchy     | Everything has equal visual weight          |
| Template layout  | Standard list → detail with no personality  |
| Overused effects | Glass/blur on everything                    |

**Red flags:**

- Could be any app's settings screen
- No brand presence
- Purely functional, no craft

---

## Common issues and fixes

### Issue: iPad is stretched iPhone

```swift
// ❌ Same layout everywhere
var body: some View {
    List(items) { item in
        ItemRow(item: item)
    }
}

// ✅ Adaptive layout
var body: some View {
    if horizontalSizeClass == .regular {
        NavigationSplitView {
            List(items, selection: $selected) { item in
                ItemRow(item: item)
            }
        } detail: {
            if let item = selected {
                ItemDetail(item: item)
            }
        }
    } else {
        NavigationStack {
            List(items) { item in
                NavigationLink(value: item) {
                    ItemRow(item: item)
                }
            }
            .navigationDestination(for: Item.self) { item in
                ItemDetail(item: item)
            }
        }
    }
}
```

### Issue: Liquid Glass on reading surface

```swift
// ❌ Glass behind content
ScrollView {
    VStack {
        ForEach(paragraphs) { p in
            Text(p.text)
        }
    }
    .background(.regularMaterial) // Don't do this
}

// ✅ Solid background for reading
ScrollView {
    VStack {
        ForEach(paragraphs) { p in
            Text(p.text)
        }
    }
    .background(Color.appBackground)
}
```

### Issue: Dynamic Type breaks layout

```swift
// ❌ Fixed height clips text
Text(title)
    .frame(height: 44)

// ✅ Minimum height allows growth
Text(title)
    .frame(minHeight: 44)
    .fixedSize(horizontal: false, vertical: true)
```

### Issue: Missing VoiceOver label

```swift
// ❌ No label
Button(action: favorite) {
    Image(systemName: "heart.fill")
}

// ✅ With label
Button(action: favorite) {
    Image(systemName: "heart.fill")
}
.accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
```

### Issue: Small tap target

```swift
// ❌ Icon alone is too small
Button(action: action) {
    Image(systemName: "plus")
        .font(.system(size: 16))
}

// ✅ Adequate tap area
Button(action: action) {
    Image(systemName: "plus")
        .font(.system(size: 20))
        .frame(minWidth: 44, minHeight: 44)
}
.contentShape(Rectangle())
```

### Issue: Default SwiftUI appearance

```swift
// ❌ Unstyled default
List {
    ForEach(items) { item in
        Text(item.name)
    }
}

// ✅ Styled with brand
List {
    ForEach(items) { item in
        HStack {
            Text(item.name)
                .font(.headline)
            Spacer()
            Text(item.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .listRowBackground(Color.appSurface)
    }
}
.listStyle(.plain)
.scrollContentBackground(.hidden)
.background(Color.appBackground)
```

---

## Report template

```
## Design Review Results

**Scope:** All Features/
**Screens reviewed:** 8

### Summary
| Severity | Count |
|----------|-------|
| Must-fix | 3 |
| Should-fix | 6 |
| Nice-to-have | 4 |

### Systemic Issues
- iPad layouts are stretched iPhone (affects 5/8 screens)
- Dynamic Type breaks layout at accessibility sizes (affects 3/8 screens)

### Findings by Screen

#### HomeView.swift

**[must-fix] iPad layout is stretched iPhone**
- No size class adaptation
- *Fix: Use NavigationSplitView for regular width*

**[should-fix] Missing VoiceOver label on filter button**
- `Image(systemName: "line.3.horizontal.decrease")` has no label
- *Fix: Add `.accessibilityLabel("Filter items")`*

#### SettingsView.swift

**[must-fix] Liquid Glass behind form**
- `.background(.regularMaterial)` on form content
- *Fix: Use solid `Color.appBackground`*

**[nice-to-have] Default Form styling**
- Looks like every Settings screen
- *Fix: Consider custom section headers with brand typography*

#### ProfileView.swift

**[should-fix] Small tap target on edit button**
- Icon is 24×24pt, needs padding for 44pt target
- *Fix: Add `.frame(minWidth: 44, minHeight: 44)`*

**[should-fix] Fixed height clips name at large Dynamic Type**
- `.frame(height: 60)` on name label
- *Fix: Use `.frame(minHeight: 60)`*

...
```

---

## Xcode preview testing workflow

```bash
# Open Xcode with preview canvas
# 1. Select a *View.swift file
# 2. Editor → Canvas (or Option+Cmd+Return)
# 3. Add preview variants for different devices/settings
# 4. Use "Selectable" mode to inspect accessibility

# Run accessibility audit
# Product → Perform Action → Run Accessibility Audit
```

---

## Quick reference

| Check          | Tool/Method                                                    |
| -------------- | -------------------------------------------------------------- |
| iPhone layout  | Preview with iPhone device                                     |
| iPad layout    | Preview with iPad device                                       |
| Dynamic Type   | Preview with `.environment(\.dynamicTypeSize, .xxxLarge)`      |
| VoiceOver      | Xcode Accessibility Inspector or device                        |
| Reduce motion  | Preview with `.environment(\.accessibilityReduceMotion, true)` |
| Color contrast | Xcode Accessibility Inspector                                  |
| Tap targets    | Visual inspection (44pt = ~12mm)                               |
