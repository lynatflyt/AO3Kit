import Foundation

/// Object representing a work on AO3. Contains statistics, metadata and chapter information.
public class AO3Work: AO3Data, @unchecked Sendable {
    public let id: Int
    public internal(set) var title: String = ""
    public internal(set) var authors: [AO3User] = []
    public internal(set) var archiveWarning: AO3Warning = .none
    public internal(set) var rating: AO3Rating = .notRated
    public internal(set) var category: AO3Category = .none
    public internal(set) var fandom: String = ""
    public internal(set) var relationships: [String] = []
    public internal(set) var characters: [String] = []
    public internal(set) var additionalTags: [String] = []
    public internal(set) var language: String = ""
    public internal(set) var stats: [String: String] = [:]
    public internal(set) var published: Date = Date()
    public internal(set) var updated: Date = Date()
    public internal(set) var chapters: [AO3ChapterInfo] = []
    public internal(set) var workSkinCSS: String? = nil

    internal init(id: Int) async throws {
        self.id = id
        super.init()
        errorMappings[404] = "Cannot find work with specified ID"
        try await loadWorkData()
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, authors, archiveWarning, rating, category, fandom
        case relationships, characters, additionalTags, language, stats
        case published, updated, chapters, workSkinCSS
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        authors = try container.decode([AO3User].self, forKey: .authors)
        archiveWarning = try container.decode(AO3Warning.self, forKey: .archiveWarning)
        rating = try container.decode(AO3Rating.self, forKey: .rating)
        category = try container.decode(AO3Category.self, forKey: .category)
        fandom = try container.decode(String.self, forKey: .fandom)
        relationships = try container.decode([String].self, forKey: .relationships)
        characters = try container.decode([String].self, forKey: .characters)
        additionalTags = try container.decode([String].self, forKey: .additionalTags)
        language = try container.decode(String.self, forKey: .language)
        stats = try container.decode([String: String].self, forKey: .stats)
        published = try container.decode(Date.self, forKey: .published)
        updated = try container.decode(Date.self, forKey: .updated)
        chapters = try container.decode([AO3ChapterInfo].self, forKey: .chapters)
        workSkinCSS = try container.decodeIfPresent(String.self, forKey: .workSkinCSS)
        super.init()
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(authors, forKey: .authors)
        try container.encode(archiveWarning, forKey: .archiveWarning)
        try container.encode(rating, forKey: .rating)
        try container.encode(category, forKey: .category)
        try container.encode(fandom, forKey: .fandom)
        try container.encode(relationships, forKey: .relationships)
        try container.encode(characters, forKey: .characters)
        try container.encode(additionalTags, forKey: .additionalTags)
        try container.encode(language, forKey: .language)
        try container.encode(stats, forKey: .stats)
        try container.encode(published, forKey: .published)
        try container.encode(updated, forKey: .updated)
        try container.encode(chapters, forKey: .chapters)
        try container.encodeIfPresent(workSkinCSS, forKey: .workSkinCSS)
    }

    private func loadWorkData() async throws {
        let document = try await getDocument()
        let parser = AO3WorkParser()
        try await parser.parse(document: document, into: self)
    }

    internal override func buildURL() -> String {
        return "https://archiveofourown.org/works/\(id)"
    }

    /// Returns an AO3Chapter based on a chapter ID
    /// - Parameter chapterID: The chapter ID
    /// - Returns: AO3Chapter object
    /// - Throws: AO3Exception if chapter not found
    public func getChapter(_ chapterID: Int) async throws -> AO3Chapter {
        guard chapters.contains(where: { $0.id == chapterID }) else {
            throw AO3Exception.chapterNotFound(chapterID)
        }
        return try await AO3.getChapter(workID: id, chapterID: chapterID)
    }

    /// Returns an AO3Chapter based on chapter number (1-indexed)
    /// - Parameter number: The chapter number (1 for first chapter, 2 for second, etc.)
    /// - Returns: AO3Chapter object
    /// - Throws: AO3Exception if chapter not found
    public func getChapter(number: Int) async throws -> AO3Chapter {
        guard let chapterInfo = chapters.first(where: { $0.number == number }) else {
            throw AO3Exception.chapterNotFound(-1)
        }
        return try await AO3.getChapter(workID: id, chapterID: chapterInfo.id)
    }
}
