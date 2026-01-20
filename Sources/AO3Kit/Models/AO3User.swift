import Foundation
import SwiftSoup

/// Object representing an AO3 user. Exposes information such as the profile picture, works and fandoms.
public class AO3User: AO3Data, @unchecked Sendable {
    public let username: String
    public let pseud: String

    // MARK: - Dashboard Data (loaded on init)

    /// User's profile image URL
    public private(set) var imageURL: URL?

    /// Fandoms the user has written for
    public private(set) var fandoms: [String] = []

    /// Recent works shown on the user's dashboard (up to 5)
    public private(set) var recentWorks: [AO3Work] = []

    // MARK: - Counts (from sidebar)

    /// Number of works by this user
    public private(set) var worksCount: Int?

    /// Number of series by this user
    public private(set) var seriesCount: Int?

    /// Number of bookmarks by this user
    public private(set) var bookmarksCount: Int?

    /// Number of collections this user maintains
    public private(set) var collectionsCount: Int?

    /// Number of gifts received by this user
    public private(set) var giftsCount: Int?

    // MARK: - Profile Data (loaded on demand via loadProfile())

    /// Date the user joined AO3
    public private(set) var joinDate: Date?

    /// User's numeric ID on AO3
    public private(set) var userID: Int?

    /// User's bio/about text (HTML content)
    public private(set) var bio: String?

    /// List of pseuds this user has
    public private(set) var pseuds: [String]?

    /// Whether profile details have been loaded
    public private(set) var profileLoaded: Bool = false

    internal init(username: String, pseud: String) async throws {
        self.username = username
        self.pseud = pseud
        super.init()
        try await loadUserData()
    }

    /// Lightweight initializer that doesn't fetch user data
    /// Used for creating author references from search results without network requests
    internal init(username: String, pseud: String, lightweight: Bool) {
        self.username = username
        self.pseud = pseud
        super.init()
        // Don't fetch user data - just store the username/pseud
    }

    private enum CodingKeys: String, CodingKey {
        case username, pseud, imageURL, fandoms, recentWorks
        case worksCount, seriesCount, bookmarksCount, collectionsCount, giftsCount
        case joinDate, userID, bio, pseuds, profileLoaded
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        pseud = try container.decode(String.self, forKey: .pseud)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        fandoms = try container.decode([String].self, forKey: .fandoms)
        recentWorks = try container.decode([AO3Work].self, forKey: .recentWorks)
        worksCount = try container.decodeIfPresent(Int.self, forKey: .worksCount)
        seriesCount = try container.decodeIfPresent(Int.self, forKey: .seriesCount)
        bookmarksCount = try container.decodeIfPresent(Int.self, forKey: .bookmarksCount)
        collectionsCount = try container.decodeIfPresent(Int.self, forKey: .collectionsCount)
        giftsCount = try container.decodeIfPresent(Int.self, forKey: .giftsCount)
        joinDate = try container.decodeIfPresent(Date.self, forKey: .joinDate)
        userID = try container.decodeIfPresent(Int.self, forKey: .userID)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        pseuds = try container.decodeIfPresent([String].self, forKey: .pseuds)
        profileLoaded = try container.decodeIfPresent(Bool.self, forKey: .profileLoaded) ?? false
        super.init()
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(username, forKey: .username)
        try container.encode(pseud, forKey: .pseud)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(fandoms, forKey: .fandoms)
        try container.encode(recentWorks, forKey: .recentWorks)
        try container.encodeIfPresent(worksCount, forKey: .worksCount)
        try container.encodeIfPresent(seriesCount, forKey: .seriesCount)
        try container.encodeIfPresent(bookmarksCount, forKey: .bookmarksCount)
        try container.encodeIfPresent(collectionsCount, forKey: .collectionsCount)
        try container.encodeIfPresent(giftsCount, forKey: .giftsCount)
        try container.encodeIfPresent(joinDate, forKey: .joinDate)
        try container.encodeIfPresent(userID, forKey: .userID)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(pseuds, forKey: .pseuds)
        try container.encode(profileLoaded, forKey: .profileLoaded)
    }

    // MARK: - Data Loading

