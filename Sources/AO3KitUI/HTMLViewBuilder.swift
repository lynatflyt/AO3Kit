import SwiftUI
import UIKit // Added unconditionally

/// Converts HTMLNode tree to SwiftUI views
struct HTMLViewBuilder {

    /// Build SwiftUI views from parsed HTML nodes
    static func buildViews(
        from nodes: [HTMLNode],
        context: RenderContext = RenderContext(),
        textSelectionEnabled: Bool = false,
        textAlignment: TextAlignment = .leading
    ) -> [AnyView] {
        // Group consecutive inline nodes together, but split on line breaks for proper spacing
        var result: [AnyView] = []
        var inlineBuffer: [HTMLNode] = []

        func flushInlineBuffer() {
            if !inlineBuffer.isEmpty {
                result.append(AnyView(
                    buildTextView(
                        nodes: inlineBuffer,
                        baseStyle: context.currentStyle,
                        context: context,
                        textSelectionEnabled: textSelectionEnabled,
                        textAlignment: textAlignment
                    )
                ))
                inlineBuffer.removeAll()
            }
        }

        for node in nodes {
            if node.isBlock {
                // Flush any buffered inline nodes first
                flushInlineBuffer()
                // Add the block node
                result.append(AnyView(buildView(from: node, context: context, textSelectionEnabled: textSelectionEnabled, textAlignment: textAlignment)))
            } else {
                // Buffer inline nodes
                inlineBuffer.append(node)
            }
        }

        // Flush any remaining inline nodes
        flushInlineBuffer()

        return result
    }

    /// Build the appropriate text view based on alignment
    /// Uses JustifiedFormattedText for justified alignment (UITextView-based),
    /// FormattedText for other alignments (SwiftUI Text-based)
    @ViewBuilder
    private static func buildTextView(
        nodes: [HTMLNode],
        baseStyle: TextStyle,
        context: RenderContext,
        textSelectionEnabled: Bool,
        textAlignment: TextAlignment
    ) -> some View {
        if textAlignment == .justified {
            JustifiedFormattedText(
                nodes: nodes,
                baseStyle: baseStyle,
                fontSize: context.fontSize,
                fontDesign: context.fontDesign,
                textColor: context.textColor,
                backgroundColor: context.backgroundColor,
                textSelectionEnabled: textSelectionEnabled,
                alignment: textAlignment
            )
        } else {
            FormattedText(
                nodes: nodes,
                baseStyle: baseStyle,
                textSelectionEnabled: textSelectionEnabled
            )
            .multilineTextAlignment(swiftUITextAlignment(from: textAlignment))
        }
    }

    /// Build a single view from a node (returns AnyView to avoid @ViewBuilder complexity)
    private static func buildView(
        from node: HTMLNode,
        context: RenderContext,
        textSelectionEnabled: Bool,
        textAlignment: TextAlignment
    ) -> AnyView {
        switch node {
        // Block elements
        case .paragraph(let children):
            return AnyView(
                buildTextView(
                    nodes: children,
                    baseStyle: context.currentStyle,
                    context: context,
                    textSelectionEnabled: textSelectionEnabled,
                    textAlignment: textAlignment
                )
                .padding(.bottom, 8)
            )

        case .heading(let level, let children):
            // Use relative font size multipliers instead of fixed font styles
            // Headings always use regular FormattedText (not justified)
            let sizeMultiplier = fontSizeForHeading(level)
            return AnyView(
                FormattedText(nodes: children, baseStyle: context.currentStyle, textSelectionEnabled: textSelectionEnabled)
                    .font(.system(size: 17 * sizeMultiplier, weight: .bold))
                    .padding(.bottom, level <= 2 ? 12 : 8)
                    .padding(.top, level <= 2 ? 8 : 4)
            )

        case .blockquote(let children):
            return AnyView(HTMLBlockquote(children: children, context: context, textSelectionEnabled: textSelectionEnabled, textAlignment: textAlignment))

        case .codeBlock(let code, let language):
            return AnyView(HTMLCodeBlock(code: code, language: language, textSelectionEnabled: textSelectionEnabled))

        case .preformatted(let text):
            let textView = Text(text)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.vertical, 4)
            if textSelectionEnabled {
                return AnyView(textView.textSelection(.enabled))
            }
            return AnyView(textView)

        case .horizontalRule:
            return AnyView(
                Divider()
                    .padding(.vertical, 8)
            )

        case .list(let ordered, let items):
            return AnyView(HTMLList(ordered: ordered, items: items, depth: context.listDepth, textSelectionEnabled: textSelectionEnabled, textAlignment: textAlignment))

        case .div(let children, let attributes):
            return AnyView(buildDivView(children: children, attributes: attributes, context: context, textSelectionEnabled: textSelectionEnabled, textAlignment: textAlignment))

        case .details(let summary, let content):
            return AnyView(HTMLDetails(summary: summary, content: content, textSelectionEnabled: textSelectionEnabled, textAlignment: textAlignment))

        // Inline elements shouldn't appear at top level
        case .text, .formatted, .link, .lineBreak, .span, .listItem:
            return AnyView(
                buildTextView(
                    nodes: [node],
                    baseStyle: context.currentStyle,
                    context: context,
                    textSelectionEnabled: textSelectionEnabled,
                    textAlignment: textAlignment
                )
            )
        }
    }

    private static func buildDivView(children: [HTMLNode], attributes: [String: String], context: RenderContext, textSelectionEnabled: Bool, textAlignment: TextAlignment) -> some View {
        let alignment = htmlAlignment(from: attributes["align"])

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                buildView(from: child, context: context, textSelectionEnabled: textSelectionEnabled, textAlignment: textAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: swiftUIAlignment(from: alignment))
    }

    // MARK: - Helpers

    private static func fontSizeForHeading(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 2.0    // ~34pt at base 17pt
        case 2: return 1.65   // ~28pt
        case 3: return 1.35   // ~22pt
        case 4: return 1.18   // ~20pt
        case 5: return 1.06   // ~18pt
        case 6: return 0.94   // ~16pt
        default: return 1.0
        }
    }

    private static func htmlAlignment(from string: String?) -> TextAlignment {
        guard let string = string else { return .leading }
        switch string.lowercased() {
        case "center": return .center
        case "right": return .trailing
        case "left": return .leading
        default: return .leading
        }
    }

    private static func swiftUIAlignment(from alignment: TextAlignment) -> Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        case .leading, .justified: return .leading
        }
    }

    private static func swiftUITextAlignment(from alignment: TextAlignment) -> SwiftUI.TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        case .justified: return .leading // Fallback, shouldn't reach here
        }
    }
}
