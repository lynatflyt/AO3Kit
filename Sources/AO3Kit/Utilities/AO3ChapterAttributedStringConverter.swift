import Foundation
import SwiftSoup

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Converts AO3 chapter HTML to AttributedString with formatting
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
internal struct AO3ChapterAttributedStringConverter {
    /// Converts HTML content to AttributedString with formatting
    /// - Parameter html: The HTML string to convert
    /// - Returns: AttributedString with formatting applied
    static func convert(_ html: String) throws -> AttributedString {
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

    // MARK: - Private Helpers

    private static func processNode(
        _ node: Element,
        inheritedAttributes: AttributeContainer = AttributeContainer()
    ) throws -> AttributedString {
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

    private static func applyColorFromClassName(
        _ className: String,
        to attributes: AttributeContainer
    ) -> AttributeContainer {
        var attrs = attributes

        // Common AO3 color patterns - you can expand this based on common class names
        let colorMap: [String: (red: Double, green: Double, blue: Double)] = [:]

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
