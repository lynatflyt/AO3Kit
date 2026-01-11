import Foundation
import SwiftSoup

/// Thread-safe cache configuration actor
private actor AO3Configuration {
    static let shared = AO3Configuration()
    private var cache: AO3CacheProtocol?

    func setCache(_ cache: AO3CacheProtocol?) {
        self.cache = cache
    }

    func getCache() -> AO3CacheProtocol? {
        return cache
    }
}

/// Main API class for interacting with Archive of Our Own (AO3)
public struct AO3 {
    /// Configure the cache for AO3 requests
    /// - Parameter cache: The cache implementation to use, or nil to disable caching
    /// - Note: This should be called once at app startup before making any requests
    public static func configure(cache: AO3CacheProtocol?) async {
        await AO3Configuration.shared.setCache(cache)
    }

    /// Retrieves a work by its ID
    /// - Parameter workID: The work ID to retrieve
    /// - Returns: An AO3Work object containing work metadata
    /// - Throws: AO3Exception if the work cannot be retrieved
    public static func getWork(_ workID: Int) async throws -> AO3Work {
        // Check cache first
        if let cached = await AO3Configuration.shared.getCache()?.getWork(workID) {
            return cached
        }

        // Cache miss or no cache - fetch from network
        do {
            let work = try await AO3Work(id: workID)

            // Cache the first chapter if we parsed content from the work page
            // This avoids a duplicate request when user opens the chapter
            if let content = work.firstChapterContent,
               let html = work.firstChapterHTML,
               let firstChapterInfo = work.chapters.first {
                let chapter = AO3Chapter(
                    workID: work.id,
                    chapterID: firstChapterInfo.id,
                    number: firstChapterInfo.number,
                    title: firstChapterInfo.title,
                    content: content,
                    contentHTML: html,
                    notes: work.firstChapterNotes,
                    summary: work.firstChapterSummary
                )
                await AO3Configuration.shared.getCache()?.setChapter(chapter)
            }

            // Store work in cache if available
            await AO3Configuration.shared.getCache()?.setWork(work)
            return work
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to obtain work. Most likely a parsing error!", error)
        }
    }

    /// Retrieves a user by their username
    /// - Parameter username: The username to retrieve
    /// - Returns: An AO3User object containing user information
    /// - Throws: AO3Exception if the user cannot be retrieved
    public static func getUser(_ username: String) async throws -> AO3User {
        return try await getPseud(username: username, pseud: username)
    }

    /// Retrieves a user with a specific pseudonym
    /// - Parameters:
    ///   - username: The username
    ///   - pseud: The pseudonym
    /// - Returns: An AO3User object containing user information
    /// - Throws: AO3Exception if the user cannot be retrieved
    public static func getPseud(username: String, pseud: String) async throws -> AO3User {
        // Check cache first
        if let cached = await AO3Configuration.shared.getCache()?.getUser(username: username, pseud: pseud) {
            return cached
        }

        // Cache miss or no cache - fetch from network
        do {
            let user = try await AO3User(username: username, pseud: pseud)
            // Store in cache if available
            await AO3Configuration.shared.getCache()?.setUser(user)
            return user
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to obtain user. Most likely a parsing error!", error)
        }
    }

    // MARK: - User Works & Bookmarks

    /// Retrieves a paginated list of works by a user
    /// - Parameters:
    ///   - username: The username to get works for
    ///   - page: Page number (1-indexed, default 1)
    /// - Returns: AO3WorksResult containing works and pagination info
    /// - Throws: AO3Exception if the works cannot be retrieved
    public static func getUserWorks(
        username: String,
        page: Int = 1
    ) async throws -> AO3WorksResult {
        do {
            var urlString = "https://archiveofourown.org/users/\(username)/works"
            if page > 1 {
                urlString += "?page=\(page)"
            }

            let (data, statusCode) = try await AO3Utils.syncRequest(urlString)

            guard statusCode == 200 else {
                if statusCode == 404 {
                    throw AO3Exception.userNotFound(username)
                }
                throw AO3Exception.invalidStatusCode(statusCode, nil)
            }

            guard let body = String(data: data, encoding: .utf8) else {
                throw AO3Exception.noBodyReturned
            }

            let document = try SwiftSoup.parse(body)
            let parser = AO3SearchResultParser()
            let result = try parser.parseSearchResultsWithPagination(from: document)

            // Cache the parsed works
            for work in result.works {
                await AO3Configuration.shared.getCache()?.setWork(work)
            }

            return result
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to get user works. Most likely a parsing error!", error)
        }
    }

