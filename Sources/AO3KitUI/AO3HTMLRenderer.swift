import SwiftUI
import AO3Kit

/// Main API for rendering AO3 HTML content as SwiftUI views
public struct AO3HTMLRenderer {

    /// Parse HTML and return an array of SwiftUI views
    /// - Parameters:
    ///   - html: The HTML string to parse
    ///   - workSkinCSS: Optional CSS from work skin for custom colors
    /// - Returns: Array of AnyView that can be embedded in VStack/ScrollView
    /// - Throws: Parsing errors from SwiftSoup
    ///
    /// Example usage:
    /// ```swift
    /// let chapter = try await AO3.getChapter(workID: 123, chapterID: 456)
    /// let work = try await AO3.getWork(id: 123)
    /// let views = try AO3HTMLRenderer.parse(chapter.contentHTML, workSkinCSS: work.workSkinCSS)
    ///
    /// ScrollView {
    ///     VStack(alignment: .leading, spacing: 0) {
    ///         ForEach(Array(views.enumerated()), id: \.offset) { _, view in
    ///             AnyView(view)
    ///         }
    ///     }
    ///     .padding()
    /// }
    /// ```
    public static func parse(_ html: String, workSkinCSS: String? = nil) throws -> [AnyView] {
        // Step 1: Parse CSS to get color mappings
        let workSkin = CSSParser.parse(workSkinCSS)

        // Step 2: Parse HTML into intermediate representation
        let nodes = try HTMLParser.parse(html, workSkin: workSkin)

        // Step 3: Convert nodes to SwiftUI views
        let context = RenderContext(workSkin: workSkin)
        let views = HTMLViewBuilder.buildViews(from: nodes, context: context)

        return views
    }
}

// MARK: - Convenience Extension

extension AO3Chapter {
    /// Render this chapter's HTML content as SwiftUI views
    /// - Parameter workSkinCSS: Optional CSS from the work for custom colors
    /// - Returns: Array of views ready to display
    /// - Throws: Parsing errors
    public func renderAsViews(workSkinCSS: String? = nil) throws -> [AnyView] {
        return try AO3HTMLRenderer.parse(self.contentHTML, workSkinCSS: workSkinCSS)
    }
}
