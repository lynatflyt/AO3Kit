import Foundation

/// A segment of chapter content, either native text or web content
public enum ContentSegment: Sendable, Identifiable {
    case nativeText(nodes: [HTMLNode], id: UUID)
    case webContent(html: String, type: WebContentType, id: UUID)

    public var id: UUID {
        switch self {
        case .nativeText(_, let id):
            return id
        case .webContent(_, _, let id):
            return id
        }
    }

    /// Whether this segment contains web content
    public var isWebContent: Bool {
        switch self {
        case .nativeText:
            return false
        case .webContent:
            return true
        }
    }
}
