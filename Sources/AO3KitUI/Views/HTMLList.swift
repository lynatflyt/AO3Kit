import SwiftUI

/// Renders ordered or unordered lists with proper indentation
struct HTMLList: View {
    let ordered: Bool
    let items: [[HTMLNode]]
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    // Bullet or number
                    Text(marker(for: index))
                        .font(.body)
                        .frame(width: 20, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(item.enumerated()), id: \.offset) { _, node in
                            renderNode(node, itemIndex: index)
                        }
                    }
                }
                .padding(.leading, CGFloat(depth * 20))
            }
        }
        .padding(.vertical, 4)
    }

    private func marker(for index: Int) -> String {
        if ordered {
            return "\(index + 1)."
        } else {
            switch depth % 3 {
            case 0: return "•"
            case 1: return "◦"
            default: return "▪"
            }
        }
    }

    @ViewBuilder
    private func renderNode(_ node: HTMLNode, itemIndex: Int) -> some View {
        switch node {
        case .list(let nestedOrdered, let nestedItems):
            HTMLList(ordered: nestedOrdered, items: nestedItems, depth: depth + 1)
        case .paragraph(let children):
            FormattedText(nodes: children, baseStyle: TextStyle())
        default:
            FormattedText(nodes: [node], baseStyle: TextStyle())
        }
    }
}
