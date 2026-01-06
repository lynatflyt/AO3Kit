import Foundation

/// Various utility methods for HTTP requests and URL handling
internal enum AO3Utils {

    /// Shared URLSession with cookie storage
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        return URLSession(configuration: config)
    }()

    /// Performs a synchronous HTTP GET request
    /// - Parameter urlString: The URL to request
    /// - Returns: Tuple containing the response data and HTTP status code
    /// - Throws: AO3Exception if the request fails
    static func syncRequest(_ urlString: String) async throws -> (Data, Int) {
        guard let url = URL(string: urlString) else {
            throw AO3Exception.generic("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
                        forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AO3Exception.generic("Invalid response type")
        }

        return (data, httpResponse.statusCode)
    }

    /// Encodes a string for use in AO3 URLs
    /// - Parameter string: The string to encode
    /// - Returns: URL-encoded string with AO3-specific formatting
    static func ao3URLEncode(_ string: String) -> String {
        var encoded = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
        encoded = encoded.replacingOccurrences(of: "+", with: "%20")
        encoded = encoded.replacingOccurrences(of: "%2F", with: "*s*")
        encoded = encoded.replacingOccurrences(of: "%2f", with: "*s*")
        return encoded
    }

    /// JSON encoder with pretty printing
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// JSON decoder
    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
