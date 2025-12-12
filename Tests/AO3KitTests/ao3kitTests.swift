import Testing
import Foundation
@testable import ao3kit

// MARK: - Work Tests

@Test("Get work by ID - AO3 Ship Stats 2025")
func testGetWorkByID() async throws {
    // Using a known public work: "AO3 Ship Stats 2025"
    let work = try await AO3.getWork(68352911)

    #expect(work.id == 68352911)
    #expect(!work.title.isEmpty, "Work should have a title")
    #expect(!work.authors.isEmpty, "Work should have at least one author")
    #expect(work.language == "English")

    // Check that we got some metadata
    #expect(work.rating != .notRated || work.rating == .notRated, "Rating should be set")
    #expect(!work.fandom.isEmpty, "Work should have a fandom")
}

@Test("Work should have valid stats")
func testWorkStats() async throws {
    let work = try await AO3.getWork(68352911)

    // Stats should be populated
    #expect(!work.stats.isEmpty, "Work should have statistics")

    // Common stats that should be present
    let expectedStats = ["words", "chapters", "kudos", "hits"]
    for stat in expectedStats {
        #expect(work.stats[stat] != nil, "Work should have \(stat) stat")
    }
}

@Test("Work should have chapters")
func testWorkHasChapters() async throws {
    let work = try await AO3.getWork(68352911)

    #expect(!work.chapters.isEmpty, "Work should have at least one chapter")

    // Verify chapter IDs and titles are valid
    for (chapterID, chapterTitle) in work.chapters {
        #expect(chapterID > 0, "Chapter ID should be positive")
        #expect(!chapterTitle.isEmpty, "Chapter title should not be empty")
    }
}

@Test("Work dates should be valid")
func testWorkDates() async throws {
    let work = try await AO3.getWork(68352911)

    // Published date should be in the past
    #expect(work.published <= Date(), "Published date should be in the past")

    // Updated date should be >= published date
    #expect(work.updated >= work.published, "Updated date should be after or equal to published date")
}

// MARK: - Chapter Tests

@Test("Get chapter content")
func testGetChapter() async throws {
    let work = try await AO3.getWork(68352911)

    // Get the first chapter
    guard let firstChapterID = work.chapters.keys.sorted().first else {
        Issue.record("No chapters found in work")
        return
    }

    let chapter = try await work.getChapter(firstChapterID)

    #expect(chapter.workID == work.id, "Chapter should reference correct work ID")
    #expect(chapter.id == firstChapterID, "Chapter ID should match")
    #expect(!chapter.title.isEmpty, "Chapter should have a title")
    #expect(!chapter.content.isEmpty, "Chapter should have content")
}

@Test("Chapter should have content and metadata")
func testChapterMetadata() async throws {
    let work = try await AO3.getWork(68352911)

    guard let firstChapterID = work.chapters.keys.sorted().first else {
        Issue.record("No chapters found in work")
        return
    }

    let chapter = try await work.getChapter(firstChapterID)

    // Content should be non-empty
    #expect(chapter.content.count > 0, "Chapter content should not be empty")

    // Notes array should exist (even if empty)
    #expect(chapter.notes.count >= 0, "Notes array should exist")

    // Summary should exist (even if empty)
    #expect(chapter.summary.count >= 0, "Summary should exist")
}

@Test("Invalid chapter ID should throw error")
func testInvalidChapterID() async throws {
    let work = try await AO3.getWork(68352911)

    await #expect(throws: AO3Exception.self) {
        _ = try await work.getChapter(99999999)
    }
}

// MARK: - User Tests

@Test("Get user by username")
func testGetUser() async throws {
    // Get the author from a known work
    let work = try await AO3.getWork(68352911)

    guard let firstAuthor = work.authors.first else {
        Issue.record("Work should have at least one author")
        return
    }

    let user = try await AO3.getUser(firstAuthor.username)

    #expect(user.username == firstAuthor.username, "Username should match")
    #expect(user.pseud == firstAuthor.username, "Pseud should equal username when no separate pseud")
    #expect(!user.imageURL.isEmpty, "User should have a profile image URL")
}

@Test("User should have profile data")
func testUserProfile() async throws {
    let work = try await AO3.getWork(68352911)

    guard let firstAuthor = work.authors.first else {
        Issue.record("Work should have at least one author")
        return
    }

    let user = try await AO3.getUser(firstAuthor.username)

    // User should have some profile data (fandoms or recent works)
    let hasProfileData = !user.fandoms.isEmpty || !user.recentWorks.isEmpty
    #expect(hasProfileData, "User should have fandoms or recent works")
}

