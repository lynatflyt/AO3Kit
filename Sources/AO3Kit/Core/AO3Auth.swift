import Foundation
import SwiftSoup

/// Authentication state for AO3
public enum AO3AuthState: Sendable, Equatable {
    case loggedOut
    case loggedIn(username: String)

    public var isLoggedIn: Bool {
        if case .loggedIn = self { return true }
        return false
    }

    public var username: String? {
        if case .loggedIn(let username) = self { return username }
        return nil
    }
}

// MARK: - Notifications

public extension Notification.Name {
    /// Posted when the AO3 session expires (detected passively during page loads)
    static let ao3SessionExpired = Notification.Name("AO3SessionExpired")

    /// Posted when AO3 auth state changes for any reason
    static let ao3AuthStateChanged = Notification.Name("AO3AuthStateChanged")
}

/// Actor for managing AO3 authentication
public actor AO3Auth {
    public static let shared = AO3Auth()

    private static let loginURL = "https://archiveofourown.org/users/login"
    private static let ao3Domain = "archiveofourown.org"

    private(set) public var state: AO3AuthState = .loggedOut

    /// The current CSRF token extracted from AO3 pages
    /// This is refreshed whenever we fetch an AO3 page (session check, etc.)
    private(set) public var csrfToken: String?

    private init() {}

    // MARK: - Login

    /// Attempts to log in to AO3 with the given credentials
    /// - Parameters:
    ///   - username: The username or email
    ///   - password: The password
    ///   - rememberMe: Whether to persist the session (default true)
    /// - Throws: AO3Exception if login fails
    public func login(username: String, password: String, rememberMe: Bool = true) async throws {
        // Step 1: GET the login page to extract CSRF token
        let csrfToken = try await extractCSRFToken()

        // Step 2: POST the login form
        var formData: [String: String] = [
            "authenticity_token": csrfToken,
            "user[login]": username,
            "user[password]": password,
            "commit": "Log In"
        ]

        if rememberMe {
            formData["user[remember_me]"] = "1"
        }

        // Step 2: POST the login form
        let (data, statusCode) = try await AO3Utils.postRequest(Self.loginURL, formData: formData)

        // Step 3: Parse response
        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        // Check for error messages in response
        let document = try SwiftSoup.parse(body)

        // Check for flash messages
        let allFlash = try document.select("div.flash")
        for flash in allFlash {
            let flashText = try flash.text()

            // "Already logged in" means success - extract username and return
            if flashText.contains("already logged in") {
                if let extractedUsername = try extractUsernameFromPage(document) {
                    state = .loggedIn(username: extractedUsername)
                    return
                }
            }
        }

        // AO3 returns error messages in a div with class "flash error"
        if let errorDiv = try document.select("div.flash.error").first() {
            let errorMessage = try errorDiv.text()
            throw AO3Exception.authenticationFailed(errorMessage)
        }

        // Check if we're now logged in by looking for the logged-in user greeting
        if let extractedUsername = try extractUsernameFromPage(document) {
            state = .loggedIn(username: extractedUsername)
            return
        }

        // If status code indicates redirect (302) and no error, check cookies
        if statusCode == 302 || statusCode == 200 {
            // Try to validate session via cookies
            if let detectedUsername = await checkSessionFromCookies() {
                state = .loggedIn(username: detectedUsername)
                return
            }
        }

        // If we get here without finding an error or a successful login indicator
        throw AO3Exception.authenticationFailed("Login failed for unknown reason. Status: \(statusCode)")
    }

    // MARK: - Logout

    /// Logs out by clearing AO3 cookies
    public func logout() async {
        clearAO3Cookies()
        state = .loggedOut
    }

    // MARK: - Bookmarks

    /// Creates a bookmark for a work on AO3
    /// - Parameters:
    ///   - bookmark: The bookmark data to create
    /// - Returns: The result of the bookmark operation
    /// - Throws: AO3Exception if not authenticated or if the request fails
    public func createBookmark(_ bookmark: AO3Bookmark) async throws -> AO3BookmarkResult {
        guard case .loggedIn = state else {
            throw AO3Exception.notAuthenticated
        }

        // Step 1: Fetch the work page to get CSRF token and pseud_id from bookmark form
        let workURL = "https://archiveofourown.org/works/\(bookmark.workID)"
        let (data, statusCode) = try await AO3Utils.syncRequest(workURL)

        guard statusCode == 200 else {
            throw AO3Exception.invalidStatusCode(statusCode, "Failed to load work page")
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        let document = try SwiftSoup.parse(body)

        // Check if already bookmarked (form would be for editing, not creating)
        if try document.select("a.bookmark_form_placement_open:contains(Edit)").first() != nil {
            return .alreadyExists
        }

        // Parse bookmark form for CSRF token and pseud_id
        guard let form = try document.select("form[action*='/bookmarks']").first() else {
            throw AO3Exception.generic("Bookmark form not found - you may need to log in")
        }

        guard let csrfInput = try form.select("input[name='authenticity_token']").first(),
              let csrfToken = try? csrfInput.attr("value"),
              !csrfToken.isEmpty else {
            throw AO3Exception.csrfTokenNotFound
        }

        guard let pseudInput = try form.select("input[name='bookmark[pseud_id]']").first(),
              let pseudID = try? pseudInput.attr("value"),
              !pseudID.isEmpty else {
            throw AO3Exception.generic("Could not find pseud_id - you may need to log in")
        }

        // Step 2: POST the bookmark
        let formData = bookmark.toFormData(pseudID: pseudID, csrfToken: csrfToken)
        let bookmarkURL = "https://archiveofourown.org/works/\(bookmark.workID)/bookmarks"

        let (responseData, responseStatus) = try await AO3Utils.postRequest(bookmarkURL, formData: formData)

        // AO3 typically redirects on success (302) or returns 200 with the bookmark page
        if responseStatus == 302 || responseStatus == 200 {
            // Check response for success indicators
            if let responseBody = String(data: responseData, encoding: .utf8) {
                let responseDoc = try SwiftSoup.parse(responseBody)

                // Check for error messages
                if let errorDiv = try responseDoc.select("div.flash.error").first() {
                    let errorMessage = try errorDiv.text()
                    throw AO3Exception.generic("Bookmark failed: \(errorMessage)")
                }
            }
            return .created
        }

        throw AO3Exception.invalidStatusCode(responseStatus, "Failed to create bookmark")
    }

    /// Deletes a bookmark for a work
    /// - Parameter workID: The work ID to remove the bookmark from
    /// - Throws: AO3Exception if not authenticated or if the request fails
    public func deleteBookmark(workID: Int) async throws {
        guard case .loggedIn = state else {
            throw AO3Exception.notAuthenticated
        }

        // First fetch the bookmarks page to find the bookmark ID and delete form
        // This is more complex - AO3 requires finding the specific bookmark ID
        // For now, we'll implement this when we have the user's bookmarks list
        throw AO3Exception.generic("deleteBookmark not yet implemented")
    }

    // MARK: - Kudos

    /// Leave kudos on a work
    /// - Parameters:
    ///   - workID: The ID of the work
    /// - Returns: True if kudos were left successfully or were already left
    /// - Note: This method automatically fetches a fresh CSRF token before making the request
    public func leaveKudos(workID: Int) async throws -> Bool {
        // Always fetch a fresh CSRF token to avoid stale token issues
        let token = try await refreshCSRFToken()

        let url = URL(string: "https://archiveofourown.org/kudos.js")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Headers
        request.addValue(token, forHTTPHeaderField: "X-CSRF-Token")
        request.addValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        // Manually add cookies
        let cookies = getAO3Cookies()
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")

        // Form URL-encoded body
        let bodyParameters = [
            "authenticity_token": token,
            "kudo[commentable_id]": String(workID),
            "kudo[commentable_type]": "Work"
        ]
        let bodyString = bodyParameters
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8, allowLossyConversion: true)

        // Create a fresh session for the request
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)

        let (data, response) = try await session.data(for: request)
        session.finishTasksAndInvalidate()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AO3Exception.parsingError("Failed to parse response", nil)
        }

        // 201 Created: Success
        if httpResponse.statusCode == 201 {
            return true
        }

        // 422 Unprocessable Entity: Could be "already left kudos" OR "auth error"
        if httpResponse.statusCode == 422 {
            if let responseBody = String(data: data, encoding: .utf8),
               responseBody.contains("auth_error") {
                throw AO3Exception.csrfTokenExpired
            }
            // Otherwise, 422 means already left kudos = success
            return true
        }

        throw AO3Exception.invalidStatusCode(httpResponse.statusCode, "Failed to leave kudos")
    }

    // MARK: - Session Validation

    /// Checks if there's an existing valid session and updates state accordingly
    /// - Returns: The current auth state after checking
    @discardableResult
    public func checkExistingSession() async -> AO3AuthState {
        // First check if we have AO3 cookies
        guard hasAO3Cookies() else {
            state = .loggedOut
            return state
        }

        // Try to fetch a page that shows login status
        do {
            let (data, statusCode) = try await AO3Utils.syncRequest("https://archiveofourown.org")

            guard statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else {
                state = .loggedOut
                return state
            }

            let document = try SwiftSoup.parse(body)

            // Extract and store CSRF token from meta tags
            if let token = extractCSRFTokenFromPage(document) {
                csrfToken = token
            }

            // Use the shared username extraction logic
            if let username = try extractUsernameFromPage(document) {
                state = .loggedIn(username: username)
            } else {
                state = .loggedOut
            }
        } catch {
            state = .loggedOut
        }

        return state
    }

    /// Refreshes the CSRF token by fetching the AO3 homepage
    /// Call this before making actions that require a fresh token (like leaving kudos)
    public func refreshCSRFToken() async throws -> String {
        let (data, statusCode) = try await AO3Utils.syncRequest("https://archiveofourown.org")

        guard statusCode == 200,
              let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.invalidStatusCode(statusCode, "Failed to fetch AO3 page for CSRF token")
        }

        let document = try SwiftSoup.parse(body)

        guard let token = extractCSRFTokenFromPage(document) else {
            throw AO3Exception.csrfTokenNotFound
        }

        csrfToken = token
        return token
    }

    // MARK: - Private Helpers

    private func extractUsernameFromPage(_ document: Document) throws -> String? {
        // Method 1: Look for "Hi, username!" in nav#greeting dropdown toggle
        // The actual HTML structure is: <nav id="greeting"> ... <a class="dropdown-toggle">Hi, username!</a>
        if let greetingLink = try document.select("nav#greeting a.dropdown-toggle").first() {
            let greetingText = try greetingLink.text()

            // Parse "Hi, username!" pattern
            if greetingText.hasPrefix("Hi, ") {
                let afterHi = greetingText.dropFirst(4) // Remove "Hi, "
                // Username ends at "!" or first space after the name
                if let exclamationIndex = afterHi.firstIndex(of: "!") {
                    let username = String(afterHi[..<exclamationIndex])
                    return username
                }
            }
        }

        // Method 2: Look for link to user profile in greeting nav
        if let greetingLink = try document.select("nav#greeting a[href*='/users/']").first() {
            let href = try greetingLink.attr("href")
            // Extract username from /users/username path
            if let match = href.range(of: "/users/([^/]+)", options: .regularExpression) {
                let fullMatch = String(href[match])
                let username = fullMatch.replacingOccurrences(of: "/users/", with: "")
                return username
            }
        }

        // Method 3: Look for My Dashboard link which contains username
        // The link text is "My Dashboard" and href is /users/username
        if let dashboardLink = try document.select("a:contains(My Dashboard)[href*='/users/']").first() {
            let href = try dashboardLink.attr("href")
            // Extract from /users/username
            let components = href.split(separator: "/")
            if components.count >= 2, let usersIndex = components.firstIndex(of: "users") {
                let usernameIndex = components.index(after: usersIndex)
                if usernameIndex < components.endIndex {
                    return String(components[usernameIndex])
                }
            }
        }

        return nil
    }

    /// Extracts the CSRF token from the meta tags in an AO3 page
    /// <meta name="csrf-token" content="..."/>
    private func extractCSRFTokenFromPage(_ document: Document) -> String? {
        do {
            if let metaTag = try document.select("meta[name=csrf-token]").first() {
                let token = try metaTag.attr("content")
                if !token.isEmpty {
                    return token
                }
            }
        } catch {
            // Silently fail - token extraction is best-effort
        }
        return nil
    }

    // MARK: - Passive Session Validation

    /// Validates the current session by checking if a username was found on the page.
    /// Call this after parsing any AO3 HTML page to passively detect session expiration.
    /// If we think we're logged in but no username was found, updates state to logged out.
    /// - Parameter foundUsername: The username extracted from the page, or nil if not found
    public func validateSessionWithUsername(_ foundUsername: String?) {
        // Only check if we think we're logged in
        guard case .loggedIn(let expectedUsername) = state else { return }

        if let foundUsername = foundUsername {
            // Session still valid - optionally verify username matches
            if foundUsername != expectedUsername {
                state = .loggedIn(username: foundUsername)
                postAuthStateChanged()
            }
        } else {
            // No greeting found - session has expired
            state = .loggedOut
            postSessionExpired()
        }
    }

    /// Extracts username from a parsed AO3 page (static, can be called outside actor)
    /// - Parameter document: The parsed HTML document
    /// - Returns: The username if found, nil otherwise
    public static func extractUsername(from document: Document) -> String? {
        do {
            // Method 1: Look for "Hi, username!" in nav#greeting dropdown toggle
            if let greetingLink = try document.select("nav#greeting a.dropdown-toggle").first() {
                let greetingText = try greetingLink.text()

                if greetingText.hasPrefix("Hi, ") {
                    let afterHi = greetingText.dropFirst(4)
                    if let exclamationIndex = afterHi.firstIndex(of: "!") {
                        return String(afterHi[..<exclamationIndex])
                    }
                }
            }

            // Method 2: Look for link to user profile in greeting nav
            if let greetingLink = try document.select("nav#greeting a[href*='/users/']").first() {
                let href = try greetingLink.attr("href")
                if let match = href.range(of: "/users/([^/]+)", options: .regularExpression) {
                    let fullMatch = String(href[match])
                    return fullMatch.replacingOccurrences(of: "/users/", with: "")
                }
            }

            // Method 3: Look for My Dashboard link
            if let dashboardLink = try document.select("a:contains(My Dashboard)[href*='/users/']").first() {
                let href = try dashboardLink.attr("href")
                let components = href.split(separator: "/")
                if components.count >= 2, let usersIndex = components.firstIndex(of: "users") {
                    let usernameIndex = components.index(after: usersIndex)
                    if usernameIndex < components.endIndex {
                        return String(components[usernameIndex])
                    }
                }
            }
        } catch {
            // Silently fail - username extraction is best-effort
        }

        return nil
    }

    /// Posts notification that auth state changed
    private func postAuthStateChanged() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .ao3AuthStateChanged, object: nil)
        }
    }

    /// Posts notification that session expired (subset of state changed)
    private func postSessionExpired() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .ao3SessionExpired, object: nil)
            NotificationCenter.default.post(name: .ao3AuthStateChanged, object: nil)
        }
    }

    private func extractCSRFToken() async throws -> String {
        let (data, statusCode) = try await AO3Utils.syncRequest(Self.loginURL)

        guard statusCode == 200 else {
            throw AO3Exception.invalidStatusCode(statusCode, "Failed to load login page")
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        let document = try SwiftSoup.parse(body)

        // Find the authenticity_token input
        guard let tokenInput = try document.select("input[name=authenticity_token]").first(),
              let token = try? tokenInput.attr("value"),
              !token.isEmpty else {
            throw AO3Exception.csrfTokenNotFound
        }

        return token
    }

    private func checkSessionFromCookies() async -> String? {
        // Make a quick request to check if we're logged in
        do {
            let (data, statusCode) = try await AO3Utils.syncRequest("https://archiveofourown.org")

            guard statusCode == 200,
                  let body = String(data: data, encoding: .utf8) else {
                return nil
            }

            let document = try SwiftSoup.parse(body)

            // Use the shared username extraction logic
            if let username = try extractUsernameFromPage(document) {
                return username
            }

        } catch {
            return nil
        }

        return nil
    }

    private func hasAO3Cookies() -> Bool {
        guard let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: "https://\(Self.ao3Domain)")!) else {
            return false
        }

        // Look for session-related cookies
        return cookies.contains { cookie in
            cookie.name == "_otwarchive_session" || cookie.name == "user_credentials"
        }
    }

    private func clearAO3Cookies() {
        guard let url = URL(string: "https://\(Self.ao3Domain)"),
              let cookies = HTTPCookieStorage.shared.cookies(for: url) else {
            return
        }

        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    // MARK: - Cookie Inspection (for debugging)

    /// Returns all AO3-related cookies for debugging purposes
    public func getAO3Cookies() -> [HTTPCookie] {
        guard let url = URL(string: "https://\(Self.ao3Domain)"),
              let cookies = HTTPCookieStorage.shared.cookies(for: url) else {
            return []
        }
        return cookies
    }
}

