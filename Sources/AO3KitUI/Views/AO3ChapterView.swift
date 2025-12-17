import SwiftUI
import AO3Kit

/// A SwiftUI view that renders AO3 chapter content with rich formatting
///
/// This view automatically parses and displays HTML content from AO3 chapters,
/// preserving formatting like bold, italic, colors, and more. It adapts to the
/// parent view's size and inherits the parent's font settings.
///
/// Example usage:
/// ```swift
/// struct ChapterReader: View {
///     let chapter: AO3Chapter
///     let work: AO3Work
///
///     var body: some View {
///         AO3ChapterView(
///             html: chapter.contentHTML,
///             workSkinCSS: work.workSkinCSS
///         )
///         .font(.custom("New York", size: 18))  // Apply your custom font
///         .padding()
///     }
/// }
/// ```
public struct AO3ChapterView: View {
    private let views: [AnyView]
    private let parseError: Error?

    /// Create a chapter view from HTML content
    /// - Parameters:
    ///   - html: The HTML content to render
    ///   - workSkinCSS: Optional CSS from the work's custom skin for color styling
    public init(html: String, workSkinCSS: String? = nil) {
        do {
            self.views = try AO3HTMLRenderer.parse(html, workSkinCSS: workSkinCSS)
            self.parseError = nil
        } catch {
            self.views = []
            self.parseError = error
        }
    }

    /// Create a chapter view directly from an AO3Chapter
    /// - Parameters:
    ///   - chapter: The chapter to render
    ///   - workSkinCSS: Optional CSS from the work's custom skin
    public init(chapter: AO3Chapter, workSkinCSS: String? = nil) {
        self.init(html: chapter.contentHTML, workSkinCSS: workSkinCSS)
    }

    public var body: some View {
        ScrollView {
            if let error = parseError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Failed to parse chapter content")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(views.enumerated()), id: \.offset) { _, view in
                        view
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Convenience extension for rendering chapters with work context
extension AO3ChapterView {
    /// Create a chapter view with automatic work skin CSS
    /// - Parameters:
    ///   - chapter: The chapter to render
    ///   - work: The parent work (for work skin CSS)
    public init(chapter: AO3Chapter, work: AO3Work) {
        self.init(chapter: chapter, workSkinCSS: work.workSkinCSS)
    }
}

// MARK: - Preview Support

#if DEBUG
import struct AO3Kit.AO3MockData

#Preview("Basic Chapter") {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapter1
    )
    .padding()
}

#Preview("Formatted Chapter") {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapterFormatted
    )
    .font(.custom("New York", size: 18))
    .padding()
}

#Preview("Custom Font") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text("System Font")
                .font(.headline)
            AO3ChapterView(
                html: "<p><strong>Bold</strong> and <em>italic</em> text with <span class=\"test\">colors</span>.</p>"
            )

            Divider()

            Text("New York Font")
                .font(.headline)
            AO3ChapterView(
                html: "<p><strong>Bold</strong> and <em>italic</em> text with <span class=\"test\">colors</span>.</p>"
            )
            .font(.custom("New York", size: 18))
        }
        .padding()
    }
}
#endif
