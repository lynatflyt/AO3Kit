import Foundation
import SwiftSoup

/// Parses AO3 work HTML into structured data
internal struct AO3WorkParser {
    func parse(document: Document, into work: AO3Work) async throws {
        // Parse basic metadata
        work.title = try parseTitle(from: document)
        work.authors = try await parseAuthors(from: document)

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
    }

    // MARK: - Parsing Methods

    private func parseTitle(from document: Document) throws -> String {
        return try document.select("h2.title.heading").first()?.html() ?? ""
    }

    private func parseAuthors(from document: Document) async throws -> [AO3User] {
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
