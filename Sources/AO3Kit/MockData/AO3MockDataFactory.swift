import Foundation

/// Factory methods for creating mock AO3 data for testing
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
internal struct AO3MockDataFactory {
    static func createMockWork(
        id: Int,
        title: String,
        authors: [String],
        rating: AO3Rating,
        warning: AO3Warning,
        category: AO3Category,
        fandom: String,
        relationships: [String],
        characters: [String],
        tags: [String],
        language: String,
        wordCount: String,
        chapterCount: String,
        kudos: String,
        bookmarks: String,
        hits: String,
        published: String,
        updated: String
    ) throws -> AO3Work {
        let json: [String: Any] = [
            "id": id,
            "title": title,
            "authors": authors.map { username in
                [
                    "username": username,
                    "pseud": username,
                    "imageURL": "",
                    "location": "",
                    "joinDate": "",
                    "fandoms": [],
                    "recentWorks": []
                ]
            },
            "archiveWarning": warning.rawValue,
            "rating": rating.rawValue,
            "category": category.rawValue,
            "fandom": fandom,
            "relationships": relationships,
            "characters": characters,
            "additionalTags": tags,
            "language": language,
            "stats": [
                "words": wordCount,
                "chapters": chapterCount,
                "kudos": kudos,
                "bookmarks": bookmarks,
                "hits": hits
            ],
            "published": published,
            "updated": updated,
            "chapters": ["\(id)": title]
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted({
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }())

        return try decoder.decode(AO3Work.self, from: data)
    }

    static func createMockChapter(
        workID: Int,
        chapterID: Int,
        title: String,
        summary: String,
        content: String,
        contentHTML: String? = nil,
        notes: [String]
    ) throws -> AO3Chapter {
        let json: [String: Any] = [
            "workID": workID,
            "id": chapterID,
            "title": title,
            "summary": summary,
            "content": content,
            "contentHTML": contentHTML ?? content,
            "notes": notes
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AO3Chapter.self, from: data)
    }

    static func createMockUser(
        username: String,
        pseud: String,
        imageURL: String,
        location: String,
        joinDate: String,
        fandoms: [String],
        recentWorks: [Int]
    ) throws -> AO3User {
        let json: [String: Any] = [
            "username": username,
            "pseud": pseud,
            "imageURL": imageURL,
            "location": location,
            "joinDate": joinDate,
            "fandoms": fandoms,
            "recentWorks": recentWorks
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(AO3User.self, from: data)
    }
}
