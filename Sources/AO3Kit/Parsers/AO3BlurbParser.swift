//
//  AO3BlurbParser.swift
//  AO3Kit
//
//  Reusable parser for work blurb data across different contexts
//

import Foundation
import SwiftSoup

/// Bookmark-specific metadata parsed from a bookmark blurb
internal struct BookmarkMetadata {
    let notes: String?
    let tags: [String]
    let date: Date?
    let isPrivate: Bool
    let isRec: Bool
}

/// Parses work blurb data from HTML elements
/// This is the core parser used by AO3SearchResultParser and AO3BookmarkParser
internal struct AO3BlurbParser {
    // Static date formatter to avoid expensive re-initialization
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    /// Parse base blurb data common to all contexts
    /// - Parameters:
    ///   - element: The blurb HTML element
    ///   - workID: The work ID (already extracted by the caller)
    /// - Returns: An AO3WorkBlurb with parsed data
    func parseBlurb(_ element: Element, workID: Int) throws -> AO3WorkBlurb {
        let title = try parseTitle(from: element)
        let authors = try parseAuthors(from: element)
        let fandom = try parseFandom(from: element)
        let (rating, warning, category) = parseRequiredTags(from: element)
        let relationships = try parseRelationships(from: element)
        let characters = try parseCharacters(from: element)
        let additionalTags = try parseAdditionalTags(from: element)
        let language = try parseLanguage(from: element)
        let summary = try parseSummary(from: element)
        let stats = parseStats(from: element)
        let published = parsePublishedDate(from: element)
        let updated = parseWorkUpdateDate(from: element, fallback: published)

        return AO3WorkBlurb(
            id: workID,
            title: title,
            authors: authors,
            fandom: fandom,
            rating: rating,
            archiveWarning: warning,
            category: category,
            relationships: relationships,
            characters: characters,
            additionalTags: additionalTags,
            language: language,
            stats: stats,
            published: published,
            updated: updated,
            summary: summary
        )
    }

    /// Parse history-specific data (last visited date)
    /// - Parameter element: The blurb HTML element
    /// - Returns: The last visited date, or nil if not present
    func parseHistoryDate(_ element: Element) -> Date? {
        do {
            if let viewedHeading = (try element.select("h4.viewed.heading")).first(),
               let dateTextRange = try viewedHeading.text().range(of: "Last visited: ") {
                let dateString = try String(viewedHeading.text()[dateTextRange.upperBound...])
                    .prefix(11) // "dd MMM yyyy" is 11 chars
                return Self.dateFormatter.date(from: String(dateString))
            }
        } catch {
            // lastVisitedDate is optional
        }
        return nil
    }

    /// Parse bookmark-specific data
    /// - Parameter element: The bookmark blurb HTML element
    /// - Returns: Bookmark metadata
    func parseBookmarkData(_ element: Element) -> BookmarkMetadata {
        var notes: String? = nil
        var tags: [String] = []
        var date: Date? = nil
        var isPrivate = false
        var isRec = false

        do {
            // Bookmark notes
            if let notesElement = try element.select("blockquote.userstuff.notes").first() {
                notes = try notesElement.text()
            }

            // Bookmark tags
            let tagElements = try element.select("ul.meta.tags.commas li a.tag")
            tags = try tagElements.array().map { try $0.text() }

            // Bookmark date
            if let dateElement = try element.select("p.datetime").array().last {
                let dateText = try dateElement.text()
                date = Self.dateFormatter.date(from: dateText)
            }

            // Private/Rec status from bookmark meta
            let metaText = try element.select("p.status").text().lowercased()
            isPrivate = metaText.contains("private")
            isRec = metaText.contains("rec")

        } catch {
            // Use defaults
        }

        return BookmarkMetadata(
            notes: notes,
            tags: tags,
            date: date,
            isPrivate: isPrivate,
            isRec: isRec
        )
    }

    // MARK: - Private Parsing Helpers

    private func parseTitle(from blurb: Element) throws -> String {
        if let titleLink = try blurb.select("h4.heading a").first() {
            let href = try titleLink.attr("href")
            if href.contains("/works/") {
                return try titleLink.text()
            }
        }
        return ""
    }

    private func parseAuthors(from blurb: Element) throws -> [AO3User] {
        let authorLinks = try blurb.select("h4.heading a[rel=author]")
        var parsedAuthors: [AO3User] = []

        for link in authorLinks {
            let authorText = try link.text()
            // Check for pseud format: "name (username)"
            if let parenStart = authorText.firstIndex(of: "("),
               let parenEnd = authorText.firstIndex(of: ")") {
                let pseud = String(authorText[..<parenStart]).trimmingCharacters(in: .whitespaces)
                let username = String(authorText[authorText.index(after: parenStart)..<parenEnd])
                parsedAuthors.append(AO3User(username: username, pseud: pseud, lightweight: true))
            } else {
                parsedAuthors.append(AO3User(username: authorText, pseud: authorText, lightweight: true))
            }
        }
        return parsedAuthors
    }

    private func parseFandom(from blurb: Element) throws -> String {
        if let fandomTag = try blurb.select("h5.fandoms a.tag").first() {
            return try fandomTag.text()
        }
        return ""
    }

