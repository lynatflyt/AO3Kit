import SwiftUI

/// Set to true to show debug background colors on text elements
private let DEBUG_SHOW_TEXT_BACKGROUNDS = false

/// Renders inline text with nested formatting (bold, italic, colors, links)
struct FormattedText: View {
    let nodes: [HTMLNode]
    let baseStyle: TextStyle

    var body: some View {
        if DEBUG_SHOW_TEXT_BACKGROUNDS {
            // Debug mode: show each text segment with background color
            buildDebugText(from: nodes, style: baseStyle)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            buildText(from: nodes, style: baseStyle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Debug Text Builder (shows backgrounds via colored text)

    /// Build text with debug colors showing node boundaries
    private func buildDebugText(from nodes: [HTMLNode], style: TextStyle) -> Text {
        var result = Text("")

        for (index, node) in nodes.enumerated() {
            result = result + debugTextForNode(node, style: style, index: index)
        }

        return result
    }

    private func debugTextForNode(_ node: HTMLNode, style: TextStyle, index: Int) -> Text {
        switch node {
        case .text(let string):
            // Show text with a colored background marker
            let debugMarker = "[\(index)]"
            let colors: [Color] = [.yellow, .cyan, .pink, .mint, .orange, .green]
            let color = colors[index % colors.count]

            // Apply style and add visible boundary markers
            var styledText = applyStyle(Text(string), style: style)

            // Add background color effect by using foreground color blend
            if style.isBold && style.isItalic {
                styledText = Text("«").foregroundColor(.red) + styledText + Text("»").foregroundColor(.red)
            } else if style.isBold {
                styledText = Text("‹").foregroundColor(.orange) + styledText + Text("›").foregroundColor(.orange)
            } else if style.isItalic {
                styledText = Text("⟨").foregroundColor(.green) + styledText + Text("⟩").foregroundColor(.green)
            }

            return styledText

        case .formatted(let children, let nodeStyle):
            let mergedStyle = style.merging(nodeStyle)
            return buildDebugText(from: children, style: mergedStyle)

        case .link(_, let children):
            var linkStyle = style
            linkStyle.isUnderlined = true
            linkStyle.color = ColorInfo(red: 0, green: 0.478, blue: 1.0)
            return Text("[link:").foregroundColor(.blue) + buildDebugText(from: children, style: linkStyle) + Text("]").foregroundColor(.blue)

        case .span(let children, _):
            return Text("{span:").foregroundColor(.purple) + buildDebugText(from: children, style: style) + Text("}").foregroundColor(.purple)

        case .lineBreak:
            return Text("\n")

        default:
            return Text("")
        }
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

        // Apply italic BEFORE bold - in SwiftUI, applying .italic() after .fontWeight(.bold)
        // can reset the font weight. Applying bold last ensures it takes effect.
        if style.isItalic {
            result = result.italic()
        }

        // Always apply fontWeight (even .regular) to ensure proper style inheritance
        // from parent view's foregroundStyle when concatenating Text views
        result = result.fontWeight(style.isBold ? .bold : .regular)

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
