import Foundation
import SwiftSoup

/// Superclass for all other data classes. Contains utility methods to get a SwiftSoup document,
/// convert to JSON, and build URLs.
open class AO3Data: Codable, @unchecked Sendable {
    internal var errorMappings: [Int: String] = [:]

    /// Method used in subclasses to get the document
    /// - Returns: A SwiftSoup parsed Document
    /// - Throws: AO3Exception if fetching or parsing fails
    internal func getDocument() async throws -> Document {
        return try await getDocument(try buildURL(), depth: 0)
    }

    /// Internal method to retrieve the page.
    /// - Parameters:
    ///   - url: The URL to get
    ///   - depth: The number of passes (used when dealing with adult works)
    /// - Returns: A SwiftSoup parsed Document
    /// - Throws: AO3Exception if fetching or parsing fails
    private func getDocument(_ url: String, depth: Int) async throws -> Document {
        let (data, statusCode) = try await AO3Utils.syncRequest(url)

        if statusCode != 200 {
            if let message = errorMappings[statusCode] {
                throw AO3Exception.invalidStatusCode(statusCode, message)
            } else {
                throw AO3Exception.invalidStatusCode(statusCode, nil)
            }
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        // Check for adult content confirmation
        if body.range(of: "This work could have adult content", options: .caseInsensitive) != nil {
            if depth == 9 {
                throw AO3Exception.tooManyRedirects
            }
            // Properly append view_adult=true, avoiding duplicates
            let adultURL = Self.appendViewAdult(to: url)
            return try await getDocument(adultURL, depth: depth + 1)
        }

        // Check for registered users only
        if body.range(of: "This work is only available to registered users", options: .caseInsensitive) != nil {
            throw AO3Exception.registeredUsersOnly
        }

        let document = try SwiftSoup.parse(body)

        // Passively validate session from every parsed page
        await AO3.validateSession(from: document)

        return document
    }

    /// Converts this object to JSON
    /// - Returns: A JSON string representation of the object
    /// - Throws: EncodingError if JSON encoding fails
    public func toJSON() throws -> String {
        let data = try AO3Utils.jsonEncoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Converts JSON back into the object
    /// - Parameters:
    ///   - json: JSON string to decode
    ///   - type: The type to decode to
    /// - Returns: Decoded object
    /// - Throws: DecodingError if JSON decoding fails
    public static func fromJSON<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw AO3Exception.generic("Invalid JSON string")
        }
        return try AO3Utils.jsonDecoder.decode(type, from: data)
    }

    /// Builds a URL that can be queried for information
    /// - Returns: The URL string
    /// - Throws: AO3Exception if buildURL is not implemented by subclass
    internal func buildURL() throws -> String {
        throw AO3Exception.generic("buildURL() must be implemented by subclasses of AO3Data")
    }

    /// Appends view_adult=true to a URL, handling existing query parameters correctly
    /// - Parameter url: The original URL
    /// - Returns: URL with view_adult=true properly appended
    private static func appendViewAdult(to url: String) -> String {
        // If already has view_adult=true, return as-is
        if url.contains("view_adult=true") {
            return url
        }

        // Use proper separator based on existing query string
        if url.contains("?") {
            return "\(url)&view_adult=true"
        } else {
            return "\(url)?view_adult=true"
        }
    }
}
