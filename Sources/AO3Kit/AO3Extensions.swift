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
    private var warning: AO3Work.Warning?
    private var rating: AO3Work.Rating?

    public init() {}

    /// Add search terms
    public func term(_ term: String) -> AO3SearchQuery {
        var query = self
        query.queryTerms.append(term)
        return query
    }

    /// Set the warning filter
    public func warning(_ warning: AO3Work.Warning) -> AO3SearchQuery {
        var query = self
        query.warning = warning
        return query
    }

    /// Set the rating filter
    public func rating(_ rating: AO3Work.Rating) -> AO3SearchQuery {
        var query = self
        query.rating = rating
        return query
    }

    /// Execute the search
    public func execute() async throws -> [AO3Work] {
        let queryString = queryTerms.joined(separator: " ")
        return try await AO3.searchWork(query: queryString, warning: warning, rating: rating)
    }
}

// MARK: - AO3 Extensions with Fluent API

extension AO3 {
    /// Create a new search query using the fluent API
    public static func search() -> AO3SearchQuery {
        AO3SearchQuery()
    }
}

// MARK: - AO3Work Extensions

extension AO3Work {
    /// Convenience property for word count as an integer
    public var wordCount: Int? {
        guard let wordsString = stats["words"] else { return nil }
        return Int(wordsString.replacingOccurrences(of: ",", with: ""))
    }

    /// Convenience property for kudos count as an integer
    public var kudosCount: Int? {
        guard let kudosString = stats["kudos"] else { return nil }
        return Int(kudosString.replacingOccurrences(of: ",", with: ""))
    }

    /// Convenience property for hits count as an integer
    public var hitsCount: Int? {
        guard let hitsString = stats["hits"] else { return nil }
        return Int(hitsString.replacingOccurrences(of: ",", with: ""))
    }

    /// Convenience property for bookmarks count as an integer
    public var bookmarksCount: Int? {
        guard let bookmarksString = stats["bookmarks"] else { return nil }
        return Int(bookmarksString.replacingOccurrences(of: ",", with: ""))
    }

    /// Convenience property for comments count as an integer
    public var commentsCount: Int? {
        guard let commentsString = stats["comments"] else { return nil }
        return Int(commentsString.replacingOccurrences(of: ",", with: ""))
    }

    /// Convenience property for chapter count
    public var chapterCount: Int {
        return chapters.count
    }

    /// Check if the work is complete
    public var isComplete: Bool {
        // This is an approximation - AO3 doesn't always provide completion status consistently
        // In the original, this would be in the stats, but we'd need to parse it differently
        return chapters.count > 0
    }

    /// Get all chapters asynchronously
    public func getAllChapters() async throws -> [AO3Chapter] {
        return try await withThrowingTaskGroup(of: (Int, AO3Chapter).self) { group in
            for chapterID in chapters.keys {
                group.addTask {
                    let chapter = try await self.getChapter(chapterID)
                    return (chapterID, chapter)
                }
            }

            var results: [Int: AO3Chapter] = [:]
            for try await (id, chapter) in group {
                results[id] = chapter
            }

            return results.keys.sorted().compactMap { results[$0] }
        }
    }

    /// Get the first chapter
    public func getFirstChapter() async throws -> AO3Chapter {
        guard let firstID = chapters.keys.sorted().first else {
            throw AO3Exception.chapterNotFound(-1)
        }
        return try await getChapter(firstID)
    }
}

// MARK: - Collection Extensions

extension Collection where Element == AO3Work {
    /// Sort works by kudos count (descending)
    public func sortedByKudos() -> [AO3Work] {
        self.sorted { (lhs, rhs) in
            (lhs.kudosCount ?? 0) > (rhs.kudosCount ?? 0)
        }
    }

    /// Sort works by word count (descending)
    public func sortedByWordCount() -> [AO3Work] {
        self.sorted { (lhs, rhs) in
            (lhs.wordCount ?? 0) > (rhs.wordCount ?? 0)
        }
    }

    /// Sort works by hits (descending)
    public func sortedByHits() -> [AO3Work] {
        self.sorted { (lhs, rhs) in
            (lhs.hitsCount ?? 0) > (rhs.hitsCount ?? 0)
        }
    }

    /// Sort works by date published (newest first)
    public func sortedByPublished() -> [AO3Work] {
        self.sorted { (lhs, rhs) in
            lhs.published > rhs.published
        }
    }

    /// Sort works by date updated (newest first)
    public func sortedByUpdated() -> [AO3Work] {
        self.sorted { (lhs, rhs) in
            lhs.updated > rhs.updated
        }
    }

    /// Filter works by minimum word count
    public func withMinimumWords(_ count: Int) -> [AO3Work] {
        self.filter { ($0.wordCount ?? 0) >= count }
    }

    /// Filter works by rating
    public func withRating(_ rating: AO3Work.Rating) -> [AO3Work] {
        self.filter { $0.rating == rating }
    }

    /// Filter works by warning
    public func withWarning(_ warning: AO3Work.Warning) -> [AO3Work] {
        self.filter { $0.archiveWarning == warning }
    }

    /// Filter works by category
    public func withCategory(_ category: AO3Work.Category) -> [AO3Work] {
        self.filter { $0.category == category }
    }
}

// MARK: - String Extensions for AO3

extension String {
    /// Check if string contains AO3 work URL and extract ID
    public var ao3WorkID: Int? {
        let pattern = #"archiveofourown\.org/works/(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)),
              let range = Range(match.range(at: 1), in: self) else {
            return nil
        }
        return Int(self[range])
    }
}

// MARK: - Async Sequence for Paginated Results (Future Enhancement)

/// A protocol for searchable content
public protocol AO3Searchable {
    associatedtype ResultType
    func search(query: String) async throws -> [ResultType]
}

// MARK: - Custom Operators (Optional - can be removed if too "clever")

infix operator ~>: AdditionPrecedence

/// Operator for chaining async operations
public func ~> <T, U>(lhs: @autoclosure () async throws -> T,
                       rhs: (T) async throws -> U) async throws -> U {
    let value = try await lhs()
    return try await rhs(value)
}