// MARK: - Convenience Extensions on AO3

public extension AO3 {
    /// The current authentication state
    static var authState: AO3AuthState {
        get async {
            await AO3Auth.shared.state
        }
    }

    /// Logs in to AO3 with the given credentials
    /// - Parameters:
    ///   - username: The username or email
    ///   - password: The password
    ///   - rememberMe: Whether to persist the session
    static func login(username: String, password: String, rememberMe: Bool = true) async throws {
        try await AO3Auth.shared.login(username: username, password: password, rememberMe: rememberMe)
    }

    /// Logs out from AO3
    static func logout() async {
        await AO3Auth.shared.logout()
    }

    /// Checks if there's an existing valid session
    /// - Returns: The current auth state
    @discardableResult
    static func checkSession() async -> AO3AuthState {
        await AO3Auth.shared.checkExistingSession()
    }

    /// Validates the current session from a parsed HTML page.
    /// Call this after parsing any AO3 page to passively detect session expiration.
    static func validateSession(from document: Document) async {
        // Extract username outside the actor boundary to avoid Sendable issues
        let username = AO3Auth.extractUsername(from: document)
        await AO3Auth.shared.validateSessionWithUsername(username)
    }

    // MARK: - Bookmarks

    /// Creates a bookmark for a work on AO3
    /// - Parameter bookmark: The bookmark data to create
    /// - Returns: The result of the bookmark operation
    /// - Throws: AO3Exception if not authenticated or if the request fails
    @discardableResult
    static func createBookmark(_ bookmark: AO3Bookmark) async throws -> AO3BookmarkResult {
        try await AO3Auth.shared.createBookmark(bookmark)
    }

