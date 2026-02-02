import Foundation
import SwiftSoup

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
    public internal(set) var language: String
    
    /// Whether the current user has left kudos on this work
    public var userHasLeftKudos: Bool = false
    
    /// The authenticity token required to leave kudos (if available)
    public var kudosAuthenticityToken: String?
    
    public internal(set) var stats: [String: String] = [:]
    public internal(set) var published: Date = Date()
    public internal(set) var updated: Date = Date()
    public internal(set) var chapters: [AO3ChapterInfo] = []
    public internal(set) var workSkinCSS: String? = nil
    
    // Internal-only: First chapter content parsed from work page (used for caching)
    public internal(set) var firstChapterContent: String?
    public internal(set) var firstChapterHTML: String?
    public internal(set) var firstChapterNotes: [String] = []
    public internal(set) var firstChapterSummary: String = ""
    
    // Static formatter for date parsing in init
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    public init(id: Int, title: String, authors: [AO3User], summary: String, rating: AO3Rating, warnings: [AO3Warning], categories: [AO3Category], fandoms: [String], relationships: [String], characters: [String], freeforms: [String], series: [String], status: String, publishedDate: String, updatedDate: String, words: Int, chapters: Int, chapterCount: Int, comments: Int, kudos: Int, bookmarks: Int, hits: Int, language: String) {
        self.id = id
        self.title = title
        self.authors = authors
        self.archiveWarning = warnings.first ?? .none
        self.rating = rating
        self.category = categories.first ?? .none
        self.fandom = fandoms.first ?? ""
        self.relationships = relationships
        self.characters = characters
        self.additionalTags = freeforms
        self.language = language
        self.stats = [
            "words": String(words),
            "chapters": "\(chapters)/\(chapterCount)",
            "comments": String(comments),
            "kudos": String(kudos),
            "bookmarks": String(bookmarks),
            "hits": String(hits)
        ]
        self.published = AO3Work.dateFormatter.date(from: publishedDate) ?? Date()
        self.updated = AO3Work.dateFormatter.date(from: updatedDate) ?? self.published
        super.init()
    }
    
    internal init(id: Int) async throws {
        self.id = id
        // Default language to English if not set yet (will be overwritten by loadWorkData)
        self.language = "English"
        super.init()
        errorMappings[404] = "Cannot find work with specified ID"
        try await loadWorkData()
    }
    
    /// Internal initializer for creating a work from a pre-fetched document (e.g., from chapter page)
    internal init(id: Int, document: Document) async throws {
        self.id = id
        self.language = "English" // Default
        super.init()
        let parser = AO3WorkParser()
        try await parser.parse(document: document, into: self)
    }
    
    /// Internal initializer for creating a work from a search result blurb (no network fetch)
    internal init(id: Int, blurb: Element) throws {
        self.id = id
        self.language = "English" // Default
        super.init()
        let parser = AO3SearchResultParser()
        try parser.parseBlurb(blurb, into: self)
    }

    /// Create an AO3Work from an AO3WorkBlurb
    /// Useful for converting type-safe blurb data into the full work model
    public convenience init(from blurb: AO3WorkBlurb) {
        self.init(
            id: blurb.id,
            title: blurb.title,
            authors: blurb.authors,
            summary: blurb.summary,
            rating: blurb.rating,
            warnings: [blurb.archiveWarning],
            categories: [blurb.category],
            fandoms: [blurb.fandom],
            relationships: blurb.relationships,
            characters: blurb.characters,
            freeforms: blurb.additionalTags,
            series: [],
            status: blurb.stats.isComplete ? "Complete" : "In Progress",
            publishedDate: AO3Work.dateFormatter.string(from: blurb.published),
            updatedDate: AO3Work.dateFormatter.string(from: blurb.updated),
            words: blurb.stats.words,
            chapters: blurb.stats.currentChapterCount,
            chapterCount: blurb.stats.totalChapterCount ?? 0,
            comments: blurb.stats.comments ?? 0,
            kudos: blurb.stats.kudos ?? 0,
            bookmarks: blurb.stats.bookmarks ?? 0,
            hits: blurb.stats.hits ?? 0,
            language: blurb.language
        )
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, title, authors, archiveWarning, rating, category, fandom
        case relationships, characters, additionalTags, language, stats
        case published, updated, chapters, workSkinCSS
        case firstChapterContent, firstChapterHTML, firstChapterNotes, firstChapterSummary
        case userHasLeftKudos, kudosAuthenticityToken
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
        firstChapterContent = try container.decodeIfPresent(String.self, forKey: .firstChapterContent)
        firstChapterHTML = try container.decodeIfPresent(String.self, forKey: .firstChapterHTML)
        firstChapterNotes = try container.decodeIfPresent([String].self, forKey: .firstChapterNotes) ?? []
        firstChapterSummary = try container.decodeIfPresent(String.self, forKey: .firstChapterSummary) ?? ""
        userHasLeftKudos = try container.decodeIfPresent(Bool.self, forKey: .userHasLeftKudos) ?? false
        kudosAuthenticityToken = try container.decodeIfPresent(String.self, forKey: .kudosAuthenticityToken)
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
        try container.encodeIfPresent(firstChapterContent, forKey: .firstChapterContent)
        try container.encodeIfPresent(firstChapterHTML, forKey: .firstChapterHTML)
        try container.encode(firstChapterNotes, forKey: .firstChapterNotes)
        try container.encode(firstChapterSummary, forKey: .firstChapterSummary)
        try container.encode(userHasLeftKudos, forKey: .userHasLeftKudos)
        try container.encodeIfPresent(kudosAuthenticityToken, forKey: .kudosAuthenticityToken)
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