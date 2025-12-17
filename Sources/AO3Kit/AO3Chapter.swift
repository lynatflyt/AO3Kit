import Foundation
import SwiftSoup

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Object exposing information about a chapter. Contains the title, the content itself and author notes.
public class AO3Chapter: AO3Data, @unchecked Sendable {
    public let workID: Int
    public let id: Int
    public private(set) var title: String = ""
    public private(set) var content: String = ""
    public private(set) var contentHTML: String = "" // Raw HTML content with formatting
    public private(set) var notes: [String] = []
    public private(set) var summary: String = ""

    internal init(workID: Int, chapterID: Int) async throws {
        self.workID = workID
        self.id = chapterID
        super.init()
        try await loadChapterData()
    }

    private enum CodingKeys: String, CodingKey {
        case workID, id, title, content, contentHTML, notes, summary
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workID = try container.decode(Int.self, forKey: .workID)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        contentHTML = try container.decodeIfPresent(String.self, forKey: .contentHTML) ?? ""
        notes = try container.decode([String].self, forKey: .notes)
        summary = try container.decode(String.self, forKey: .summary)
        super.init()
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workID, forKey: .workID)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(contentHTML, forKey: .contentHTML)
        try container.encode(notes, forKey: .notes)
        try container.encode(summary, forKey: .summary)
    }

    private func loadChapterData() async throws {
        let document = try await getDocument()

        // Parse title
        if let prefaceDiv = try document.select("div.chapter.preface.group").first(),
           let h3 = try prefaceDiv.select("h3").first() {
            let ownText = h3.ownText()
            title = ownText.replacingOccurrences(of: ": ", with: "").trimmingCharacters(in: .whitespaces)
        }

        // Parse content
        if let article = try document.select("[role=article]").first() {
            let paragraphs = try article.select("p")
            // Store both plain text and HTML
            let contentArray = try paragraphs.map { try $0.text() }
            content = contentArray.joined(separator: "\n")

            // Preserve <p> tags by using outerHtml() instead of html()
            let htmlArray = try paragraphs.map { try $0.outerHtml() }
            contentHTML = htmlArray.joined(separator: "\n")
        }

        // Parse notes
        var tempNotes: [String] = []
        let notesModules = try document.select("div.notes.module")
        for noteModule in notesModules {
            if let userstuff = try noteModule.select(".userstuff").first() {
                let paragraphs = try userstuff.select("p")
                let noteText = try paragraphs.map { try $0.text() }.joined(separator: "\n")
                if !noteText.isEmpty {
                    tempNotes.append(noteText)
                }
            }
        }
        notes = tempNotes

        // Parse summary
        if let summaryDiv = try document.select("div.summary.module").first(),
           let blockquote = try summaryDiv.select("blockquote.userstuff").first() {
            let paragraphs = try blockquote.select("p")
            let summaryArray = try paragraphs.map { try $0.html() }
            summary = summaryArray.joined(separator: "\n")
        }
    }

    internal override func buildURL() -> String {
        return "https://archiveofourown.org/works/\(workID)/chapters/\(id)"
    }

    /// Converts the chapter's HTML content to an AttributedString with formatting preserved
    /// - Returns: AttributedString with bold, italic, and custom color formatting from AO3
    /// - Note: Custom color classes from AO3 (like span.FakeIDCallie) are preserved as foregroundColor attributes
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func getAttributedContent() throws -> AttributedString {
        return try AO3Chapter.htmlToAttributedString(contentHTML)
    }

    /// Converts HTML content to AttributedString with formatting
    /// - Parameter html: The HTML string to convert
    /// - Returns: AttributedString with formatting applied
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public static func htmlToAttributedString(_ html: String) throws -> AttributedString {
        var result = AttributedString()

        // Split by newlines to preserve paragraph structure
        let paragraphs = html.components(separatedBy: "\n")

        for (index, paragraphHTML) in paragraphs.enumerated() {
            if index > 0 {
                result += AttributedString("\n")
            }

            // Parse the paragraph HTML
            let doc = try SwiftSoup.parse("<p>\(paragraphHTML)</p>")
            guard let paragraph = try doc.select("p").first() else { continue }

            // Process all text nodes and elements
            result += try processNode(paragraph)
        }

        return result
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    private static func processNode(_ node: Element, inheritedAttributes: AttributeContainer = AttributeContainer()) throws -> AttributedString {
        var result = AttributedString()
        var attributes = inheritedAttributes

        // Apply formatting based on tag
        let tagName = node.tagName().lowercased()
        switch tagName {
        case "em", "i":
            attributes.inlinePresentationIntent = .emphasized
        case "strong", "b":
            attributes.inlinePresentationIntent = .stronglyEmphasized
        case "span":
            // Handle custom color classes from AO3
            if let className = try? node.className(), !className.isEmpty {
                // Extract color from common AO3 patterns
                attributes = applyColorFromClassName(className, to: attributes)
            }
        default:
            break
        }

        // Process child nodes
        for child in node.getChildNodes() {
            if let textNode = child as? TextNode {
                var text = AttributedString(textNode.text())
                text.setAttributes(attributes)
                result += text
            } else if let element = child as? Element {
                result += try processNode(element, inheritedAttributes: attributes)
            }
        }

        return result
    }

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    private static func applyColorFromClassName(_ className: String, to attributes: AttributeContainer) -> AttributeContainer {
        var attrs = attributes

        // Common AO3 color patterns - you can expand this based on common class names
        // For now, we'll use a simple hash-based color generation for custom classes
        let colorMap: [String: (red: Double, green: Double, blue: Double)] = [:]
        // You can add specific known color classes here
        // Example: "FakeIDCallie": (0.8, 0.2, 0.2),

        if let rgb = colorMap[className] {
            #if canImport(AppKit)
            attrs.foregroundColor = NSColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
            #elseif canImport(UIKit)
            attrs.foregroundColor = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
            #endif
        } else {
            // Generate a deterministic color from the class name for custom spans
            let hash = className.hashValue
            let red = Double((hash & 0xFF0000) >> 16) / 255.0
            let green = Double((hash & 0x00FF00) >> 8) / 255.0
            let blue = Double(hash & 0x0000FF) / 255.0

            #if canImport(AppKit)
            attrs.foregroundColor = NSColor(red: red, green: green, blue: blue, alpha: 1.0)
            #elseif canImport(UIKit)
            attrs.foregroundColor = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
            #endif
        }

        return attrs
    }
}
