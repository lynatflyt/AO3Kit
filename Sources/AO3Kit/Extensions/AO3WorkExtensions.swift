import Foundation

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

    /// Filter works by AO3Rating
    public func withAO3Rating(_ rating: AO3Rating) -> [AO3Work] {
        self.filter { $0.rating == rating }
    }

    /// Filter works by AO3Warning
    public func withAO3Warning(_ warning: AO3Warning) -> [AO3Work] {
        self.filter { $0.archiveWarning == warning }
    }

    /// Filter works by category
    public func withCategory(_ category: AO3Category) -> [AO3Work] {
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
