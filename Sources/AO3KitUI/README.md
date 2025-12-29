# AO3KitUI

A SwiftUI companion library for [AO3Kit](../../README.md) that renders AO3 chapter content with rich text formatting.

## Overview

AO3KitUI provides powerful SwiftUI components for displaying AO3 fanfiction content with full formatting support including bold, italic, colors, links, and more. It parses HTML from AO3 chapters and converts it into native SwiftUI views that adapt to your app's design.

## Features

- **Rich Text Rendering**: Preserves all formatting from AO3 including:
  - Text styles (bold, italic, underline, strikethrough)
  - Custom colors from work skins
  - Headings, blockquotes, and horizontal rules
  - Ordered and unordered lists
  - Code blocks with syntax highlighting support
  - Links, superscript, and subscript
  - Right-to-left text support

- **High-Performance UIKit Backend**: Uses UITableView under the hood for buttery-smooth scrolling
  - No jitter or stutter, even on very long chapters
  - Efficient cell reuse for minimal memory usage
  - Position tracking only occurs when scrolling stops

- **SwiftUI Integration**: Seamless integration with SwiftUI apps via UIViewRepresentable
  - Respects parent font settings
  - Dark mode compatible
  - Custom color scheme support
  - Accessibility support through SwiftUI

- **Position Tracking**: Built-in reading progress support
  - Tracks scroll position via binding
  - Restore reading position on chapter reload
  - Updates only on scroll end for maximum performance

- **Easy to Use**: Simple API with multiple integration options

## Installation

AO3KitUI is included in the AO3Kit package. Add it to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/lynatflyt/ao3kit.git", from: "1.0.0")
]
```

Then import both libraries:

```swift
import AO3Kit
import AO3KitUI
```

## Requirements

- iOS 17.0+ / iPadOS 17.0+
- Swift 5.9+
- SwiftUI and UIKit

## Usage

### Basic Chapter Rendering

The simplest way to display a chapter is using `AO3ChapterView`:

```swift
import SwiftUI
import AO3Kit
import AO3KitUI

struct ChapterReaderView: View {
    let chapter: AO3Chapter
    let work: AO3Work
    @State private var scrollPosition: Int? = nil

    var body: some View {
        AO3ChapterView(
            chapter: chapter,
            work: work,
            topVisibleIndex: $scrollPosition
        )
    }
}
```

### Position Tracking and Restoration

Track reading progress and restore position when returning to a chapter:

```swift
struct ChapterReaderView: View {
    let chapter: AO3Chapter
    let work: AO3Work
    @State private var scrollPosition: Int? = nil
    let savedPosition: Int? // Load from your persistence layer

    var body: some View {
        AO3ChapterView(
            chapter: chapter,
            work: work,
            topVisibleIndex: $scrollPosition,
            initialPosition: savedPosition
        )
        .onDisappear {
            // Save scrollPosition to your persistence layer
            if let position = scrollPosition {
                saveReadingProgress(position)
            }
        }
    }
}
```

### Font Design Options

AO3KitUI supports three font designs via the `AO3FontDesign` enum:

```swift
// Serif (recommended for reading)
AO3ChapterView(
    chapter: chapter,
    work: work,
    topVisibleIndex: $scrollPosition,
    fontDesign: .serif
)

// System default
AO3ChapterView(
    chapter: chapter,
    work: work,
    topVisibleIndex: $scrollPosition,
    fontDesign: .default
)

// Rounded
AO3ChapterView(
    chapter: chapter,
    work: work,
    topVisibleIndex: $scrollPosition,
    fontDesign: .rounded
)
```

### Custom Colors

Apply custom text and background colors for reading modes (dark, sepia, etc.):

```swift
AO3ChapterView(
    chapter: chapter,
    work: work,
    topVisibleIndex: $scrollPosition,
    fontSize: 18,
    fontDesign: .serif,
    textColor: UIColor(red: 64/255, green: 62/255, blue: 59/255, alpha: 1),  // Sepia text
    backgroundColor: UIColor(red: 229/255, green: 196/255, blue: 144/255, alpha: 1)  // Sepia background
)
```

### Custom Header View

Add a scrollable header that moves with the content using the `header` parameter:

```swift
AO3ChapterView(
    chapter: chapter,
    work: work,
    topVisibleIndex: $scrollPosition,
    fontSize: 18,
    fontDesign: .serif,
    textColor: .label,
    backgroundColor: .systemBackground
) {
    // Your custom SwiftUI header
    VStack(spacing: 8) {
        Text("Chapter \(chapter.number)")
            .font(.caption)
            .foregroundStyle(.secondary)
        Text(chapter.title)
            .font(.title2)
            .fontWeight(.bold)
    }
    .padding()
}
```

### Full Reading Experience

Build a complete reading interface with preferences:

```swift
struct ChapterView: View {
    let work: AO3Work
    let chapter: AO3Chapter
    @State private var scrollPosition: Int? = nil
    @State private var fontSize: CGFloat = 17
    @State private var fontDesign: AO3FontDesign = .serif
    @State private var isDarkMode = false

