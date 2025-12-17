import SwiftUI

/// Renders inline text with nested formatting (bold, italic, colors, links)
struct FormattedText: View {
    let nodes: [HTMLNode]
    let baseStyle: TextStyle

    var body: some View {
        buildText(from: nodes, style: baseStyle)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Recursively build Text with formatting
    private func buildText(from nodes: [HTMLNode], style: TextStyle) -> Text {
        var result = Text("")

        for node in nodes {
            result = result + textForNode(node, style: style)
        }

        return result
    }

    private func textForNode(_ node: HTMLNode, style: TextStyle) -> Text {
        switch node {
        case .text(let string):
            return applyStyle(Text(string), style: style)

        case .formatted(let children, let nodeStyle):
            let mergedStyle = style.merging(nodeStyle)
            return buildText(from: children, style: mergedStyle)

        case .link(_, let children):
            // Links are handled separately in ViewBuilder
            // For inline text, render as blue underlined text
            var linkStyle = style
            linkStyle.isUnderlined = true
            linkStyle.color = ColorInfo(red: 0, green: 0.478, blue: 1.0) // SwiftUI blue
            return buildText(from: children, style: linkStyle)

        case .span(let children, _):
            return buildText(from: children, style: style)

        case .lineBreak:
            return Text("\n")

        // Block elements shouldn't appear here, but handle gracefully
        default:
            return Text("")
        }
    }

    private func applyStyle(_ text: Text, style: TextStyle) -> Text {
        var result = text

        if style.isBold {
            result = result.fontWeight(.bold)
        }

        if style.isItalic {
            result = result.italic()
        }

        if style.isUnderlined {
            result = result.underline()
        }

        if style.isStrikethrough {
            result = result.strikethrough()
        }

        // Note: We don't apply monospaced here to allow parent font to control design
        // Users can apply .monospaced() to the parent view if desired

        if let color = style.color {
            result = result.foregroundColor(Color(red: color.red, green: color.green, blue: color.blue))
        }

        // Superscript/subscript using relative font size + baseline offset
        if style.isSuperscript {
            result = result.font(.system(size: 12, weight: .regular, design: .default)).baselineOffset(6)
        }

        if style.isSubscript {
            result = result.font(.system(size: 12, weight: .regular, design: .default)).baselineOffset(-3)
        }

        return result
    }
}
