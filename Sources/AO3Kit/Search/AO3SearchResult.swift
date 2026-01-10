//
//  AO3SearchResult.swift
//  AO3Kit
//
//  Search result container with pagination information
//

import Foundation

/// Contains search results along with pagination metadata
public struct AO3SearchResult: Sendable {
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

    /// Create a search result for a single page (no pagination)
    public init(works: [AO3Work]) {
        self.works = works
        self.currentPage = 1
        self.totalPages = 1
    }
}
