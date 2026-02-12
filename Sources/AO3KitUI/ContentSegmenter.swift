import Foundation

/// Segments parsed HTML nodes into native text and web content segments
public struct ContentSegmenter {

    /// Segment an array of HTMLNodes into ContentSegments
    /// - Parameter nodes: The parsed HTML nodes
    /// - Returns: Array of ContentSegments, grouping consecutive native nodes together
    public static func segment(_ nodes: [HTMLNode]) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentNativeNodes: [HTMLNode] = []

        for node in nodes {
            if case .webContent(let rawHTML, let elementType) = node {
                // Flush any accumulated native nodes
                if !currentNativeNodes.isEmpty {
                    segments.append(.nativeText(nodes: currentNativeNodes, id: UUID()))
                    currentNativeNodes = []
                }
                // Add web content as its own segment
                segments.append(.webContent(html: rawHTML, type: elementType, id: UUID()))
            } else {
                // Check if this node contains any web content children
                if containsWebContent(node) {
                    // Need to split this node
                    let childSegments = segmentNodeWithWebContent(node)

                    // Handle the child segments
                    for childSegment in childSegments {
                        switch childSegment {
                        case .nativeText(let nodes, _):
                            currentNativeNodes.append(contentsOf: nodes)
                        case .webContent:
                            // Flush native nodes first
                            if !currentNativeNodes.isEmpty {
                                segments.append(.nativeText(nodes: currentNativeNodes, id: UUID()))
                                currentNativeNodes = []
                            }
                            segments.append(childSegment)
                        }
                    }
                } else {
                    // Pure native node
                    currentNativeNodes.append(node)
                }
            }
        }

        // Flush any remaining native nodes
        if !currentNativeNodes.isEmpty {
            segments.append(.nativeText(nodes: currentNativeNodes, id: UUID()))
        }

        return segments
    }

    /// Check if a node contains any web content in its children
    private static func containsWebContent(_ node: HTMLNode) -> Bool {
        switch node {
        case .webContent:
            return true
        case .paragraph(let children),
             .heading(_, let children),
             .blockquote(let children),
             .listItem(let children),
             .div(let children, _),
             .formatted(let children, _),
             .link(_, let children),
             .span(let children, _):
            return children.contains(where: containsWebContent)
        case .list(_, let items):
            return items.flatMap { $0 }.contains(where: containsWebContent)
        case .details(let summary, let content):
            return summary.contains(where: containsWebContent) || content.contains(where: containsWebContent)
        case .text, .lineBreak, .horizontalRule, .codeBlock, .preformatted:
            return false
        }
    }

    /// Segment a node that contains web content within it
    private static func segmentNodeWithWebContent(_ node: HTMLNode) -> [ContentSegment] {
        switch node {
        case .webContent(let rawHTML, let elementType):
            return [.webContent(html: rawHTML, type: elementType, id: UUID())]

        case .paragraph(let children):
            return segmentChildren(children, wrapNative: { .paragraph(children: $0) })

        case .heading(let level, let children):
            return segmentChildren(children, wrapNative: { .heading(level: level, children: $0) })

        case .blockquote(let children):
            return segmentChildren(children, wrapNative: { .blockquote(children: $0) })

        case .div(let children, let attributes):
            return segmentChildren(children, wrapNative: { .div(children: $0, attributes: attributes) })

        case .details(let summary, let content):
            // For details, segment the content but keep summary native
            // This is a simplification - details with web content in summary is rare
            let contentSegments = segment(content)
            if contentSegments.allSatisfy({ !$0.isWebContent }) {
                return [.nativeText(nodes: [node], id: UUID())]
            }
            // For now, treat the whole details as native if it has web content
            // A more sophisticated approach would render it via web view
            return [.nativeText(nodes: [node], id: UUID())]

        case .list(let ordered, let items):
            // Lists are complex - for now, treat as single native block
            // A list with web content in items is rare
            return [.nativeText(nodes: [node], id: UUID())]

        case .formatted(let children, let style):
            return segmentChildren(children, wrapNative: { .formatted(children: $0, style: style) })

        case .link(let url, let children):
            return segmentChildren(children, wrapNative: { .link(url: url, children: $0) })

        case .span(let children, let className):
            return segmentChildren(children, wrapNative: { .span(children: $0, className: className) })

        case .listItem(let children):
            return segmentChildren(children, wrapNative: { .listItem(children: $0) })

        case .text, .lineBreak, .horizontalRule, .codeBlock, .preformatted:
            return [.nativeText(nodes: [node], id: UUID())]
        }
    }

    /// Helper to segment children and wrap native portions in a parent node
    private static func segmentChildren(
        _ children: [HTMLNode],
        wrapNative: ([HTMLNode]) -> HTMLNode
    ) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentNativeChildren: [HTMLNode] = []

        for child in children {
            if case .webContent(let rawHTML, let elementType) = child {
                if !currentNativeChildren.isEmpty {
                    segments.append(.nativeText(nodes: [wrapNative(currentNativeChildren)], id: UUID()))
                    currentNativeChildren = []
                }
                segments.append(.webContent(html: rawHTML, type: elementType, id: UUID()))
            } else if containsWebContent(child) {
                // Recursively segment
                let childSegments = segmentNodeWithWebContent(child)
                for seg in childSegments {
                    switch seg {
                    case .nativeText(let nodes, _):
                        currentNativeChildren.append(contentsOf: nodes)
                    case .webContent:
                        if !currentNativeChildren.isEmpty {
                            segments.append(.nativeText(nodes: [wrapNative(currentNativeChildren)], id: UUID()))
                            currentNativeChildren = []
                        }
                        segments.append(seg)
                    }
                }
            } else {
                currentNativeChildren.append(child)
            }
        }

        if !currentNativeChildren.isEmpty {
            segments.append(.nativeText(nodes: [wrapNative(currentNativeChildren)], id: UUID()))
        }

        return segments
    }
}