    /// Retrieves a paginated list of bookmarks by a user
    /// - Parameters:
    ///   - username: The username to get bookmarks for
    ///   - page: Page number (1-indexed, default 1)
    /// - Returns: AO3WorksResult containing bookmarked works and pagination info
    /// - Throws: AO3Exception if the bookmarks cannot be retrieved
    public static func getUserBookmarks(
        username: String,
        page: Int = 1
    ) async throws -> AO3WorksResult {
        do {
            var urlString = "https://archiveofourown.org/users/\(username)/bookmarks"
            if page > 1 {
                urlString += "?page=\(page)"
            }

            let (data, statusCode) = try await AO3Utils.syncRequest(urlString)

            guard statusCode == 200 else {
                if statusCode == 404 {
                    throw AO3Exception.userNotFound(username)
                }
                throw AO3Exception.invalidStatusCode(statusCode, nil)
            }

            guard let body = String(data: data, encoding: .utf8) else {
                throw AO3Exception.noBodyReturned
            }

            let document = try SwiftSoup.parse(body)
            let parser = AO3BookmarkParser()
            let result = try parser.parseBookmarksWithPagination(from: document)

            // Cache the parsed works
            for work in result.works {
                await AO3Configuration.shared.getCache()?.setWork(work)
            }

            return result
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to get user bookmarks. Most likely a parsing error!", error)
        }
    }

    /// Internal method to get a chapter with caching support
    /// - Parameters:
    ///   - workID: The work ID
    ///   - chapterID: The chapter ID
    /// - Returns: An AO3Chapter object
    /// - Throws: AO3Exception if the chapter cannot be retrieved
    internal static func getChapter(workID: Int, chapterID: Int) async throws -> AO3Chapter {
        // Check cache first
        if let cached = await AO3Configuration.shared.getCache()?.getChapter(workID: workID, chapterID: chapterID) {
            return cached
        }

        // Cache miss or no cache - fetch from network
        let chapter = try await AO3Chapter(workID: workID, chapterID: chapterID)

        // If we parsed work metadata from the chapter page, refresh the work cache
        // This keeps work stats (kudos, hits, etc.) fresh without extra requests
        if let parsedWork = chapter.parsedWork {
            // Also cache the current chapter in the work's first chapter data
            // so it's available if this chapter is the first one
            if let firstChapterInfo = parsedWork.chapters.first,
               firstChapterInfo.id == chapterID {
                parsedWork.firstChapterContent = chapter.content
                parsedWork.firstChapterHTML = chapter.contentHTML
                parsedWork.firstChapterNotes = chapter.notes
                parsedWork.firstChapterSummary = chapter.summary
            }
            await AO3Configuration.shared.getCache()?.setWork(parsedWork)
        }

        // Store chapter in cache
        await AO3Configuration.shared.getCache()?.setChapter(chapter)
        return chapter
    }

    /// Searches for works matching the given query (simple search)
    /// - Parameters:
    ///   - query: The search query
    ///   - warnings: Optional set of warning filters
    ///   - rating: Optional rating filter (only one can be selected)
    /// - Returns: Array of AO3Work objects matching the search criteria
    /// - Throws: AO3Exception if the search fails
    public static func searchWork(
        query: String,
        warnings: Set<AO3Warning> = [],
        rating: AO3Rating? = nil
    ) async throws -> [AO3Work] {
        do {
            return try await performSearch(query: query, warnings: warnings, rating: rating)
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to search for works! Most likely a parsing error!", error)
        }
    }

    /// Searches for works with advanced filters
    /// - Parameters:
    ///   - query: The main search query
    ///   - filters: Advanced search filters
    /// - Returns: Array of AO3Work objects matching the search criteria
    /// - Throws: AO3Exception if the search fails
    public static func searchWork(
        query: String,
        filters: AO3SearchFilters
    ) async throws -> [AO3Work] {
        do {
            return try await performAdvancedSearch(query: query, filters: filters)
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to search for works! Most likely a parsing error!", error)
        }
    }

    // MARK: - Paginated Search