    private func parseRequiredTags(from blurb: Element) -> (AO3Rating, AO3Warning, AO3Category) {
        var rating: AO3Rating = .notRated
        var warning: AO3Warning = .none
        var category: AO3Category = .none

        do {
            // Rating
            if let ratingSpan = try blurb.select("span.rating").first() {
                let ratingText = try ratingSpan.text()
                rating = AO3Rating.byValue(ratingText)
            } else if let ratingSpan = try blurb.select("ul.required-tags li").first()?.select("span").first() {
                let ratingText = try ratingSpan.attr("title")
                rating = AO3Rating.byValue(ratingText)
            }

            // Warnings
            if let warningSpan = try blurb.select("span.warnings").first() {
                let warningText = try warningSpan.text()
                warning = AO3Warning.byValue(warningText)
            } else if let warningLi = try blurb.select("ul.required-tags li").array().dropFirst().first {
                let warningText = try warningLi.select("span").first()?.attr("title") ?? ""
                warning = AO3Warning.byValue(warningText)
            }

            // Category
            if let categorySpan = try blurb.select("span.category").first() {
                let categoryText = try categorySpan.text()
                category = (try? AO3Category.byValue(categoryText)) ?? .none
            } else if let categoryLi = try blurb.select("ul.required-tags li").array().dropFirst(2).first {
                let categoryText = try categoryLi.select("span").first()?.attr("title") ?? ""
                category = (try? AO3Category.byValue(categoryText)) ?? .none
            }
        } catch {
            // Use defaults
        }

        return (rating, warning, category)
    }

    private func parseRelationships(from blurb: Element) throws -> [String] {
        let relationshipTags = try blurb.select("li.relationships a.tag")
        return try relationshipTags.array().map { try $0.text() }
    }

    private func parseCharacters(from blurb: Element) throws -> [String] {
        let characterTags = try blurb.select("li.characters a.tag")
        return try characterTags.array().map { try $0.text() }
    }

    private func parseAdditionalTags(from blurb: Element) throws -> [String] {
        let freeformTags = try blurb.select("li.freeforms a.tag")
        return try freeformTags.array().map { try $0.text() }
    }

    private func parseLanguage(from blurb: Element) throws -> String {
        if let langDD = try blurb.select("dd.language").first() {
            return try langDD.text()
        }
        return "English"
    }

    private func parseSummary(from blurb: Element) throws -> String {
        if let summaryBlock = try blurb.select("blockquote.userstuff.summary").first() {
            let paragraphs = try summaryBlock.select("p")
            if !paragraphs.isEmpty() {
                return try paragraphs.array().map { try $0.text() }.joined(separator: "\n")
            } else {
                return try summaryBlock.text()
            }
        }
        return ""
    }

    private func parseStats(from blurb: Element) -> AO3WorkStats {
        var words = 0
        var chapters = "1/1"
        var kudos: Int? = nil
        var hits: Int? = nil
        var bookmarks: Int? = nil
        var comments: Int? = nil

        do {
            let statsDL = try blurb.select("dl.stats")

            if let wordsDD = try statsDL.select("dd.words").first() {
                let wordText = try wordsDD.text().replacingOccurrences(of: ",", with: "")
                words = Int(wordText) ?? 0
            }

            if let chaptersDD = try statsDL.select("dd.chapters").first() {
                chapters = try chaptersDD.text()
            }

            if let kudosDD = try statsDL.select("dd.kudos").first() {
                let kudosText = try kudosDD.text().replacingOccurrences(of: ",", with: "")
                kudos = Int(kudosText)
            }

            if let hitsDD = try statsDL.select("dd.hits").first() {
                let hitsText = try hitsDD.text().replacingOccurrences(of: ",", with: "")
                hits = Int(hitsText)
            }

            if let bookmarksDD = try statsDL.select("dd.bookmarks").first() {
                let bookmarksText = try bookmarksDD.text().replacingOccurrences(of: ",", with: "")
                bookmarks = Int(bookmarksText)
            }

            if let commentsDD = try statsDL.select("dd.comments").first() {
                let commentsText = try commentsDD.text().replacingOccurrences(of: ",", with: "")
                comments = Int(commentsText)
            }
        } catch {
            // Use defaults
        }

        return AO3WorkStats(
            words: words,
            chapters: chapters,
            kudos: kudos,
            hits: hits,
            bookmarks: bookmarks,
            comments: comments
        )
    }

    private func parsePublishedDate(from blurb: Element) -> Date {
        do {
            if let dateP = try blurb.select("p.datetime").first() {
                let dateText = try dateP.text()
                if let date = Self.dateFormatter.date(from: dateText) {
                    return date
                }
            }
        } catch {
            // Use current date as default
        }
        return Date()
    }

    private func parseWorkUpdateDate(from blurb: Element, fallback: Date) -> Date {
        do {
            if let headerModule = (try blurb.select("div.header.module")).first(),
               let commentNode = headerModule.childNode(0) as? Comment {
                let commentText = commentNode.getData()
                let regex = try NSRegularExpression(pattern: "updated_at=(\\d+)")
                if let match = regex.firstMatch(in: commentText, range: NSRange(commentText.startIndex..., in: commentText)),
                   let range = Range(match.range(at: 1), in: commentText),
                   let timestamp = TimeInterval(commentText[range]) {
                    return Date(timeIntervalSince1970: timestamp)
                }
            }
        } catch {
            // Use fallback
        }
        return fallback
    }
}
