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

    /// Performs a synchronous HTTP GET request and detects redirects
    /// - Parameter urlString: The URL to request
    /// - Returns: Tuple containing the response data, HTTP status code, and whether the request was redirected
    /// - Throws: AO3Exception if the request fails
    /// - Note: Useful for detecting auth redirects (302 to login page)
    static func syncRequestWithRedirectInfo(_ urlString: String) async throws -> (Data, Int, Bool) {
        guard let url = URL(string: urlString) else {
            throw AO3Exception.generic("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
                        forHTTPHeaderField: "User-Agent")

        // Use a custom delegate to detect redirects
        let delegate = RedirectDetectionDelegate()
        let delegateSession = URLSession(configuration: session.configuration, delegate: delegate, delegateQueue: nil)

        let (data, response) = try await delegateSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AO3Exception.generic("Invalid response type")
        }

        return (data, httpResponse.statusCode, delegate.wasRedirected)
    }

    /// Performs a synchronous HTTP POST request with form data
    /// - Parameters:
    ///   - urlString: The URL to request
    ///   - formData: Dictionary of form fields to submit
    /// - Returns: Tuple containing the response data and HTTP status code
    /// - Throws: AO3Exception if the request fails
    static func postRequest(_ urlString: String, formData: [String: String]) async throws -> (Data, Int) {
        guard let url = URL(string: urlString) else {
            throw AO3Exception.generic("Invalid URL: \(urlString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
                        forHTTPHeaderField: "User-Agent")
        request.setValue("application/x-www-form-urlencoded",
                        forHTTPHeaderField: "Content-Type")

        // Encode form data as URL-encoded body
        let bodyParts = formData.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

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

/// Delegate that tracks whether a redirect occurred during a request
private final class RedirectDetectionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let _wasRedirected = AtomicBool()

    var wasRedirected: Bool {
        _wasRedirected.value
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        _wasRedirected.set(true)
        // Allow the redirect to proceed
        completionHandler(request)
    }
}

/// Thread-safe atomic boolean for Sendable conformance
private final class AtomicBool: @unchecked Sendable {
    private var _value = false
    private let lock = NSLock()

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }
}
