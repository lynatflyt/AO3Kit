import SwiftUI

/// Renders a collapsible details/summary element
struct HTMLDetails: View {
    let summary: [HTMLNode]
    let content: [HTMLNode]

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    FormattedText(nodes: summary, baseStyle: TextStyle())
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(content.enumerated()), id: \.offset) { _, node in
                        renderContent(node)
                    }
                }
                .padding(.leading, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    @ViewBuilder
    private func renderContent(_ node: HTMLNode) -> some View {
        switch node {
        case .paragraph(let children):
            FormattedText(nodes: children, baseStyle: TextStyle())
        default:
            FormattedText(nodes: [node], baseStyle: TextStyle())
        }
    }
}
