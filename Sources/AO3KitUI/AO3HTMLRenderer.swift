import SwiftUI
import UIKit
import AO3Kit

/// Main API for rendering AO3 HTML content as SwiftUI views
public struct AO3HTMLRenderer {

    /// Parse HTML and return an NSAttributedString
    /// - Parameters:
    ///   - html: The HTML string to parse
    ///   - workSkinCSS: Optional CSS from work skin
    ///   - fontSize: Base font size
    ///   - fontDesign: Font design
    ///   - textColor: Text color
    ///   - textAlignment: Alignment for paragraphs
    /// - Returns: NSAttributedString ready for UITextView
    public static func parseToAttributed(
        _ html: String,
        workSkinCSS: String? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        textAlignment: AO3TextAlignment = .leading
    ) throws -> NSAttributedString {
        let workSkin = CSSParser.parse(workSkinCSS)
        let nodes = try HTMLParser.parse(html, workSkin: workSkin)
        
        // Convert AO3TextAlignment to NSTextAlignment
        let nsAlignment: NSTextAlignment
        switch textAlignment {
        case .leading: nsAlignment = .left
        case .center: nsAlignment = .center
        case .trailing: nsAlignment = .right
        case .justified: nsAlignment = .justified
        }

        return AttributedStringBuilder.build(
            from: nodes,
            baseStyle: TextStyle(), // Start with clean style
            fontSize: fontSize,
            fontDesign: fontDesign.uiFontDescriptorDesign,
            textColor: textColor,
            alignment: nsAlignment
        )
    }

    /// Parse HTML and return an array of SwiftUI views
    /// - Parameters:
    ///   - html: The HTML string to parse
    ///   - workSkinCSS: Optional CSS from work skin for custom colors
    ///   - textSelectionEnabled: Enable text selection on rendered text
    ///   - textAlignment: Text alignment for paragraphs
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
    public static func parse(
        _ html: String,
        workSkinCSS: String? = nil,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        fontSize: CGFloat = 17,
        fontDesign: UIFontDescriptor.SystemDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground
    ) throws -> [AnyView] {
        // Step 1: Parse CSS to get color mappings
        let workSkin = CSSParser.parse(workSkinCSS)

        // Step 2: Parse HTML into intermediate representation
        let nodes = try HTMLParser.parse(html, workSkin: workSkin)

        // Step 3: Convert nodes to SwiftUI views
        let context = RenderContext(
            workSkin: workSkin,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
        let views = HTMLViewBuilder.buildViews(
            from: nodes,
            context: context,
            textSelectionEnabled: textSelectionEnabled,
            textAlignment: textAlignment
        )

        return views
    }
}

// MARK: - Convenience Extension

extension AO3Chapter {
    /// Render this chapter's HTML content as SwiftUI views
    /// - Parameters:
    ///   - workSkinCSS: Optional CSS from the work for custom colors
    ///   - textSelectionEnabled: Enable text selection on rendered text
    ///   - textAlignment: Text alignment for paragraphs
    ///   - fontSize: Font size for text rendering
    ///   - fontDesign: Font design for text rendering
    ///   - textColor: Text color for rendering
    ///   - backgroundColor: Background color for rendering
    /// - Returns: Array of views ready to display
    /// - Throws: Parsing errors
    public func renderAsViews(
        workSkinCSS: String? = nil,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        fontSize: CGFloat = 17,
        fontDesign: UIFontDescriptor.SystemDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground
    ) throws -> [AnyView] {
        return try AO3HTMLRenderer.parse(
            self.contentHTML,
            workSkinCSS: workSkinCSS,
            textSelectionEnabled: textSelectionEnabled,
            textAlignment: textAlignment,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
    }
}
