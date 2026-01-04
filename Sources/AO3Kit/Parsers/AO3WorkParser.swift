import Foundation
import SwiftSoup

/// Parses AO3 work HTML into structured data
internal struct AO3WorkParser {
    func parse(document: Document, into work: AO3Work) async throws {
        // Parse basic metadata
        work.title = try parseTitle(from: document)
        work.authors = try parseAuthors(from: document)

        // Parse tags and warnings
        work.archiveWarning = AO3Warning.byValue(try getArchiveTag("warning", document: document))
        work.rating = AO3Rating.byValue(try getArchiveTag("rating", document: document))
        work.category = (try? AO3Category.byValue(getArchiveTag("category", document: document))) ?? .none

        // Parse fandom and tags
        work.fandom = try getWorkTag("fandom", document: document)
        work.relationships = (try? getTagList("relationship", document: document)) ?? []
        work.characters = (try? getTagList("character", document: document)) ?? []
        work.additionalTags = (try? getTagList("freeform", document: document)) ?? []

        // Parse metadata
        work.language = try parseLanguage(from: document)
        work.stats = try parseStats(from: document)

        // Parse dates
        let (published, updated) = try parseDates(from: document)
        work.published = published
        work.updated = updated

        // Parse chapters
        work.chapters = try parseChapters(from: document, workID: work.id)

        // Parse work skin CSS if present
        work.workSkinCSS = try parseWorkSkinCSS(from: document)

        // Parse first chapter content (displayed on work page)
        let (content, html) = try parseFirstChapterContent(from: document)
        work.firstChapterContent = content
        work.firstChapterHTML = html
        work.firstChapterNotes = try parseFirstChapterNotes(from: document)
        work.firstChapterSummary = try parseFirstChapterSummary(from: document)
    }

    // MARK: - Parsing Methods

    private func parseTitle(from document: Document) throws -> String {
        return try document.select("h2.title.heading").first()?.html() ?? ""
    }

    private func parseAuthors(from document: Document) throws -> [AO3User] {
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
                        // Use lightweight initializer - no network request for author profile
                        tempAuthors.append(AO3User(username: username, pseud: pseud, lightweight: true))
                    }
                } else {
                    // Use lightweight initializer - no network request for author profile
                    tempAuthors.append(AO3User(username: authorText, pseud: authorText, lightweight: true))
                }
            }
        }
        return tempAuthors
    }

    private func parseLanguage(from document: Document) throws -> String {
        return try document.select("dd.language").first()?.html() ?? ""
    }

    private func parseStats(from document: Document) throws -> [String: String] {
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

        return tempStats
    }

    private func parseDates(from document: Document) throws -> (published: Date, updated: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var published = Date()
        var updated = Date()

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

        return (published, updated)
    }

    private func parseChapters(from document: Document, workID: Int) throws -> [AO3ChapterInfo] {
        var tempChapters: [AO3ChapterInfo] = []

        if let chapterSelect = try? document.select("#selected_id").first() {
            let options = try chapterSelect.select("option")
            for (index, option) in options.enumerated() {
                if let chapterID = Int(try option.attr("value")) {
                    var chapterTitle = try option.html()
                    // Chapter number is 1-indexed (first option is chapter 1)
                    let chapterNumber = index + 1

                    // Remove the "1. " "2. " etc. prefix from chapter titles
                    // since we already track the chapter number separately
                    if let range = chapterTitle.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                        chapterTitle.removeSubrange(range)
                    }

                    tempChapters.append(AO3ChapterInfo(
                        id: chapterID,
                        number: chapterNumber,
                        title: chapterTitle
                    ))
                }
            }
        } else {
            // Single-chapter work (no dropdown)
            tempChapters.append(AO3ChapterInfo(
                id: workID,
                number: 1,
                title: try parseTitle(from: document)
            ))
        }

        return tempChapters
    }

    private func parseWorkSkinCSS(from document: Document) throws -> String? {
        if let styleTag = try document.select("style").first(where: { element in
            (try? element.html().contains("#workskin")) ?? false
        }) {
            return try styleTag.html()
        }
        return nil
    }

    private func parseFirstChapterContent(from document: Document) throws -> (content: String?, html: String?) {
        // The first chapter content is displayed on the work page in the [role=article] element
        guard let article = try document.select("[role=article]").first() else {
            return (nil, nil)
        }

        let paragraphs = try article.select("p")
        let contentArray = try paragraphs.map { try $0.text() }
        let htmlArray = try paragraphs.map { try $0.outerHtml() }

        let content = contentArray.joined(separator: "\n")
        let html = htmlArray.joined(separator: "\n")

        // Only return if we actually have content
        guard !content.isEmpty else {
            return (nil, nil)
        }

        return (content, html)
    }

    private func parseFirstChapterNotes(from document: Document) throws -> [String] {
        var tempNotes: [String] = []
        let notesModules = try document.select("div.notes.module")

        for noteModule in notesModules {
            if let userstuff = try noteModule.select(".userstuff").first() {
                let paragraphs = try userstuff.select("p")
                let noteText = try paragraphs.map { try $0.text() }.joined(separator: "\n")
                if !noteText.isEmpty {
                    tempNotes.append(noteText)
                }
            }
        }

        return tempNotes
    }

    private func parseFirstChapterSummary(from document: Document) throws -> String {
        if let summaryDiv = try document.select("div.summary.module").first(),
           let blockquote = try summaryDiv.select("blockquote.userstuff").first() {
            let paragraphs = try blockquote.select("p")
            let summaryArray = try paragraphs.map { try $0.html() }
            return summaryArray.joined(separator: "\n")
        }
        return ""
    }

    // MARK: - Tag Helpers

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
}
