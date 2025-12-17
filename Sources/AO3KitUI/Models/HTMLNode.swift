import Foundation
import SwiftUI

/// Intermediate representation of parsed HTML
public enum HTMLNode: Sendable {
    // Block-level elements (create vertical spacing)
    case paragraph(children: [HTMLNode])
    case heading(level: Int, children: [HTMLNode])
    case blockquote(children: [HTMLNode])
    case codeBlock(code: String, language: String?)
    case preformatted(text: String)
    case horizontalRule
    case list(ordered: Bool, items: [[HTMLNode]])
    case listItem(children: [HTMLNode])
    case div(children: [HTMLNode], attributes: [String: String])
    case details(summary: [HTMLNode], content: [HTMLNode])

    // Inline elements (no line breaks)
    case text(String)
    case formatted(children: [HTMLNode], style: TextStyle)
    case link(url: String, children: [HTMLNode])
    case lineBreak
    case span(children: [HTMLNode], className: String?)

    /// Check if this node is a block-level element
    public var isBlock: Bool {
        switch self {
        case .paragraph, .heading, .blockquote, .codeBlock,
             .preformatted, .horizontalRule, .list, .div, .details:
            return true
        case .text, .formatted, .link, .lineBreak, .span, .listItem:
            return false
        }
    }
}

/// Accumulated text styling attributes
public struct TextStyle: Sendable, Equatable {
    public var isBold: Bool = false
    public var isItalic: Bool = false
    public var isUnderlined: Bool = false
    public var isStrikethrough: Bool = false
    public var isSuperscript: Bool = false
    public var isSubscript: Bool = false
    public var isCode: Bool = false
    public var color: ColorInfo? = nil
    public var alignment: TextAlignment? = nil
    public var isRTL: Bool = false

    public init() {}

    /// Merge styles (child inherits parent)
    public func merging(_ other: TextStyle) -> TextStyle {
        var result = self
        if other.isBold { result.isBold = true }
        if other.isItalic { result.isItalic = true }
        if other.isUnderlined { result.isUnderlined = true }
        if other.isStrikethrough { result.isStrikethrough = true }
        if other.isSuperscript { result.isSuperscript = true }
        if other.isSubscript { result.isSubscript = true }
        if other.isCode { result.isCode = true }
        if other.color != nil { result.color = other.color }
        if other.alignment != nil { result.alignment = other.alignment }
        if other.isRTL { result.isRTL = true }
        return result
    }
}

/// Color information for styling
public struct ColorInfo: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Create color from hex string (without #)
    public static func fromHex(_ hex: String) -> ColorInfo {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        return ColorInfo(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }

    /// Generate deterministic color from class name (fallback)
    public static func fromClassName(_ className: String) -> ColorInfo {
        let hash = className.hashValue
        return ColorInfo(
            red: Double((hash & 0xFF0000) >> 16) / 255.0,
            green: Double((hash & 0x00FF00) >> 8) / 255.0,
            blue: Double(hash & 0x0000FF) / 255.0
        )
    }
}

/// Text alignment options
public enum TextAlignment: Sendable {
    case leading, center, trailing
}
