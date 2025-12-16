import Foundation

/// Mock data for testing and SwiftUI previews
/// This provides realistic sample data without making actual network requests
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public struct AO3MockData {

    // MARK: - Mock Works

    /// A sample completed work with high stats
    public static let sampleWork1: AO3Work = {
        let work = try! createMockWork(
            id: 1000001,
            title: "The Adventure Begins",
            authors: ["AuthorOne"],
            rating: .teenAndUp,
            warning: .noneApply,
            category: .gen,
            fandom: "Original Work",
            relationships: ["Character A & Character B"],
            characters: ["Character A", "Character B", "Character C"],
            tags: ["Adventure", "Friendship", "Found Family", "Angst with a Happy Ending"],
            language: "English",
            wordCount: "45,231",
            chapterCount: "15/15",
            kudos: "1,234",
            bookmarks: "567",
            hits: "12,345",
            published: "2024-01-15",
            updated: "2024-03-20"
        )
        return work
    }()

    /// A sample in-progress work with formatted content
    public static let sampleWork2: AO3Work = {
        let work = try! createMockWork(
            id: 1000002,
            title: "Coffee Shop Chronicles",
            authors: ["WriterTwo", "CoAuthor"],
            rating: .general,
            warning: .noneApply,
            category: .fm,
            fandom: "Original Work",
            relationships: ["Character D/Character E"],
            characters: ["Character D", "Character E"],
            tags: ["Coffee Shop AU", "Fluff", "Slow Burn", "First Kiss"],
            language: "English",
            wordCount: "12,458",
            chapterCount: "5/10",
            kudos: "456",
            bookmarks: "123",
            hits: "3,456",
            published: "2024-06-01",
            updated: "2024-12-01"
        )
        return work
    }()

    /// A sample mature-rated work
    public static let sampleWork3: AO3Work = {
        let work = try! createMockWork(
            id: 1000003,
            title: "Shadows and Light",
            authors: ["DarkWriter"],
            rating: .mature,
            warning: .violence,
            category: .mm,
            fandom: "Original Work",
            relationships: ["Character F/Character G"],
            characters: ["Character F", "Character G", "Character H"],
            tags: ["Enemies to Lovers", "Violence", "Angst", "Hurt/Comfort", "Happy Ending"],
            language: "English",
            wordCount: "67,890",
            chapterCount: "20/20",
            kudos: "2,345",
            bookmarks: "890",
            hits: "23,456",
            published: "2023-09-12",
            updated: "2024-02-14"
        )
        return work
    }()

    // MARK: - Mock Chapters

    /// A sample chapter with plain text
    public static let sampleChapter1: AO3Chapter = {
        let chapter = try! createMockChapter(
            workID: 1000001,
            chapterID: 2000001,
            title: "Chapter 1: New Beginnings",
            summary: "Our heroes meet for the first time.",
            content: """
            The sun was setting over the horizon, painting the sky in shades of orange and pink.

            "This is it," Character A said, adjusting their backpack. "The start of our adventure."

            Character B nodded, a small smile playing on their lips. "I'm ready. Are you?"

            "Always," came the reply.

            Together, they stepped forward into the unknown, ready to face whatever challenges lay ahead.
            """,
            notes: ["Author's Note: Thanks for reading! Updates every Monday."]
        )
        return chapter
    }()

    /// A sample chapter with formatted HTML content
    public static let sampleChapter2: AO3Chapter = {
        let chapter = try! createMockChapter(
            workID: 1000002,
            chapterID: 2000002,
            title: "Chapter 2: The First Meeting",
            summary: "A chance encounter at the coffee shop.",
            content: "\"Hi, can I get a latte?\" Character D asked.\n\nCharacter E smiled warmly. \"Of course! Coming right up.\"\n\nThere was something about that smile that made Character D's heart skip a beat.",
            contentHTML: """
            <span class="DialogueD">"Hi, can I get a latte?"</span> Character D asked.

            <span class="DialogueE">Character E smiled warmly. "Of course! <em>Coming right up.</em>"</span>

            There was something about that smile that made Character D's heart <strong>skip a beat</strong>.
            """,
            notes: ["Content Warning: Excessive caffeine consumption"]
        )
        return chapter
    }()

    /// A sample chapter with rich formatting
    public static let sampleChapterFormatted: AO3Chapter = {
        let chapter = try! createMockChapter(
            workID: 1000003,
            chapterID: 2000003,
            title: "Chapter 5: The Confrontation",
            summary: "The truth comes out.",
            content: "\"You lied to me,\" Character F said quietly.\n\n\"I had to,\" Character G replied. \"You wouldn't have understood.\"\n\n\"Try me.\"\n\nThere was a long pause before Character G spoke again. \"I was trying to protect you.\"",
            contentHTML: """
            <span class="SpeakerF">"You <em>lied</em> to me,"</span> Character F said quietly.

            <span class="SpeakerG">"I had to,"</span> Character G replied. <span class="SpeakerG">"You wouldn't have understood."</span>

            <span class="SpeakerF">"<strong>Try me.</strong>"</span>

            There was a long pause before Character G spoke again. <span class="SpeakerG">"I was trying to <em>protect</em> you."</span>
            """,
            notes: ["TW: Emotional confrontation", "Next chapter coming soon!"]
        )
        return chapter
    }()

    // MARK: - Mock Users

    /// A sample user profile
    public static let sampleUser1: AO3User = {
        let user = try! createMockUser(
            username: "AuthorOne",
            pseud: "AuthorOne",
            imageURL: "https://via.placeholder.com/100",
            location: "Somewhere in the world",
            joinDate: "2020-05-15",
            fandoms: ["Original Work", "Fantasy", "Science Fiction"],
            recentWorks: [1000001, 1000004, 1000005]
        )
        return user
    }()

    /// Another sample user profile
    public static let sampleUser2: AO3User = {
        let user = try! createMockUser(
            username: "WriterTwo",
            pseud: "WriterTwo",
            imageURL: "https://via.placeholder.com/100",
            location: "Coffee shop",
            joinDate: "2019-08-22",
            fandoms: ["Original Work", "Romance", "Slice of Life"],
            recentWorks: [1000002, 1000006]
        )
        return user
    }()

    // MARK: - Collections

    /// Array of sample works for list views
    public static let sampleWorks: [AO3Work] = [
        sampleWork1,
        sampleWork2,
        sampleWork3
    ]

    /// Array of sample chapters
    public static let sampleChapters: [AO3Chapter] = [
        sampleChapter1,
        sampleChapter2,
        sampleChapterFormatted
    ]

    /// Array of sample users
    public static let sampleUsers: [AO3User] = [
        sampleUser1,
        sampleUser2
    ]

    // MARK: - Helper Methods

    private static func createMockWork(
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
        // Create a mock work using JSON decoding
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

    private static func createMockChapter(
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

    private static func createMockUser(
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

// MARK: - SwiftUI Preview Helpers

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension AO3MockData {
    /// Example usage in SwiftUI previews:
    /// ```swift
    /// struct WorkView_Previews: PreviewProvider {
    ///     static var previews: some View {
    ///         WorkView(work: AO3MockData.sampleWork1)
    ///     }
    /// }
    /// ```
    public static var previewWork: AO3Work { sampleWork1 }
    public static var previewChapter: AO3Chapter { sampleChapterFormatted }
    public static var previewUser: AO3User { sampleUser1 }
}
#endif
