import Foundation

/// Information about a chapter in a work
public struct AO3ChapterInfo: Codable, Hashable, Sendable {
    /// The unique chapter ID
    public let id: Int

    /// The chapter number (1-indexed)
    public let number: Int

    /// The chapter title
    public let title: String

    public init(id: Int, number: Int, title: String) {
        self.id = id
        self.number = number
        self.title = title
    }
}
