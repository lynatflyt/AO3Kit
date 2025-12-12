import Foundation
import SwiftSoup

/// Main API class for interacting with Archive of Our Own (AO3)
public struct AO3 {

    /// Retrieves a work by its ID
    /// - Parameter workID: The work ID to retrieve
    /// - Returns: An AO3Work object containing work metadata
    /// - Throws: AO3Exception if the work cannot be retrieved
    public static func getWork(_ workID: Int) async throws -> AO3Work {
        do {
            return try await AO3Work(id: workID)
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
        do {
            return try await AO3User(username: username, pseud: username)
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to obtain user. Most likely a parsing error!", error)
        }
    }

    /// Retrieves a user with a specific pseudonym
    /// - Parameters:
    ///   - username: The username
    ///   - pseud: The pseudonym
    /// - Returns: An AO3User object containing user information
    /// - Throws: AO3Exception if the user cannot be retrieved
    public static func getPseud(username: String, pseud: String) async throws -> AO3User {
        do {
            return try await AO3User(username: username, pseud: pseud)
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to obtain user. Most likely a parsing error!", error)
        }
    }

    /// Searches for works matching the given query
    /// - Parameters:
    ///   - query: The search query
    ///   - warning: Optional warning filter
    ///   - rating: Optional rating filter
    /// - Returns: Array of AO3Work objects matching the search criteria
    /// - Throws: AO3Exception if the search fails
    public static func searchWork(
        query: String,
        warning: AO3Work.Warning? = nil,
        rating: AO3Work.Rating? = nil
    ) async throws -> [AO3Work] {
        do {
            return try await performSearch(query: query, warning: warning, rating: rating)
        } catch let error as AO3Exception {
            throw error
        } catch {
            throw AO3Exception.parsingError("Failed to search for works! Most likely a parsing error!", error)
        }
    }

    private static func performSearch(
        query: String,
        warning: AO3Work.Warning?,
        rating: AO3Work.Rating?
    ) async throws -> [AO3Work] {
        var urlString = "https://archiveofourown.org/works/search?utf8=%E2%9C%93&work_search%5Bquery%5D="
        urlString += AO3Utils.ao3URLEncode(query)

        if let warning = warning {
            urlString += " AND \""
            urlString += warning.rawValue.lowercased()
            urlString += "\""
        }

        if let rating = rating {
            urlString += " AND \""
            urlString += rating.rawValue.lowercased()
            urlString += "\""
        }

        let (data, statusCode) = try await AO3Utils.syncRequest(urlString)

        guard statusCode == 200 else {
            throw AO3Exception.invalidStatusCode(statusCode, nil)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        let document = try SwiftSoup.parse(body)

        // Find the results list
        guard let resultList = try document.select("ol.work.index.group").first() else {
            return []
        }

        let results = try resultList.select("li.work.blurb.group")

        // Extract work IDs from the results
        var workIDs: [Int] = []
        for result in results {
            let id = result.id()
            if id.hasPrefix("work_") {
                let idString = String(id.dropFirst(5))
                if let workID = Int(idString) {
                    workIDs.append(workID)
                }
            }
        }

        // Fetch each work (in parallel for better performance)
        return await withTaskGroup(of: AO3Work?.self) { group in
            for workID in workIDs {
                group.addTask {
                    do {
                        return try await getWork(workID)
                    } catch {
                        print("Error fetching work \(workID): \(error)")
                        return nil
                    }
                }
            }

            var works: [AO3Work] = []
            for await work in group {
                if let work = work {
                    works.append(work)
                }
            }
            return works
        }
    }
}