    /// Creates a simple bookmark for a work (no notes/tags, public, not a rec)
    /// - Parameter workID: The work ID to bookmark
    /// - Returns: The result of the bookmark operation
    /// - Throws: AO3Exception if not authenticated or if the request fails
    @discardableResult
    static func bookmarkWork(_ workID: Int) async throws -> AO3BookmarkResult {
        try await createBookmark(AO3Bookmark(workID: workID))
    }

    /// Deletes a bookmark for a work
    /// - Parameter workID: The work ID to remove the bookmark from
    /// - Throws: AO3Exception if not authenticated or if the request fails
    static func deleteBookmark(workID: Int) async throws {
        try await AO3Auth.shared.deleteBookmark(workID: workID)
    }
    
    /// Leave kudos on a work
    /// - Parameters:
    ///   - workID: The ID of the work
    /// - Returns: True if kudos were left successfully or were already left
    /// - Note: This method automatically fetches a fresh CSRF token before making the request
    @discardableResult
    static func leaveKudos(workID: Int) async throws -> Bool {
        try await AO3Auth.shared.leaveKudos(workID: workID)
    }

    /// Refreshes the stored CSRF token by fetching the AO3 homepage
    /// - Returns: The fresh CSRF token
    @discardableResult
    static func refreshCSRFToken() async throws -> String {
        try await AO3Auth.shared.refreshCSRFToken()
    }
}
