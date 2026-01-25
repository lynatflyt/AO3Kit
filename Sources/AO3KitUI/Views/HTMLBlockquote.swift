import SwiftUI

/// Renders a blockquote with left border and padding
struct HTMLBlockquote: View {
    let children: [HTMLNode]
    let context: RenderContext
    var textSelectionEnabled: Bool = false
    var textAlignment: TextAlignment = .leading

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    renderChild(child)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func renderChild(_ node: HTMLNode) -> some View {
        switch node {
        case .paragraph(let children):
            FormattedText(nodes: children, baseStyle: context.currentStyle, textSelectionEnabled: textSelectionEnabled)
        default:
            FormattedText(nodes: [node], baseStyle: context.currentStyle, textSelectionEnabled: textSelectionEnabled)
        }
    }
}
