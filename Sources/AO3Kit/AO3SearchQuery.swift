import Foundation

// MARK: - Search Query Builder

/// Result builder for creating search queries in a declarative way
@resultBuilder
public struct SearchQueryBuilder {
    public static func buildBlock(_ components: String...) -> String {
        components.joined(separator: " ")
    }

    public static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }

    public static func buildEither(first component: String) -> String {
        component
    }

    public static func buildEither(second component: String) -> String {
        component
    }
}

/// A more Swifty search query builder
public struct AO3SearchQuery {
    private var queryTerms: [String] = []
    private var useAdvancedSearch: Bool = false
    private var filters: AO3SearchFilters = AO3SearchFilters()

    public init() {}

    /// Add search terms
    public func term(_ term: String) -> AO3SearchQuery {
        var query = self
        query.queryTerms.append(term)
        return query
    }

    /// Set the AO3Warning filter (simple search - backward compatible)
    public func AO3Warning(_ warning: AO3Warning) -> AO3SearchQuery {
        var query = self
        query.filters.warnings.insert(warning)
        return query
    }

    /// Set the AO3Rating filter (simple search - backward compatible)
    public func AO3Rating(_ rating: AO3Rating) -> AO3SearchQuery {
        var query = self
        query.filters.ratings.insert(rating)
        return query
    }

    /// Add multiple warnings (advanced search)
    public func warnings(_ warnings: Set<AO3Warning>) -> AO3SearchQuery {
        var query = self
        query.filters.warnings = warnings
        query.useAdvancedSearch = true
        return query
    }

    /// Add multiple ratings (advanced search)
    public func ratings(_ ratings: Set<AO3Rating>) -> AO3SearchQuery {
        var query = self
        query.filters.ratings = ratings
        query.useAdvancedSearch = true
        return query
    }

    /// Set completion status filter
    public func complete(_ status: AO3CompletionStatus) -> AO3SearchQuery {
        var query = self
        query.filters.complete = status
        query.useAdvancedSearch = true
        return query
    }

    /// Set word count filter
    public func wordCount(_ range: String) -> AO3SearchQuery {
        var query = self
        query.filters.wordCount = range
        query.useAdvancedSearch = true
        return query
    }

    /// Set fandom filter
    public func fandom(_ fandomName: String) -> AO3SearchQuery {
        var query = self
        query.filters.fandomNames = fandomName
        query.useAdvancedSearch = true
        return query
    }

    /// Set character filter
    public func characters(_ characterNames: String) -> AO3SearchQuery {
        var query = self
        query.filters.characterNames = characterNames
        query.useAdvancedSearch = true
        return query
    }

    /// Set relationship filter
    public func relationships(_ relationshipNames: String) -> AO3SearchQuery {
        var query = self
        query.filters.relationshipNames = relationshipNames
        query.useAdvancedSearch = true
        return query
    }

    /// Set additional tags filter
    public func tags(_ tagNames: String) -> AO3SearchQuery {
        var query = self
        query.filters.freeformNames = tagNames
        query.useAdvancedSearch = true
        return query
    }

    /// Set categories filter
    public func categories(_ categories: Set<AO3Category>) -> AO3SearchQuery {
        var query = self
        query.filters.categories = categories
        query.useAdvancedSearch = true
        return query
    }

    /// Set title filter
    public func title(_ title: String) -> AO3SearchQuery {
        var query = self
        query.filters.title = title
        query.useAdvancedSearch = true
        return query
    }

    /// Set creator filter
    public func creator(_ creatorName: String) -> AO3SearchQuery {
        var query = self
        query.filters.creators = creatorName
        query.useAdvancedSearch = true
        return query
    }

    /// Set sort column
    public func sortBy(_ column: AO3SortColumn, direction: AO3SortDirection = .descending) -> AO3SearchQuery {
        var query = self
        query.filters.sortColumn = column
        query.filters.sortDirection = direction
        query.useAdvancedSearch = true
        return query
    }

    /// Set minimum kudos count
    public func minKudos(_ count: Int) -> AO3SearchQuery {
        var query = self
        query.filters.kudosCount = ">\(count)"
        query.useAdvancedSearch = true
        return query
    }

    /// Set crossover filter
    public func crossover(_ crossover: AO3Crossover) -> AO3SearchQuery {
        var query = self
        query.filters.crossover = crossover
        query.useAdvancedSearch = true
        return query
    }

    /// Set single chapter filter
    public func singleChapter(_ isSingle: Bool) -> AO3SearchQuery {
        var query = self
        query.filters.singleChapter = isSingle
        query.useAdvancedSearch = true
        return query
    }

    /// Execute the search
    public func execute() async throws -> [AO3Work] {
        let queryString = queryTerms.joined(separator: " ")

        // If using advanced search or any filters are set, use advanced search
        if useAdvancedSearch || !filters.ratings.isEmpty || !filters.warnings.isEmpty {
            return try await AO3.searchWork(query: queryString, filters: filters)
        } else {
            // Fall back to simple search for backward compatibility
            return try await AO3.searchWork(query: queryString, warnings: [], ratings: [])
        }
    }
}

// MARK: - AO3 Extensions with Fluent API

extension AO3 {
    /// Create a new search query using the fluent API
    public static func search() -> AO3SearchQuery {
        AO3SearchQuery()
    }
}