    private func loadUserData() async throws {
        let document = try await getDocument()

        // Parse image URL
        if let img = try document.select("img.icon").first() {
            let src = try img.attr("src")
            imageURL = URL(string: src)
        }

        // Parse fandoms
        var tempFandoms: [String] = []
        if let userFandomsDiv = try document.getElementById("user-fandoms"),
           let ol = try userFandomsDiv.select("ol.index.group").first() {
            let items = try ol.select("li")
            for item in items {
                if let link = try item.select("a").first() {
                    let fandomName = try link.text()
                    tempFandoms.append(fandomName)
                }
            }
        }
        fandoms = tempFandoms

        // Parse recent works as full AO3Work objects from blurbs
        var tempRecentWorks: [AO3Work] = []
        if let userWorksDiv = try document.getElementById("user-works") {
            let blurbs = try userWorksDiv.select("li.work.blurb.group")

            for blurb in blurbs {
                let elementId = blurb.id()
                guard elementId.hasPrefix("work_"),
                      let workID = Int(elementId.dropFirst(5)) else {
                    continue
                }

                do {
                    let work = try AO3Work(id: workID, blurb: blurb)
                    tempRecentWorks.append(work)
                } catch {
                    // Skip works that fail to parse
                    continue
                }
            }
        }
        recentWorks = tempRecentWorks

        // Parse counts from sidebar
        parseSidebarCounts(from: document)
    }

    /// Loads additional profile details (join date, bio, user ID, pseuds)
    /// Call this when you need the full profile information
    public func loadProfile() async throws {
        guard !profileLoaded else { return }

        let profileURL = "https://archiveofourown.org/users/\(username)/profile"
        let (data, statusCode) = try await AO3Utils.syncRequest(profileURL)

        guard statusCode == 200 else {
            throw AO3Exception.invalidStatusCode(statusCode, nil)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw AO3Exception.noBodyReturned
        }

        let document = try SwiftSoup.parse(body)

        // Passively validate session from the parsed page
        await AO3.validateSession(from: document)

        // Parse profile meta (join date, user ID)
        if let metaDL = try document.select("dl.meta").first() {
            let dts = try metaDL.select("dt")
            let dds = try metaDL.select("dd")

            for (index, dt) in dts.array().enumerated() {
                let dtText = try dt.text()
                guard index < dds.size() else { continue }
                let dd = dds.array()[index]
                let ddText = try dd.text()

                if dtText.contains("joined on") {
                    // Parse date in format "2025-08-24"
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    joinDate = formatter.date(from: ddText)
                } else if dtText.contains("user ID") {
                    userID = Int(ddText)
                } else if dtText.contains("pseuds") {
                    // Parse pseuds list
                    let pseudLinks = try dd.select("a")
                    pseuds = try pseudLinks.array().map { try $0.text() }
                }
            }
        }

        // Parse bio
        if let bioBlock = try document.select("div.bio blockquote.userstuff").first() {
            bio = try bioBlock.html()
        }

        // Also update counts from profile page sidebar (in case they changed)
        parseSidebarCounts(from: document)

        profileLoaded = true
    }

    /// Parse work/series/bookmark counts from the sidebar navigation
    private func parseSidebarCounts(from document: Document) {
        do {
            // Look for navigation links with counts like "Works (12)"
            let navLinks = try document.select("#dashboard ul.navigation a")

            for link in navLinks {
                let text = try link.text()

                // Extract count from text like "Works (12)"
                if let match = text.range(of: #"\((\d+)\)"#, options: .regularExpression) {
                    let countStr = text[match].dropFirst().dropLast() // Remove parentheses
                    guard let count = Int(countStr) else { continue }

                    if text.hasPrefix("Works") {
                        worksCount = count
                    } else if text.hasPrefix("Series") {
                        seriesCount = count
                    } else if text.hasPrefix("Bookmarks") {
                        bookmarksCount = count
                    } else if text.hasPrefix("Collections") {
                        collectionsCount = count
                    } else if text.hasPrefix("Gifts") {
                        giftsCount = count
                    }
                }
            }
        } catch {
            // Silently fail - counts are optional
        }
    }

    internal override func buildURL() -> String {
        return "https://archiveofourown.org/users/\(username)/pseuds/\(pseud)"
    }
}
