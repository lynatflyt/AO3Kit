//
//  AO3WorksResult.swift
//  AO3Kit
//
//  Paginated result containers for various AO3 content types
//

import Foundation

// MARK: - AO3WorksResult (Legacy)

/// Contains a paginated list of works with navigation metadata
/// Used for search results, user works, tag browsing, etc.
public struct AO3WorksResult: Sendable {
    /// The works returned from this search page
    public let works: [AO3Work]

    /// Current page number (1-indexed)
    public let currentPage: Int

    /// Total number of pages available
    public let totalPages: Int

    /// Whether there is a next page of results
    public var hasNextPage: Bool {
        currentPage < totalPages
    }

    /// Whether there is a previous page of results
    public var hasPreviousPage: Bool {
        currentPage > 1
    }

    /// The next page number, if available
    public var nextPage: Int? {
        hasNextPage ? currentPage + 1 : nil
    }

    /// The previous page number, if available
    public var previousPage: Int? {
        hasPreviousPage ? currentPage - 1 : nil
    }

    /// Create a search result with pagination info
    public init(works: [AO3Work], currentPage: Int, totalPages: Int) {
        self.works = works
        self.currentPage = currentPage
        self.totalPages = max(1, totalPages) // At least 1 page
    }

    /// Create a result for a single page (no pagination)
    public init(works: [AO3Work]) {
        self.works = works
        self.currentPage = 1
        self.totalPages = 1
    }
}

/// Backward compatibility alias
@available(*, deprecated, renamed: "AO3WorksResult")
public typealias AO3SearchResult = AO3WorksResult

// MARK: - AO3BlurbsResult

/// Contains a paginated list of work blurbs with navigation metadata
/// Used for search results with the new type-safe blurb model
public struct AO3BlurbsResult: Sendable {
    /// The work blurbs returned from this page
    public let blurbs: [AO3WorkBlurb]

    /// Current page number (1-indexed)
    public let currentPage: Int

    /// Total number of pages available
    public let totalPages: Int

    /// Whether there is a next page of results
    public var hasNextPage: Bool {
        currentPage < totalPages
    }

    /// Whether there is a previous page of results
    public var hasPreviousPage: Bool {
        currentPage > 1
    }

    /// The next page number, if available
    public var nextPage: Int? {
        hasNextPage ? currentPage + 1 : nil
    }

    /// The previous page number, if available
    public var previousPage: Int? {
        hasPreviousPage ? currentPage - 1 : nil
    }

    /// Create a blurbs result with pagination info
    public init(blurbs: [AO3WorkBlurb], currentPage: Int, totalPages: Int) {
        self.blurbs = blurbs
        self.currentPage = currentPage
        self.totalPages = max(1, totalPages)
    }

    /// Create a result for a single page (no pagination)
    public init(blurbs: [AO3WorkBlurb]) {
        self.blurbs = blurbs
        self.currentPage = 1
        self.totalPages = 1
    }
}

// MARK: - AO3HistoryResult

/// Contains a paginated list of history entries with navigation metadata
/// Used for user reading history with type-safe lastVisitedDate
public struct AO3HistoryResult: Sendable {
    /// The history entries returned from this page
    public let entries: [AO3HistoryEntry]

    /// Current page number (1-indexed)
    public let currentPage: Int

    /// Total number of pages available
    public let totalPages: Int

    /// Whether there is a next page of results
    public var hasNextPage: Bool {
        currentPage < totalPages
    }

    /// Whether there is a previous page of results
    public var hasPreviousPage: Bool {
        currentPage > 1
    }

    /// The next page number, if available
    public var nextPage: Int? {
        hasNextPage ? currentPage + 1 : nil
    }

    /// The previous page number, if available
    public var previousPage: Int? {
        hasPreviousPage ? currentPage - 1 : nil
    }

    /// Create a history result with pagination info
    public init(entries: [AO3HistoryEntry], currentPage: Int, totalPages: Int) {
        self.entries = entries
        self.currentPage = currentPage
        self.totalPages = max(1, totalPages)
    }

    /// Create a result for a single page (no pagination)
    public init(entries: [AO3HistoryEntry]) {
        self.entries = entries
        self.currentPage = 1
        self.totalPages = 1
    }
}

// MARK: - AO3BookmarksResult

/// Contains a paginated list of bookmark entries with navigation metadata
/// Used for user bookmarks with type-safe bookmark metadata
public struct AO3BookmarksResult: Sendable {
    /// The bookmark entries returned from this page
    public let entries: [AO3BookmarkEntry]

    /// Current page number (1-indexed)
    public let currentPage: Int

    /// Total number of pages available
    public let totalPages: Int

    /// Whether there is a next page of results
    public var hasNextPage: Bool {
        currentPage < totalPages
    }

    /// Whether there is a previous page of results
    public var hasPreviousPage: Bool {
        currentPage > 1
    }

    /// The next page number, if available
    public var nextPage: Int? {
        hasNextPage ? currentPage + 1 : nil
    }

    /// The previous page number, if available
    public var previousPage: Int? {
        hasPreviousPage ? currentPage - 1 : nil
    }

    /// Create a bookmarks result with pagination info
    public init(entries: [AO3BookmarkEntry], currentPage: Int, totalPages: Int) {
        self.entries = entries
        self.currentPage = currentPage
        self.totalPages = max(1, totalPages)
    }

    /// Create a result for a single page (no pagination)
    public init(entries: [AO3BookmarkEntry]) {
        self.entries = entries
        self.currentPage = 1
        self.totalPages = 1
    }
}
