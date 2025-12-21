import Foundation

/// Sample works for testing and SwiftUI previews
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension AO3MockData {
    /// A sample completed work with high stats
    public static let sampleWork1: AO3Work = {
        let work = try! AO3MockDataFactory.createMockWork(
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
        let work = try! AO3MockDataFactory.createMockWork(
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
        let work = try! AO3MockDataFactory.createMockWork(
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

    /// Array of sample works for list views
    public static let sampleWorks: [AO3Work] = [
        sampleWork1,
        sampleWork2,
        sampleWork3
    ]
}