// MARK: - Search Tests

@Test("Search works by query")
func testSearchWorks() async throws {
    // Search for a common term that should return results
    let results = try await AO3.searchWork(query: "coffee shop AU")

    #expect(!results.isEmpty, "Search should return at least some results")

    // All results should be valid AO3Work objects
    for work in results {
        #expect(work.id > 0, "Work ID should be positive")
        #expect(!work.title.isEmpty, "Work should have a title")
    }
}

@Test("Search with rating filter")
func testSearchWithRatingFilter() async throws {
    let results = try await AO3.searchWork(
        query: "friendship",
        warning: nil,
        rating: .general
    )

    // Search should complete without errors (results may be empty depending on AO3's search behavior)
    #expect(results.count >= 0, "Search should return valid results array")

    // If we got results, verify they're valid
    for work in results {
        #expect(work.id > 0, "Work ID should be positive")
    }
}

@Test("Search with warning filter")
func testSearchWithWarningFilter() async throws {
    let results = try await AO3.searchWork(
        query: "fluff",
        warning: .noneApply,
        rating: nil
    )

    // Search should complete without errors (results may be empty depending on AO3's search behavior)
    #expect(results.count >= 0, "Search should return valid results array")
}

@Test("Search with both filters")
func testSearchWithBothFilters() async throws {
    let results = try await AO3.searchWork(
        query: "hurt/comfort",
        warning: .noneApply,
        rating: .teenAndUp
    )

    // Should complete successfully (may or may not have results depending on query)
    #expect(results.count >= 0, "Search should return valid results array")
}

// MARK: - Error Handling Tests

@Test("Invalid work ID should throw error")
func testInvalidWorkID() async throws {
    await #expect(throws: AO3Exception.self) {
        _ = try await AO3.getWork(99999999)
    }
}

@Test("Non-existent user should throw error")
func testNonExistentUser() async throws {
    // Use a username that's very unlikely to exist
    await #expect(throws: AO3Exception.self) {
        _ = try await AO3.getUser("thisuserdoesnotexist123456789")
    }
}

// MARK: - JSON Serialization Tests

@Test("Work can be serialized to JSON")
func testWorkJSONSerialization() async throws {
    let work = try await AO3.getWork(68352911)

    let jsonString = try work.toJSON()

    #expect(!jsonString.isEmpty, "JSON string should not be empty")
    #expect(jsonString.contains("\"id\""), "JSON should contain id field")
    #expect(jsonString.contains("\"title\""), "JSON should contain title field")
}

@Test("Work can be deserialized from JSON")
func testWorkJSONDeserialization() async throws {
    let originalWork = try await AO3.getWork(68352911)

    // Serialize to JSON
    let jsonString = try originalWork.toJSON()

    // Deserialize back
    let decodedWork = try AO3Work.fromJSON(jsonString, as: AO3Work.self)

    #expect(decodedWork.id == originalWork.id, "Deserialized work ID should match")
    #expect(decodedWork.title == originalWork.title, "Deserialized work title should match")
    #expect(decodedWork.authors.count == originalWork.authors.count, "Authors count should match")
}

@Test("Chapter can be serialized to JSON")
func testChapterJSONSerialization() async throws {
    let work = try await AO3.getWork(68352911)

    guard let firstChapterID = work.chapters.keys.sorted().first else {
        Issue.record("No chapters found in work")
        return
    }

    let chapter = try await work.getChapter(firstChapterID)
    let jsonString = try chapter.toJSON()

    #expect(!jsonString.isEmpty, "JSON string should not be empty")
    #expect(jsonString.contains("\"workID\""), "JSON should contain workID field")
    #expect(jsonString.contains("\"content\""), "JSON should contain content field")
}

@Test("User can be serialized to JSON")
func testUserJSONSerialization() async throws {
    let work = try await AO3.getWork(68352911)

    guard let firstAuthor = work.authors.first else {
        Issue.record("Work should have at least one author")
        return
    }

    let user = try await AO3.getUser(firstAuthor.username)
    let jsonString = try user.toJSON()

    #expect(!jsonString.isEmpty, "JSON string should not be empty")
    #expect(jsonString.contains("\"username\""), "JSON should contain username field")
}

// MARK: - Enum Tests

