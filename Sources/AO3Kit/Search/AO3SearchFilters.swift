import Foundation

/// Comprehensive filters for AO3 advanced search
public struct AO3SearchFilters {
    // Work Info
    public var title: String?
    public var creators: String?
    public var revisedAt: String?  // Date range
    public var complete: AO3CompletionStatus?
    public var crossover: AO3Crossover?
    public var singleChapter: Bool?
    public var wordCount: String?  // Range like ">1000" or "1000-5000"
    public var languageID: String?

    // Work Tags
    public var fandomNames: String?
    public var rating: AO3Rating?  // Only one rating can be selected at a time
    public var warnings: Set<AO3Warning>
    public var categories: Set<AO3Category>
    public var characterNames: String?
    public var relationshipNames: String?
    public var freeformNames: String?  // Additional tags

    // Work Stats
    public var hits: String?  // Range
    public var kudosCount: String?  // Range
    public var commentsCount: String?  // Range
    public var bookmarksCount: String?  // Range

    // Results Options
    public var sortColumn: AO3SortColumn?
    public var sortDirection: AO3SortDirection?

    public init(
        title: String? = nil,
        creators: String? = nil,
        revisedAt: String? = nil,
        complete: AO3CompletionStatus? = nil,
        crossover: AO3Crossover? = nil,
        singleChapter: Bool? = nil,
        wordCount: String? = nil,
        languageID: String? = nil,
        fandomNames: String? = nil,
        rating: AO3Rating? = nil,
        warnings: Set<AO3Warning> = [],
        categories: Set<AO3Category> = [],
        characterNames: String? = nil,
        relationshipNames: String? = nil,
        freeformNames: String? = nil,
        hits: String? = nil,
        kudosCount: String? = nil,
        commentsCount: String? = nil,
        bookmarksCount: String? = nil,
        sortColumn: AO3SortColumn? = nil,
        sortDirection: AO3SortDirection? = nil
    ) {
        self.title = title
        self.creators = creators
        self.revisedAt = revisedAt
        self.complete = complete
        self.crossover = crossover
        self.singleChapter = singleChapter
        self.wordCount = wordCount
        self.languageID = languageID
        self.fandomNames = fandomNames
        self.rating = rating
        self.warnings = warnings
        self.categories = categories
        self.characterNames = characterNames
        self.relationshipNames = relationshipNames
        self.freeformNames = freeformNames
        self.hits = hits
        self.kudosCount = kudosCount
        self.commentsCount = commentsCount
        self.bookmarksCount = bookmarksCount
        self.sortColumn = sortColumn
        self.sortDirection = sortDirection
    }

    /// Build URL parameters from filters
    internal func buildURLParameters() -> String {
        let builder = AO3SearchURLBuilder()
        return builder.build(from: self)
    }
}
