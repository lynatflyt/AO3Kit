//
//  AO3SearchResultParser.swift
//  AO3Kit
//
//  Parses work metadata directly from search result blurbs
//  This avoids making individual requests for each work in search results
//

import Foundation
import SwiftSoup

/// Pagination information parsed from search results
internal struct AO3PaginationInfo {
    let currentPage: Int
    let totalPages: Int

    static let empty = AO3PaginationInfo(currentPage: 1, totalPages: 1)
}

/// Parses AO3 search result blurbs into AO3Work objects
/// This is much more efficient than fetching each work individually
internal struct AO3SearchResultParser {
    // Static date formatter to avoid expensive re-initialization
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yyyy"
        return formatter
    }()

    /// Parse search results with pagination info
    /// - Parameter document: The parsed HTML document
    /// - Returns: AO3SearchResult containing works and pagination metadata
    func parseSearchResultsWithPagination(from document: Document) throws -> AO3SearchResult {
        let works = try parseSearchResults(from: document)
        let pagination = parsePagination(from: document)
        return AO3SearchResult(works: works, currentPage: pagination.currentPage, totalPages: pagination.totalPages)
    }

    /// Parse pagination information from the search results page
    /// - Parameter document: The parsed HTML document
    /// - Returns: Pagination info with current page and total pages
    func parsePagination(from document: Document) -> AO3PaginationInfo {
        do {
            // Find the pagination element - it has class "pagination actions"
            guard let paginationOL = try document.select("ol.pagination").first() else {
                // No pagination means single page of results
                return .empty
            }

            let listItems = try paginationOL.select("li")

            var currentPage = 1
            var totalPages = 1

            for item in listItems {
                let text = try item.text().trimmingCharacters(in: .whitespaces)

                // Skip Previous/Next arrows and ellipsis
                if text == "← Previous" || text == "Next →" || text == "…" {
                    continue
                }

                // Check if this is the current page (no link, just text)
                if try item.select("a").isEmpty(), let pageNum = Int(text) {
                    currentPage = pageNum
                }

                // Track the highest page number we see
                if let pageNum = Int(text) {
                    totalPages = max(totalPages, pageNum)
                }

                // Also check links for page numbers (the last numbered link is often the total)
                if let link = try item.select("a").first() {
                    let linkText = try link.text()
                    if let pageNum = Int(linkText) {
                        totalPages = max(totalPages, pageNum)
                    }
                }
            }

            return AO3PaginationInfo(currentPage: currentPage, totalPages: totalPages)
        } catch {
            return .empty
        }
    }

    /// Parse all work blurbs from a search results page
    /// - Parameter document: The parsed HTML document
    /// - Returns: Array of AO3Work objects parsed from blurbs
    func parseSearchResults(from document: Document) throws -> [AO3Work] {
        guard let resultList = try document.select("ol.work.index.group").first() else {
            return []
        }

        let blurbs = try resultList.select("li.work.blurb.group")
        var works: [AO3Work] = []

        for blurb in blurbs {
            // Extract work ID from the element's id attribute (format: "work_12345")
            let elementId = blurb.id()
            guard elementId.hasPrefix("work_"),
                  let workID = Int(elementId.dropFirst(5)) else {
                continue
            }

            do {
                let work = try AO3Work(id: workID, blurb: blurb)
                works.append(work)
            } catch {
                // Silently skip works that fail to parse - this is expected when
                // AO3's HTML structure changes or contains malformed data.
                // The partial results are still useful to the caller.
                continue
            }
        }

        return works
    }

    /// Parse a single work blurb and populate the work object
    /// - Parameters:
    ///   - blurb: The blurb HTML element
    ///   - work: The AO3Work object to populate
    func parseBlurb(_ blurb: Element, into work: AO3Work) throws {
        // Title
        if let titleLink = try blurb.select("h4.heading a").first() {
            let href = try titleLink.attr("href")
            if href.contains("/works/") {
                work.title = try titleLink.text()
            }
        }

        // Authors - use lightweight initializer to avoid network requests
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
        work.authors = parsedAuthors

        // Fandoms - get the first one as primary
        if let fandomTag = try blurb.select("h5.fandoms a.tag").first() {
            work.fandom = try fandomTag.text()
        }

        // Required tags (rating, warnings, category)
        // These are in spans with specific class patterns
        parseRequiredTags(from: blurb, into: work)

        // Relationships
        let relationshipTags = try blurb.select("li.relationships a.tag")
        work.relationships = try relationshipTags.array().map { try $0.text() }

        // Characters
        let characterTags = try blurb.select("li.characters a.tag")
        work.characters = try characterTags.array().map { try $0.text() }

        // Additional tags (freeforms)
        let freeformTags = try blurb.select("li.freeforms a.tag")
        work.additionalTags = try freeformTags.array().map { try $0.text() }

        // Language - check if present in blurb, otherwise default
        if let langDD = try blurb.select("dd.language").first() {
            work.language = try langDD.text()
        } else {
            work.language = "English"
        }

        // Summary
        if let summaryBlock = try blurb.select("blockquote.userstuff.summary").first() {
            let paragraphs = try summaryBlock.select("p")
            if !paragraphs.isEmpty() {
                work.firstChapterSummary = try paragraphs.array().map { try $0.text() }.joined(separator: "\n")
            } else {
                work.firstChapterSummary = try summaryBlock.text()
            }
        }

        // Stats
        parseStats(from: blurb, into: work)

        // Dates
        parseDates(from: blurb, into: work)

        // Parse chapters from stats
        parseChaptersFromStats(into: work)
    }

    // MARK: - Private Parsing Helpers

    private func parseRequiredTags(from blurb: Element, into work: AO3Work) {
        do {
            // Rating - look for span with rating-* class
            if let ratingSpan = try blurb.select("span.rating").first() {
                let ratingText = try ratingSpan.text()
                work.rating = AO3Rating.byValue(ratingText)
            } else if let ratingSpan = try blurb.select("ul.required-tags li").first()?.select("span").first() {
                let ratingText = try ratingSpan.attr("title")
                work.rating = AO3Rating.byValue(ratingText)
            }

            // Warnings
            if let warningSpan = try blurb.select("span.warnings").first() {
                let warningText = try warningSpan.text()
                work.archiveWarning = AO3Warning.byValue(warningText)
            } else if let warningLi = try blurb.select("ul.required-tags li").array().dropFirst().first {
                let warningText = try warningLi.select("span").first()?.attr("title") ?? ""
                work.archiveWarning = AO3Warning.byValue(warningText)
            }

            // Category
            if let categorySpan = try blurb.select("span.category").first() {
                let categoryText = try categorySpan.text()
                work.category = (try? AO3Category.byValue(categoryText)) ?? .none
            } else if let categoryLi = try blurb.select("ul.required-tags li").array().dropFirst(2).first {
                let categoryText = try categoryLi.select("span").first()?.attr("title") ?? ""
                work.category = (try? AO3Category.byValue(categoryText)) ?? .none
            }
        } catch {
            // If parsing fails, use defaults
        }
    }

    private func parseStats(from blurb: Element, into work: AO3Work) {
        var stats: [String: String] = [:]

        do {
            let statsDL = try blurb.select("dl.stats")

            // Words
            if let wordsDD = try statsDL.select("dd.words").first() {
                stats["words"] = try wordsDD.text().replacingOccurrences(of: ",", with: "")
            }

            // Chapters
            if let chaptersDD = try statsDL.select("dd.chapters").first() {
                let chaptersText = try chaptersDD.text() // Format: "1/1" or "5/?"
                stats["chapters"] = chaptersText
            }

            // Kudos
            if let kudosDD = try statsDL.select("dd.kudos").first() {
                stats["kudos"] = try kudosDD.text().replacingOccurrences(of: ",", with: "")
            }

            // Hits
            if let hitsDD = try statsDL.select("dd.hits").first() {
                stats["hits"] = try hitsDD.text().replacingOccurrences(of: ",", with: "")
            }

            // Bookmarks
            if let bookmarksDD = try statsDL.select("dd.bookmarks").first() {
                stats["bookmarks"] = try bookmarksDD.text().replacingOccurrences(of: ",", with: "")
            }

            // Comments
            if let commentsDD = try statsDL.select("dd.comments").first() {
                stats["comments"] = try commentsDD.text().replacingOccurrences(of: ",", with: "")
            }
        } catch {
            // If parsing fails, use empty stats
        }

        work.stats = stats
    }

    private func parseDates(from blurb: Element, into work: AO3Work) {
        do {
            if let dateP = try blurb.select("p.datetime").first() {
                let dateText = try dateP.text()
                if let date = Self.dateFormatter.date(from: dateText) {
                    work.published = date
                    work.updated = date
                }
            }
        } catch {
            // Use current date as default
        }
    }

    private func parseChaptersFromStats(into work: AO3Work) {
        guard let chaptersText = work.stats["chapters"] else { return }

        let parts = chaptersText.split(separator: "/")
        if let currentStr = parts.first,
           let current = Int(currentStr) {
            // Create placeholder chapter infos
            // For single-chapter works, use work ID as chapter ID (AO3 convention)
            if current == 1 && (parts.count < 2 || parts[1] == "1") {
                work.chapters = [AO3ChapterInfo(id: work.id, number: 1, title: work.title)]
            }
            // For multi-chapter works, leave chapters empty - they'll be populated on full load
            // This is fine because the user will need to fetch the full work to get chapter details anyway
        }
    }
}