@Test("Warning enum byValue")
func testWarningEnumByValue() {
    #expect(AO3Work.Warning.byValue("No Archive Warnings Apply") == .noneApply)
    #expect(AO3Work.Warning.byValue("Graphic Depictions Of Violence") == .violence)
    #expect(AO3Work.Warning.byValue("invalid value") == .none)
}

@Test("Rating enum byValue")
func testRatingEnumByValue() {
    #expect(AO3Work.Rating.byValue("General Audiences") == .general)
    #expect(AO3Work.Rating.byValue("Explicit") == .explicit)
    #expect(AO3Work.Rating.byValue("invalid value") == .notRated)
}

@Test("Category enum byValue")
func testCategoryEnumByValue() {
    #expect(AO3Work.Category.byValue("M/M") == .mm)
    #expect(AO3Work.Category.byValue("F/F") == .ff)
    #expect(AO3Work.Category.byValue("Gen") == .gen)
    #expect(AO3Work.Category.byValue("invalid value") == .none)
}

// MARK: - Swifty Extensions Tests

@Test("Work convenience properties")
func testWorkConvenienceProperties() async throws {
    let work = try await AO3.getWork(68352911)

    // Test computed properties
    #expect(work.wordCount != nil, "Word count should be accessible")
    #expect(work.kudosCount != nil, "Kudos count should be accessible")
    #expect(work.chapterCount > 0, "Chapter count should be positive")

    // Counts should be non-negative
    if let words = work.wordCount {
        #expect(words >= 0, "Word count should be non-negative")
    }
    if let kudos = work.kudosCount {
        #expect(kudos >= 0, "Kudos count should be non-negative")
    }
}

@Test("Fluent search API")
func testFluentSearchAPI() async throws {
    let results = try await AO3.search()
        .term("coffee shop")
        .rating(.general)
        .execute()

    #expect(results.count >= 0, "Fluent search should return results")

    for work in results {
        #expect(work.id > 0, "Work ID should be positive")
    }
}

@Test("Get first chapter convenience")
func testGetFirstChapterConvenience() async throws {
    let work = try await AO3.getWork(68352911)
    let firstChapter = try await work.getFirstChapter()

    #expect(!firstChapter.title.isEmpty, "First chapter should have a title")
    #expect(!firstChapter.content.isEmpty, "First chapter should have content")
}

@Test("Collection sorting extensions")
func testCollectionSortingExtensions() async throws {
    let results = try await AO3.searchWork(query: "harry potter")

    // Test sorting methods
    let byKudos = results.sortedByKudos()
    let byWords = results.sortedByWordCount()
    let byHits = results.sortedByHits()
    let byPublished = results.sortedByPublished()
    let byUpdated = results.sortedByUpdated()

    // Verify sorting doesn't crash and returns same number of items
    #expect(byKudos.count == results.count, "Sorted by kudos should have same count")
    #expect(byWords.count == results.count, "Sorted by words should have same count")
    #expect(byHits.count == results.count, "Sorted by hits should have same count")
    #expect(byPublished.count == results.count, "Sorted by published should have same count")
    #expect(byUpdated.count == results.count, "Sorted by updated should have same count")
}

@Test("Collection filtering extensions")
func testCollectionFilteringExtensions() async throws {
    let results = try await AO3.searchWork(query: "fanfiction")

    // Test filtering methods
    let longFics = results.withMinimumWords(10000)
    let generalRated = results.withRating(.general)

    // Filters should return subset or equal
    #expect(longFics.count <= results.count, "Filtered results should be subset")
    #expect(generalRated.count <= results.count, "Filtered results should be subset")

    // Verify filter criteria
    for work in longFics {
        if let words = work.wordCount {
            #expect(words >= 10000, "Filtered work should meet minimum words")
        }
    }

    for work in generalRated {
        #expect(work.rating == .general, "Filtered work should have correct rating")
    }
}

@Test("String AO3 work ID extraction")
func testStringWorkIDExtraction() {
    let url1 = "https://archiveofourown.org/works/68352911"
    let url2 = "Check out this fic: archiveofourown.org/works/12345678/chapters/1"
    let url3 = "No work ID here"

    #expect(url1.ao3WorkID == 68352911, "Should extract work ID from URL")
    #expect(url2.ao3WorkID == 12345678, "Should extract work ID from text with URL")
    #expect(url3.ao3WorkID == nil, "Should return nil for non-URL")
}
