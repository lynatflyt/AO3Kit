import Foundation
import SwiftSoup

/// Main API class for interacting with Archive of Our Own (AO3)
public struct AO3 {
    private nonisolated(unsafe) static var cache: AO3CacheProtocol?

    /// Configure the cache for AO3 requests
    /// - Parameter cache: The cache implementation to use, or nil to disable caching
    /// - Note: This should be called once at app startup before making any requests
    public static func configure(cache: AO3CacheProtocol?) {
        self.cache = cache
    }

    /// Retrieves a work by its ID
    /// - Parameter workID: The work ID to retrieve
    /// - Returns: An AO3Work object containing work metadata
    /// - Throws: AO3Exception if the work cannot be retrieved
    public static func getWork(_ workID: Int) async throws -> AO3Work {
        // Check cache first
        if let cached = await cache?.getWork(workID) {
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
                await cache?.setChapter(chapter)
            }

            // Store work in cache if available
            await cache?.setWork(work)
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
        if let cached = await cache?.getUser(username: username, pseud: pseud) {
            return cached
        }

        // Cache miss or no cache - fetch from network
        do {
            let user = try await AO3User(username: username, pseud: pseud)
            // Store in cache if available
            await cache?.setUser(user)
            return user
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to obtain user. Most likely a parsing error!", error)
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
        if let cached = await cache?.getChapter(workID: workID, chapterID: chapterID) {
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
            await cache?.setWork(parsedWork)
        }

        // Store chapter in cache
        await cache?.setChapter(chapter)
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
        var urlString = "https://archiveofourown.org/works/search?work_search%5Bquery%5D="
        urlString += AO3Utils.ao3URLEncode(query)
        urlString += "&"
        urlString += filters.buildURLParameters()

        return try await executeSearch(urlString: urlString)
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
        let (data, statusCode) = try await AO3Utils.syncRequest(urlString)

        guard statusCode == 200 else {
            throw AO3Exception.invalidStatusCode(statusCode, nil)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        let document = try SwiftSoup.parse(body)

        // Parse work metadata directly from the search result blurbs
        // This is MUCH more efficient than fetching each work individually
        // (1 request instead of N+1 requests)
        let parser = AO3SearchResultParser()
        let works = try parser.parseSearchResults(from: document)

        // Cache the parsed works if caching is enabled
        for work in works {
            await cache?.setWork(work)
        }

        return works
    }
}
