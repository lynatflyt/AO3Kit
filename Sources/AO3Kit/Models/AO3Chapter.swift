import Foundation

/// Object exposing information about a chapter. Contains the title, the content itself and author notes.
public class AO3Chapter: AO3Data, @unchecked Sendable {
    public let workID: Int
    public let id: Int
    public internal(set) var number: Int = 1
    public internal(set) var title: String = ""
    public internal(set) var content: String = ""
    public internal(set) var contentHTML: String = ""
    public internal(set) var notes: [String] = []
    public internal(set) var summary: String = ""

    /// Work metadata parsed from the chapter page header (for cache refresh)
    /// This is populated when fetching a chapter and can be used to refresh the work cache
    public internal(set) var parsedWork: AO3Work?

    internal init(workID: Int, chapterID: Int) async throws {
        self.workID = workID
        self.id = chapterID
        super.init()
        try await loadChapterData()
    }

    /// Public initializer for creating a chapter from pre-parsed work page data
    /// This is useful for caching first chapter content parsed from the work page
    public init(
        workID: Int,
        chapterID: Int,
        number: Int,
        title: String,
        content: String,
        contentHTML: String,
        notes: [String],
        summary: String
    ) {
        self.workID = workID
        self.id = chapterID
        self.number = number
        self.title = title
        self.content = content
        self.contentHTML = contentHTML
        self.notes = notes
        self.summary = summary
        super.init()
    }

    private enum CodingKeys: String, CodingKey {
        case workID, id, number, title, content, contentHTML, notes, summary
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workID = try container.decode(Int.self, forKey: .workID)
        id = try container.decode(Int.self, forKey: .id)
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? 1
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        contentHTML = try container.decodeIfPresent(String.self, forKey: .contentHTML) ?? ""
        notes = try container.decode([String].self, forKey: .notes)
        summary = try container.decode(String.self, forKey: .summary)
        super.init()
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workID, forKey: .workID)
        try container.encode(id, forKey: .id)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(contentHTML, forKey: .contentHTML)
        try container.encode(notes, forKey: .notes)
        try container.encode(summary, forKey: .summary)
    }

    private func loadChapterData() async throws {
        let document = try await getDocument()

        // Parse chapter content
        let parser = AO3ChapterParser()
        try parser.parse(document: document, into: self)

        // Also parse work metadata from the same page (header is always present)
        // This allows us to refresh the work cache without extra requests
        do {
            let work = try await AO3Work(id: workID, document: document)
            self.parsedWork = work
        } catch {
            // If work parsing fails, we still have the chapter - just skip work refresh
            self.parsedWork = nil
        }
    }

    internal override func buildURL() -> String {
        return "https://archiveofourown.org/works/\(workID)/chapters/\(id)"
    }

    /// Converts the chapter's HTML content to an AttributedString with formatting preserved
    /// - Returns: AttributedString with bold, italic, and custom color formatting from AO3
    /// - Note: Custom color classes from AO3 (like span.FakeIDCallie) are preserved as foregroundColor attributes
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func getAttributedContent() throws -> AttributedString {
        return try AO3ChapterAttributedStringConverter.convert(contentHTML)
    }
}
