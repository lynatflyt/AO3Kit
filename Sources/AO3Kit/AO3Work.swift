import Foundation
import SwiftSoup

/// Object representing a work on AO3. Contains statistics, metadata and chapter information.
public class AO3Work: AO3Data, @unchecked Sendable {
    public let id: Int
    public private(set) var title: String = ""
    public private(set) var authors: [AO3User] = []
    public private(set) var archiveWarning: AO3Warning = .none
    public private(set) var rating: AO3Rating = .notRated
    public private(set) var category: AO3Category = .none
    public private(set) var fandom: String = ""
    public private(set) var relationships: [String] = []
    public private(set) var characters: [String] = []
    public private(set) var additionalTags: [String] = []
    public private(set) var language: String = ""
    public private(set) var stats: [String: String] = [:]
    public private(set) var published: Date = Date()
    public private(set) var updated: Date = Date()
    public private(set) var chapters: [Int: String] = [:]

    internal init(id: Int) async throws {
        self.id = id
        super.init()
        errorMappings[404] = "Cannot find work with specified ID"
        try await loadWorkData()
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, authors, archiveWarning, rating, category, fandom
        case relationships, characters, additionalTags, language, stats
        case published, updated, chapters
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
        chapters = try container.decode([Int: String].self, forKey: .chapters)
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
    }

    private func loadWorkData() async throws {
        let document = try await getDocument()

        // Parse title
        title = try document.select("h2.title.heading").first()?.html() ?? ""

        // Parse authors
        let pseudRegex = try NSRegularExpression(pattern: "\\((.*?)\\)", options: [])
        var tempAuthors: [AO3User] = []

        if let byline = try document.select("h3.byline.heading").first() {
            let authorLinks = try byline.select("a")
            for link in authorLinks {
                let authorText = try link.html()
                let range = NSRange(authorText.startIndex..., in: authorText)

                if let match = pseudRegex.firstMatch(in: authorText, range: range) {
                    if let usernameRange = Range(match.range(at: 1), in: authorText) {
                        let username = String(authorText[usernameRange])
                        let pseud = authorText.components(separatedBy: " ")[0].trimmingCharacters(in: .whitespaces)
                        tempAuthors.append(try await AO3User(username: username, pseud: pseud))
                    }
                } else {
                    tempAuthors.append(try await AO3User(username: authorText, pseud: authorText))
                }
            }
        }
        authors = tempAuthors

        // Parse warnings, ratings, categories
        archiveWarning = AO3Warning.byValue(try getArchiveTag("warning", document: document))
        rating = AO3Rating.byValue(try getArchiveTag("rating", document: document))
        category = (try? AO3Category.byValue(getArchiveTag("category", document: document))) ?? .none

        // Parse fandom
        fandom = try getWorkTag("fandom", document: document)

        // Parse relationships
        relationships = (try? getTagList("relationship", document: document)) ?? []

        // Parse characters
        characters = (try? getTagList("character", document: document)) ?? []

        // Parse additional tags
        additionalTags = (try? getTagList("freeform", document: document)) ?? []

        // Parse language
        language = try document.select("dd.language").first()?.html() ?? ""

        // Parse stats
        var tempStats: [String: String] = [:]
        if let statsElement = try document.select("dl.stats").first() {
            let ddElements = try statsElement.select("dd")
            for dd in ddElements {
                let className = try dd.className()
                if className != "bookmarks" && className != "status" && className != "published" {
                    tempStats[className] = try dd.html()
                }
            }
        }

        // Parse bookmarks separately
        if let bookmarksElement = try document.select("dd.bookmarks").first(),
           let bookmarksLink = try bookmarksElement.select("a").first() {
            tempStats["bookmarks"] = try bookmarksLink.html()
        } else {
            tempStats["bookmarks"] = "0"
        }
        stats = tempStats

        // Parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if let publishedElement = try document.select("dl.stats").first()?.select(".published").dropFirst().first {
            let publishedText = try publishedElement.html()
            published = dateFormatter.date(from: publishedText) ?? Date()
        }

        if let statusElement = try document.select("dl.stats").first()?.select(".status").dropFirst().first {
            let statusText = try statusElement.html()
            updated = dateFormatter.date(from: statusText) ?? published
        } else {
            updated = published
        }

        // Parse chapters
        var tempChapters: [Int: String] = [:]
        if let chapterSelect = try? document.select("#selected_id").first() {
            let options = try chapterSelect.select("option")
            for option in options {
                if let chapterID = Int(try option.attr("value")) {
                    let chapterTitle = try option.html()
                    tempChapters[chapterID] = chapterTitle
                }
            }
        } else {
            tempChapters[id] = title
        }
        chapters = tempChapters
    }

    internal override func buildURL() -> String {
        return "https://archiveofourown.org/works/\(id)"
    }

    private func getArchiveTag(_ css: String, document: Document) throws -> String {
        guard let element = try document.select("dd.\(css).tags").first(),
              let ul = try element.select("ul").first(),
              let li = try ul.select("li").first(),
              let tag = try li.select("a.tag").first() else {
            return ""
        }
        return try tag.html()
    }

    private func getWorkTag(_ css: String, document: Document) throws -> String {
        guard let element = try document.select("dd.\(css).tags").first(),
              let ul = try element.select("ul").first(),
              let li = try ul.select("li").first(),
              let tag = try li.select("a.tag").first() else {
            return ""
        }
        return try tag.html()
    }

    private func getTagList(_ css: String, document: Document) throws -> [String] {
        guard let element = try document.select("dd.\(css).tags").first(),
              let ul = try element.select("ul").first() else {
            return []
        }
        let items = try ul.select("li")
        return try items.compactMap { try $0.select("a.tag").first()?.html() }
    }

    /// Returns an AO3Chapter based on a chapter ID
    /// - Parameter chapterID: The chapter ID
    /// - Returns: AO3Chapter object
    /// - Throws: AO3Exception if chapter not found
    public func getChapter(_ chapterID: Int) async throws -> AO3Chapter {
        guard chapters.keys.contains(chapterID) else {
            throw AO3Exception.chapterNotFound(chapterID)
        }
        return try await AO3.getChapter(workID: id, chapterID: chapterID)
    }
}