    /// Searches for works with pagination support (simple search)
    /// - Parameters:
    ///   - query: The search query
    ///   - page: Page number (1-indexed, default 1)
    ///   - warnings: Optional set of warning filters
    ///   - rating: Optional rating filter
    /// - Returns: AO3WorksResult containing works and pagination info
    /// - Throws: AO3Exception if the search fails
    public static func searchWorkPaginated(
        query: String,
        page: Int = 1,
        warnings: Set<AO3Warning> = [],
        rating: AO3Rating? = nil
    ) async throws -> AO3WorksResult {
        var filters = AO3SearchFilters()
        filters.warnings = warnings
        filters.rating = rating

        return try await searchWorkPaginated(query: query, page: page, filters: filters)
    }

    /// Searches for works with advanced filters and pagination support
    /// - Parameters:
    ///   - query: The main search query
    ///   - page: Page number (1-indexed, default 1)
    ///   - filters: Advanced search filters
    /// - Returns: AO3WorksResult containing works and pagination info
    /// - Throws: AO3Exception if the search fails
    public static func searchWorkPaginated(
        query: String,
        page: Int = 1,
        filters: AO3SearchFilters
    ) async throws -> AO3WorksResult {
        do {
            return try await performAdvancedSearchPaginated(query: query, page: page, filters: filters)
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to search for works! Most likely a parsing error!", error)
        }
    }

    private static func performSearch(
        query: String,
        warnings: Set<AO3Warning>,
        rating: AO3Rating?
    ) async throws -> [AO3Work] {
        // Use the same format as advanced search for consistency with AO3's actual search URLs
        var filters = AO3SearchFilters()
        filters.warnings = warnings
        filters.rating = rating

        return try await performAdvancedSearch(query: query, filters: filters)
    }

    private static func performAdvancedSearch(
        query: String,
        filters: AO3SearchFilters
    ) async throws -> [AO3Work] {
        let result = try await performAdvancedSearchPaginated(query: query, page: 1, filters: filters)
        return result.works
    }

    private static func performAdvancedSearchPaginated(
        query: String,
        page: Int,
        filters: AO3SearchFilters
    ) async throws -> AO3WorksResult {
        var urlString = "https://archiveofourown.org/works/search?"

        // Add page parameter
        if page > 1 {
            urlString += "page=\(page)&"
        }

        urlString += "work_search%5Bquery%5D="
        urlString += AO3Utils.ao3URLEncode(query)
        urlString += "&"
        urlString += filters.buildURLParameters()

        return try await executeSearchPaginated(urlString: urlString)
    }

    // MARK: - Autocomplete

    /// Fetches autocomplete suggestions for tags
    /// - Parameters:
    ///   - type: The type of autocomplete (fandom, relationship, character, freeform)
    ///   - term: The search term to get suggestions for
    /// - Returns: Array of tag name suggestions
    /// - Throws: AO3Exception if the request fails
    public static func autocomplete(
        type: AO3AutocompleteType,
        term: String
    ) async throws -> [String] {
        guard !term.isEmpty else { return [] }

        let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        let urlString = "https://archiveofourown.org/autocomplete/\(type.rawValue).json?term=\(encodedTerm)"

        let (data, statusCode) = try await AO3Utils.syncRequest(urlString)

        guard statusCode == 200 else {
            throw AO3Exception.invalidStatusCode(statusCode, nil)
        }

        // Parse JSON response: [{"id": "Tag Name", "name": "Tag Name"}, ...]
        struct AutocompleteResult: Decodable {
            let id: String
            let name: String
        }

        let results = try AO3Utils.jsonDecoder.decode([AutocompleteResult].self, from: data)
        return results.map { $0.name }
    }

    // MARK: - Search Implementation

    private static func executeSearch(urlString: String) async throws -> [AO3Work] {
        let result = try await executeSearchPaginated(urlString: urlString)
        return result.works
    }

    private static func executeSearchPaginated(urlString: String) async throws -> AO3WorksResult {
        let (data, statusCode) = try await AO3Utils.syncRequest(urlString)

        guard statusCode == 200 else {
            throw AO3Exception.invalidStatusCode(statusCode, nil)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        let document = try SwiftSoup.parse(body)

        // Parse work metadata and pagination from the search result page
        let parser = AO3SearchResultParser()
        let result = try parser.parseSearchResultsWithPagination(from: document)

        // Cache the parsed works if caching is enabled
        for work in result.works {
            await AO3Configuration.shared.getCache()?.setWork(work)
        }

        return result
    }
}