    var textColor: UIColor { isDarkMode ? .white : .label }
    var backgroundColor: UIColor { isDarkMode ? .black : .systemBackground }

    var body: some View {
        VStack(spacing: 0) {
            // Chapter content with header
            AO3ChapterView(
                chapter: chapter,
                work: work,
                topVisibleIndex: $scrollPosition,
                fontSize: fontSize,
                fontDesign: fontDesign,
                textColor: textColor,
                backgroundColor: backgroundColor
            ) {
                // Scrollable header
                VStack(spacing: 8) {
                    Text(work.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(chapter.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            // Font size controls
            HStack {
                Button(action: { fontSize = max(12, fontSize - 2) }) {
                    Image(systemName: "textformat.size.smaller")
                }
                Text("\(Int(fontSize))pt")
                    .monospacedDigit()
                Button(action: { fontSize = min(32, fontSize + 2) }) {
                    Image(systemName: "textformat.size.larger")
                }

                Divider()

                Toggle("Dark", isOn: $isDarkMode)
            }
            .padding()
            .background(Color(backgroundColor))
        }
    }
}
```

## Advanced Usage

### Manual HTML Rendering

For more control, use `AO3HTMLRenderer` directly:

```swift
import SwiftUI
import AO3KitUI

struct CustomView: View {
    let views: [AnyView]

    init(html: String, workSkinCSS: String? = nil) {
        do {
            self.views = try AO3HTMLRenderer.parse(html, workSkinCSS: workSkinCSS)
        } catch {
            self.views = []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(views.enumerated()), id: \.offset) { _, view in
                view
            }
        }
    }
}
```

### Using with AO3Chapter Extension

Render chapters directly using the convenience extension:

```swift
let chapter = try await AO3.getChapter(workID: 123, chapterID: 456)
let work = try await AO3.getWork(id: 123)

let views = try chapter.renderAsViews(workSkinCSS: work.workSkinCSS)

// Display in your custom view
ScrollView {
    LazyVStack(alignment: .leading, spacing: 0) {
        ForEach(Array(views.enumerated()), id: \.offset) { _, view in
            view
        }
    }
    .padding()
}
```

## Supported HTML Elements

### Block Elements
- `<p>` - Paragraphs
- `<h1>` through `<h6>` - Headings (relative sizing)
- `<blockquote>` - Blockquotes with styled borders
- `<hr>` - Horizontal rules
- `<ul>` and `<ol>` - Lists (ordered and unordered)
- `<div>` - Containers with alignment support
- `<pre>` and `<code>` - Preformatted text and code blocks
- `<details>` and `<summary>` - Collapsible sections

### Inline Elements
- `<strong>` / `<b>` - Bold text
- `<em>` / `<i>` - Italic text
- `<u>` / `<ins>` - Underlined text
- `<s>` / `<strike>` / `<del>` - Strikethrough text
- `<sup>` - Superscript
- `<sub>` - Subscript
- `<code>` - Inline code (monospaced)
- `<a>` - Links
- `<span>` - Styled spans with work skin colors
- `<br>` - Line breaks

### Special Features
- **Work Skin Colors**: Automatic color parsing from `#workskin` CSS classes
- **Fallback Colors**: Deterministic color generation for unnamed classes
- **RTL Support**: Proper rendering of right-to-left text via `dir="rtl"`
- **Nested Formatting**: Complex combinations like bold italic colored text

## Architecture

AO3KitUI uses a multi-stage rendering pipeline with UIKit for optimal performance:

1. **CSS Parsing** (`CSSParser`)
   - Extracts color definitions from work skin CSS
   - Creates color mappings for custom classes

2. **HTML Parsing** (`HTMLParser`)
   - Converts HTML to intermediate `HTMLNode` tree
   - Preserves formatting hierarchy and styles
   - Handles inline and block elements correctly

3. **View Building** (`HTMLViewBuilder`)
   - Transforms nodes into SwiftUI views
   - Groups inline elements to prevent unwanted line breaks
   - Applies formatting while respecting parent styles

4. **UIKit Display** (`AO3ChapterView`)
   - Wraps UITableView via UIViewRepresentable
   - Each parsed view becomes a reusable table cell
   - Uses UIHostingController to embed SwiftUI in cells
   - Tracks scroll position via UIScrollViewDelegate

```
HTML String → CSSParser → WorkSkin
     ↓                       ↓
HTMLParser ← ← ← ← ← ← ← ← ←
     ↓
HTMLNode Tree
     ↓
HTMLViewBuilder
     ↓
SwiftUI Views (AnyView array)
     ↓
UITableView + UIHostingController cells
```

## Performance Considerations

`AO3ChapterView` is designed for maximum performance out of the box:

- **UITableView Backend**: Uses native UIKit scrolling for buttery-smooth performance
- **Cell Reuse**: Efficient memory usage via UITableViewCell recycling
- **Lazy Position Tracking**: Scroll position only updates when scrolling ends
  - Uses `scrollViewDidEndDragging` and `scrollViewDidEndDecelerating`
  - No overhead during active scrolling
- **Styling Updates**: Changes to font size, font design, or colors trigger a table reload
- **Header View**: Custom SwiftUI headers use UIHostingController as tableHeaderView

### Why UIKit?

SwiftUI's ScrollView and LazyVStack can introduce jitter when:
- Tracking scroll position via onChange or scrollPosition bindings
- Loading/unloading views during scroll
- Updating @State properties during scroll

By using UITableView directly, we get native-quality scrolling performance while keeping the SwiftUI API surface clean and familiar.

### Parsing Performance

- **Caching**: Parse results are not cached - consider caching rendered views if needed
- **Memory**: Each chapter parse creates a new node tree
- **Threading**: Parsing is synchronous; consider dispatching to background queue for very large chapters

## SwiftUI Previews

AO3KitUI views work great with SwiftUI previews:

```swift
#Preview("Chapter View") {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapter1,
        work: AO3MockData.sampleWork1,
        topVisibleIndex: .constant(nil),
        fontSize: 18,
        fontDesign: .serif
    )
}

#Preview("Dark Mode") {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapter1,
        work: AO3MockData.sampleWork1,
        topVisibleIndex: .constant(nil),
        fontSize: 18,
        fontDesign: .serif,
        textColor: .white,
        backgroundColor: .black
    )
}

#Preview("With Header") {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapter1,
        work: AO3MockData.sampleWork1,
        topVisibleIndex: .constant(nil),
        fontSize: 18,
        fontDesign: .serif
    ) {
        Text("Custom Header")
            .font(.title)
            .padding()
    }
}
```

## Error Handling

`AO3ChapterView` handles parsing errors gracefully. If HTML parsing fails, the view will display an empty table. For manual error handling:

```swift
// Manual error handling with AO3HTMLRenderer
do {
    let views = try AO3HTMLRenderer.parse(html, workSkinCSS: css)
    // Use views in your own implementation
} catch {
    print("Failed to parse: \(error)")
    // Show custom error UI
}
```

## Limitations

- **iOS/iPadOS Only**: `AO3ChapterView` uses UITableView and is only available on iOS/iPadOS
- **Tables**: Not currently supported (displays placeholder text)
- **Images**: Not rendered (displays alt text)
- **Ruby Annotations**: Not yet implemented
- **Custom Fonts in Code**: Code blocks don't inherit custom fonts (always monospaced)
- **JavaScript**: Not executed (static rendering only)

## Contributing

Contributions are welcome! Areas for improvement:

- Table rendering support
- Image loading and caching
- Ruby annotation (furigana) support
- Enhanced code block styling
- Performance optimizations for very long chapters

## Credits

- Built on top of [AO3Kit](../../README.md)
- Uses [SwiftSoup](https://github.com/scinfu/SwiftSoup) for HTML parsing
- Inspired by web-based AO3 reading experiences

## License

See the main [LICENSE](../../LICENSE) file for details.
