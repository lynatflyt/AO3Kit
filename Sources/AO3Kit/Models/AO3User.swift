import Foundation
import SwiftSoup

/// Object representing an AO3 user. Exposes information such as the profile picture, works and fandoms.
public class AO3User: AO3Data, @unchecked Sendable {
    public let username: String
    public let pseud: String
    public private(set) var imageURL: String = ""
    public private(set) var fandoms: [String] = []
    public private(set) var recentWorks: [Int] = []

    internal init(username: String, pseud: String) async throws {
        self.username = username
        self.pseud = pseud
        super.init()
        try await loadUserData()
    }

    private enum CodingKeys: String, CodingKey {
        case username, pseud, imageURL, fandoms, recentWorks
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try container.decode(String.self, forKey: .username)
        pseud = try container.decode(String.self, forKey: .pseud)
        imageURL = try container.decode(String.self, forKey: .imageURL)
        fandoms = try container.decode([String].self, forKey: .fandoms)
        recentWorks = try container.decode([Int].self, forKey: .recentWorks)
        super.init()
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(username, forKey: .username)
        try container.encode(pseud, forKey: .pseud)
        try container.encode(imageURL, forKey: .imageURL)
        try container.encode(fandoms, forKey: .fandoms)
        try container.encode(recentWorks, forKey: .recentWorks)
    }

    private func loadUserData() async throws {
        let document = try await getDocument()

        // Parse image URL
        if let img = try document.select("img.icon").first() {
            imageURL = try img.attr("src")
        }

        // Parse fandoms
        var tempFandoms: [String] = []
        if let userFandomsDiv = try document.getElementById("user-fandoms"),
           let ol = try userFandomsDiv.select("ol.index.group").first() {
            let items = try ol.select("li")
            for item in items {
                if let link = try item.select("a").first() {
                    let fandomName = try link.html()
                    tempFandoms.append(fandomName)
                }
            }
        }
        fandoms = tempFandoms

        // Parse recent works
        var tempRecentWorks: [Int] = []
        if let userWorksDiv = try document.getElementById("user-works") {
            let headers = try userWorksDiv.select(".header")
            for header in headers {
                if let h4 = try header.select("h4").first(),
                   let link = try h4.select("a").first() {
                    let href = try link.attr("href")
                    let workIDString = href.replacingOccurrences(of: "/works/", with: "")
                    if let workID = Int(workIDString) {
                        tempRecentWorks.append(workID)
                    }
                }
            }
        }
        recentWorks = tempRecentWorks
    }

    internal override func buildURL() -> String {
        return "https://archiveofourown.org/users/\(username)/pseuds/\(pseud)"
    }
}
