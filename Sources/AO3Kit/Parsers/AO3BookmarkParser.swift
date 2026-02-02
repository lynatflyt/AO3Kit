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
    private let blurbParser = AO3BlurbParser()

    /// Parse bookmarks with pagination info
    /// - Parameter document: The parsed HTML document
    /// - Returns: AO3WorksResult containing works and pagination metadata
    func parseBookmarksWithPagination(from document: Document) throws -> AO3WorksResult {
        let works = try parseBookmarks(from: document)
        let pagination = searchParser.parsePagination(from: document)
        return AO3WorksResult(works: works, currentPage: pagination.currentPage, totalPages: pagination.totalPages)
    }

    /// Parse bookmarks with pagination info (new type-safe API)
    /// - Parameter document: The parsed HTML document
    /// - Returns: AO3BookmarksResult containing bookmark entries and pagination metadata
    func parseBookmarksResultWithPagination(from document: Document) throws -> AO3BookmarksResult {
        let entries = try parseBookmarkEntries(from: document)
        let pagination = searchParser.parsePagination(from: document)
        return AO3BookmarksResult(entries: entries, currentPage: pagination.currentPage, totalPages: pagination.totalPages)
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

    /// Parse all bookmark entries from a bookmarks page (new type-safe API)
    /// - Parameter document: The parsed HTML document
    /// - Returns: Array of AO3BookmarkEntry objects with bookmark metadata
    func parseBookmarkEntries(from document: Document) throws -> [AO3BookmarkEntry] {
        guard let resultList = try document.select("ol.bookmark.index.group").first() else {
            return []
        }

        let blurbs = try resultList.select("li.bookmark.blurb.group")
        var entries: [AO3BookmarkEntry] = []

        for blurb in blurbs {
            // Extract work ID from the blurb
            guard let workLink = try blurb.select("h4.heading a[href*='/works/']").first() else {
                continue
            }

            let href = try workLink.attr("href")
            guard let workIDStr = href.components(separatedBy: "/works/").last?.components(separatedBy: "/").first,
                  let workID = Int(workIDStr) else {
                continue
            }

            do {
                let workBlurb = try blurbParser.parseBlurb(blurb, workID: workID)
                let bookmarkData = blurbParser.parseBookmarkData(blurb)
                let entry = AO3BookmarkEntry(
                    blurb: workBlurb,
                    bookmarkNotes: bookmarkData.notes,
                    bookmarkTags: bookmarkData.tags,
                    bookmarkDate: bookmarkData.date,
                    isPrivate: bookmarkData.isPrivate,
                    isRec: bookmarkData.isRec
                )
                entries.append(entry)
            } catch {
                // Skip entries that fail to parse
                continue
            }
        }

        return entries
    }
}
