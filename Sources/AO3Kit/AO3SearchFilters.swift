import Foundation

/// Completion status filter for searches
public enum AO3CompletionStatus: String {
    case all = ""
    case complete = "T"
    case incomplete = "F"
}

/// Crossover filter for searches
public enum AO3Crossover: String {
    case include = ""
    case exclude = "F"
    case only = "T"
}

/// Sort column options for search results
public enum AO3SortColumn: String {
    case bestMatch = "_score"
    case author = "authors_to_sort_on"
    case title = "title_to_sort_on"
    case datePosted = "created_at"
    case dateUpdated = "revised_at"
    case wordCount = "word_count"
    case hits = "hits"
    case kudos = "kudos_count"
    case comments = "comments_count"
    case bookmarks = "bookmarks_count"
}

/// Sort direction for search results
public enum AO3SortDirection: String {
    case ascending = "asc"
    case descending = "desc"
}

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
        var params: [String] = []

        // Work Info
        if let title = title {
            params.append("work_search%5Btitle%5D=\(AO3Utils.ao3URLEncode(title))")
        } else {
            params.append("work_search%5Btitle%5D=")
        }

        if let creators = creators {
            params.append("work_search%5Bcreators%5D=\(AO3Utils.ao3URLEncode(creators))")
        } else {
            params.append("work_search%5Bcreators%5D=")
        }

        if let revisedAt = revisedAt {
            params.append("work_search%5Brevised_at%5D=\(AO3Utils.ao3URLEncode(revisedAt))")
        } else {
            params.append("work_search%5Brevised_at%5D=")
        }

        if let complete = complete {
            params.append("work_search%5Bcomplete%5D=\(complete.rawValue)")
        } else {
            params.append("work_search%5Bcomplete%5D=")
        }

        if let crossover = crossover {
            params.append("work_search%5Bcrossover%5D=\(crossover.rawValue)")
        } else {
            params.append("work_search%5Bcrossover%5D=")
        }

        if let singleChapter = singleChapter {
            params.append("work_search%5Bsingle_chapter%5D=\(singleChapter ? "1" : "0")")
        } else {
            params.append("work_search%5Bsingle_chapter%5D=0")
        }

        if let wordCount = wordCount {
            params.append("work_search%5Bword_count%5D=\(AO3Utils.ao3URLEncode(wordCount))")
        } else {
            params.append("work_search%5Bword_count%5D=")
        }

        if let languageID = languageID {
            params.append("work_search%5Blanguage_id%5D=\(AO3Utils.ao3URLEncode(languageID))")
        } else {
            params.append("work_search%5Blanguage_id%5D=")
        }

        // Work Tags
        if let fandomNames = fandomNames {
            params.append("work_search%5Bfandom_names%5D=\(AO3Utils.ao3URLEncode(fandomNames))")
        } else {
            params.append("work_search%5Bfandom_names%5D=")
        }

        // Rating - only one can be selected
        // General = 10, Teen = 11, Mature = 12, Explicit = 13, Not Rated = 9
        if let rating = rating {
            let ratingID = getRatingID(rating)
            params.append("work_search%5Brating_ids%5D=\(ratingID)")
        }

        // Warnings - these use IDs and array notation
        // No Warnings Apply = 16, Violence = 17, Major Death = 18, Rape/Non-Con = 19, Underage = 20, Creator Chose Not To Use = 14
        if !warnings.isEmpty {
            for warning in warnings {
                let warningID = getWarningID(warning)
                params.append("work_search%5Barchive_warning_ids%5D%5B%5D=\(warningID)")
            }
        }

        // Categories - these use IDs
        // Gen = 21, F/M = 22, M/M = 23, F/F = 116, Multi = 2246, Other = 24
        if !categories.isEmpty {
            for category in categories {
                let categoryID = getCategoryID(category)
                params.append("work_search%5Bcategory_ids%5D=\(categoryID)")
            }
        }

        if let characterNames = characterNames {
            params.append("work_search%5Bcharacter_names%5D=\(AO3Utils.ao3URLEncode(characterNames))")
        } else {
            params.append("work_search%5Bcharacter_names%5D=")
        }

        if let relationshipNames = relationshipNames {
            params.append("work_search%5Brelationship_names%5D=\(AO3Utils.ao3URLEncode(relationshipNames))")
        } else {
            params.append("work_search%5Brelationship_names%5D=")
        }

        if let freeformNames = freeformNames {
            params.append("work_search%5Bfreeform_names%5D=\(AO3Utils.ao3URLEncode(freeformNames))")
        } else {
            params.append("work_search%5Bfreeform_names%5D=")
        }

        // Work Stats
        if let hits = hits {
            params.append("work_search%5Bhits%5D=\(AO3Utils.ao3URLEncode(hits))")
        } else {
            params.append("work_search%5Bhits%5D=")
        }

        if let kudosCount = kudosCount {
            params.append("work_search%5Bkudos_count%5D=\(AO3Utils.ao3URLEncode(kudosCount))")
        } else {
            params.append("work_search%5Bkudos_count%5D=")
        }

        if let commentsCount = commentsCount {
            params.append("work_search%5Bcomments_count%5D=\(AO3Utils.ao3URLEncode(commentsCount))")
        } else {
            params.append("work_search%5Bcomments_count%5D=")
        }

        if let bookmarksCount = bookmarksCount {
            params.append("work_search%5Bbookmarks_count%5D=\(AO3Utils.ao3URLEncode(bookmarksCount))")
        } else {
            params.append("work_search%5Bbookmarks_count%5D=")
        }

        // Results Options
        if let sortColumn = sortColumn {
            params.append("work_search%5Bsort_column%5D=\(sortColumn.rawValue)")
        } else {
            params.append("work_search%5Bsort_column%5D=_score")
        }

        if let sortDirection = sortDirection {
            params.append("work_search%5Bsort_direction%5D=\(sortDirection.rawValue)")
        } else {
            params.append("work_search%5Bsort_direction%5D=desc")
        }

        params.append("commit=Search")

        return params.joined(separator: "&")
    }

    // Helper methods to convert enums to AO3 tag IDs
    private func getRatingID(_ rating: AO3Rating) -> Int {
        switch rating {
        case .notRated: return 9
        case .general: return 10
        case .teenAndUp: return 11
        case .mature: return 12
        case .explicit: return 13
        }
    }

    private func getWarningID(_ warning: AO3Warning) -> Int {
        switch warning {
        case .noWarnings: return 14
        case .noneApply: return 16
        case .violence: return 17
        case .majorCharacterDeath: return 18
        case .nonCon: return 19
        case .underage: return 20
        case .none: return 16  // Default to "No Archive Warnings Apply"
        }
    }

    private func getCategoryID(_ category: AO3Category) -> Int {
        switch category {
        case .gen: return 21
        case .fm: return 22
        case .mm: return 23
        case .ff: return 116
        case .other: return 24
        case .multi: return 2246
        case .none: return 21  // Default to Gen
        }
    }
}
