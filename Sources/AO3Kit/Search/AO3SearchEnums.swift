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
