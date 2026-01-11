//
//  AO3BookmarkParser.swift
//  AO3Kit
//
//  Parses bookmarked works from a user's bookmarks page
//

import Foundation
import SwiftSoup

/// Parses AO3 bookmark pages into AO3Work objects
internal struct AO3BookmarkParser {
    private let searchParser = AO3SearchResultParser()

    /// Parse bookmarks with pagination info
    /// - Parameter document: The parsed HTML document
    /// - Returns: AO3WorksResult containing works and pagination metadata
    func parseBookmarksWithPagination(from document: Document) throws -> AO3WorksResult {
        let works = try parseBookmarks(from: document)
        let pagination = searchParser.parsePagination(from: document)
        return AO3WorksResult(works: works, currentPage: pagination.currentPage, totalPages: pagination.totalPages)
    }

    /// Parse all bookmarked works from a bookmarks page
    /// - Parameter document: The parsed HTML document
    /// - Returns: Array of AO3Work objects parsed from bookmark blurbs
    func parseBookmarks(from document: Document) throws -> [AO3Work] {
        // Bookmarks page uses ol.bookmark.index.group with li.bookmark.blurb.group
        guard let resultList = try document.select("ol.bookmark.index.group").first() else {
            return []
        }

        let blurbs = try resultList.select("li.bookmark.blurb.group")
        var works: [AO3Work] = []

        for blurb in blurbs {
            // Extract work ID from the blurb
            // Bookmark blurbs have links to works in the heading
            guard let workLink = try blurb.select("h4.heading a[href*='/works/']").first() else {
                continue
            }

            let href = try workLink.attr("href")
            guard let workIDStr = href.components(separatedBy: "/works/").last?.components(separatedBy: "/").first,
                  let workID = Int(workIDStr) else {
                continue
            }

            do {
                let work = try AO3Work(id: workID, blurb: blurb)
                works.append(work)
            } catch {
                // Skip works that fail to parse
                continue
            }
        }

        return works
    }
}
