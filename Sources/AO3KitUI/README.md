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

- **SwiftUI Native**: Uses pure SwiftUI Text and View composition
  - Fully adaptive to parent view size
  - Respects parent font settings (use any font, including New York)
  - Dark mode compatible
  - Accessibility support through SwiftUI

- **Easy to Use**: Simple API with multiple integration options
- **Performance Optimized**: Efficient parsing and lazy rendering

## Installation

AO3KitUI is included in the AO3Kit package. Add it to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ao3kit.git", from: "1.0.0")
]
```

Then import both libraries:

```swift
import AO3Kit
import AO3KitUI
```

## Requirements

- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+
- Swift 5.9+
- SwiftUI

## Usage

### Basic Chapter Rendering

The simplest way to display a chapter is using `AO3ChapterView`:

```swift
import SwiftUI
import AO3Kit
import AO3KitUI

struct ChapterReaderView: View {
    let chapter: AO3Chapter

    var body: some View {
        AO3ChapterView(chapter: chapter)
            .padding()
    }
}
```

### With Work Skin Support

Work skins allow authors to customize colors in their fics. Pass the work's CSS to render custom colors:

```swift
struct ChapterReaderView: View {
    let chapter: AO3Chapter
    let work: AO3Work

    var body: some View {
        AO3ChapterView(
            chapter: chapter,
            workSkinCSS: work.workSkinCSS
        )
        .padding()
    }
}

// Or use the convenience initializer:
AO3ChapterView(chapter: chapter, work: work)
```

### Custom Fonts

AO3KitUI respects your font settings, making it easy to use custom fonts:

```swift
AO3ChapterView(chapter: chapter)
    .font(.custom("New York", size: 18))
    .padding()

// Or use system fonts with different sizes
AO3ChapterView(chapter: chapter)
    .font(.system(size: 20, design: .serif))
    .padding()
```

### Custom Styling

Style the chapter view like any SwiftUI view:

```swift
AO3ChapterView(chapter: chapter, work: work)
    .font(.custom("Georgia", size: 17))
    .foregroundColor(.primary)
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(Color(.systemBackground))
```

### Full Reading Experience

Build a complete reading interface:

```swift
struct ChapterView: View {
    let work: AO3Work
    let chapter: AO3Chapter
    @State private var fontSize: CGFloat = 17

    var body: some View {
        VStack(spacing: 0) {
            // Chapter header
            VStack(alignment: .leading, spacing: 8) {
                Text(work.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(chapter.title)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))

            // Chapter content
            AO3ChapterView(chapter: chapter, work: work)
                .font(.system(size: fontSize, design: .serif))
                .padding()

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
            }
            .padding()
            .background(Color(.secondarySystemBackground))
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

AO3KitUI uses a three-stage rendering pipeline:

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
```

## Performance Considerations

- **Lazy Rendering**: Use `LazyVStack` for long chapters
- **Caching**: Parse results are not cached - consider caching rendered views if needed
- **Memory**: Each chapter parse creates a new node tree
- **Threading**: Parsing is synchronous; consider dispatching to background queue for large chapters

Example with background parsing:

```swift
struct ChapterView: View {
    let chapter: AO3Chapter
    @State private var views: [AnyView] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(views.enumerated()), id: \.offset) { _, view in
                            view
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            views = await Task.detached {
                try? AO3HTMLRenderer.parse(chapter.contentHTML)
            }.value ?? []
            isLoading = false
        }
    }
}
```

## SwiftUI Previews

AO3KitUI views work great with SwiftUI previews:

```swift
#Preview {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapterFormatted
    )
    .font(.custom("New York", size: 18))
    .padding()
}

#Preview("Dark Mode") {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapter1
    )
    .preferredColorScheme(.dark)
    .padding()
}
```

## Error Handling

`AO3ChapterView` handles parsing errors gracefully:

```swift
// Displays error UI if HTML parsing fails
AO3ChapterView(html: invalidHTML)

// Manual error handling
do {
    let views = try AO3HTMLRenderer.parse(html, workSkinCSS: css)
    // Use views
} catch {
    print("Failed to parse: \(error)")
    // Show custom error UI
}
```

## Limitations

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
