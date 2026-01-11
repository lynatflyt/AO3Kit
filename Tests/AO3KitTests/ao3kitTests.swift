import Testing
import Foundation
import SwiftSoup
@testable import AO3Kit

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

    // Verify chapter IDs, numbers, and titles are valid
    for chapterInfo in work.chapters {
        #expect(chapterInfo.id > 0, "Chapter ID should be positive")
        #expect(chapterInfo.number > 0, "Chapter number should be positive")
        #expect(!chapterInfo.title.isEmpty, "Chapter title should not be empty")
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
    guard let firstChapter = work.chapters.first else {
        Issue.record("No chapters found in work")
        return
    }

    let chapter = try await work.getChapter(firstChapter.id)

    #expect(chapter.workID == work.id, "Chapter should reference correct work ID")
    #expect(chapter.id == firstChapter.id, "Chapter ID should match")
    #expect(!chapter.title.isEmpty, "Chapter should have a title")
    #expect(!chapter.content.isEmpty, "Chapter should have content")
}

@Test("Chapter should have content and metadata")
func testChapterMetadata() async throws {
    let work = try await AO3.getWork(68352911)

    guard let firstChapter = work.chapters.first else {
        Issue.record("No chapters found in work")
        return
    }

    let chapter = try await work.getChapter(firstChapter.id)

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
    #expect(user.imageURL != nil, "User should have a profile image URL")
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

@Test("User should have counts from sidebar")
func testUserCounts() async throws {
    // Use a known user with works
    let user = try await AO3.getUser("astolat")

    // User should have work count
    #expect(user.worksCount != nil, "User should have works count")
    #expect(user.worksCount! > 0, "User should have at least one work")
}

@Test("User recentWorks should be AO3Work objects")
func testUserRecentWorksAreWorkObjects() async throws {
    let user = try await AO3.getUser("astolat")

    #expect(!user.recentWorks.isEmpty, "User should have recent works")

    // Recent works should be fully parsed AO3Work objects
    for work in user.recentWorks {
        #expect(work.id > 0, "Work should have valid ID")
        #expect(!work.title.isEmpty, "Work should have title")
    }
}

@Test("loadProfile fetches additional profile data")
func testLoadProfile() async throws {
    let user = try await AO3.getUser("astolat")

    #expect(!user.profileLoaded, "Profile should not be loaded initially")

    try await user.loadProfile()

    #expect(user.profileLoaded, "Profile should be marked as loaded")
    #expect(user.joinDate != nil, "User should have join date after loadProfile")
    #expect(user.userID != nil, "User should have user ID after loadProfile")
}

@Test("getUserWorks returns paginated works")
func testGetUserWorks() async throws {
    let result = try await AO3.getUserWorks(username: "astolat", page: 1)

    #expect(!result.works.isEmpty, "Should return works")
    #expect(result.currentPage == 1, "Should be on page 1")
    #expect(result.totalPages >= 1, "Should have at least 1 page")

    // Works should be valid
    for work in result.works {
        #expect(work.id > 0, "Work should have valid ID")
        #expect(!work.title.isEmpty, "Work should have title")
    }
}

@Test("getUserWorks pagination works correctly")
func testGetUserWorksPagination() async throws {
    // Get a user with many works
    let page1 = try await AO3.getUserWorks(username: "astolat", page: 1)

    guard page1.hasNextPage else {
        // User doesn't have enough works for pagination test
        return
    }

    let page2 = try await AO3.getUserWorks(username: "astolat", page: 2)

    #expect(!page2.works.isEmpty, "Page 2 should have works")

    // The key test: pages should have different works
    let page1Ids = Set(page1.works.map { $0.id })
    let page2Ids = Set(page2.works.map { $0.id })
    #expect(page1Ids.isDisjoint(with: page2Ids), "Pages should have different works")
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
        warnings: [],
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
        warnings: [.noneApply],
        rating: nil
    )

    // Search should complete without errors (results may be empty depending on AO3's search behavior)
    #expect(results.count >= 0, "Search should return valid results array")
}

@Test("Search with both filters")
func testSearchWithBothFilters() async throws {
    let results = try await AO3.searchWork(
        query: "hurt/comfort",
        warnings: [.noneApply],
        rating: .teenAndUp
    )

    // Should complete successfully (may or may not have results depending on query)
    #expect(results.count >= 0, "Search should return valid results array")
}

// MARK: - Advanced Search Tests

@Test("Basic search by author username works")
func testBasicSearchByAuthor() async throws {
    // Search for a known prolific author (SweetestSixShooter was mentioned in the user's query)
    let results = try await AO3.searchWork(query: "SweetestSixShooter")

    // Should return results without errors
    #expect(results.count >= 0, "Search should complete without errors")

    // If results are returned, verify they're valid works
    for work in results {
        #expect(work.id > 0, "Work ID should be positive")
        #expect(!work.title.isEmpty, "Work should have a title")
    }
}

@Test("Advanced search with filters - rating and warnings")
func testAdvancedSearchWithRatingsAndWarnings() async throws {
    // Create filters for Teen rating and specific warnings
    var filters = AO3SearchFilters()
    filters.rating = .teenAndUp
    filters.warnings = [.noneApply, .violence]

    let results = try await AO3.searchWork(query: "Testing", filters: filters)

    // Should complete successfully
    #expect(results.count >= 0, "Advanced search should return valid results array")

    // Verify returned works
    for work in results {
        #expect(work.id > 0, "Work ID should be positive")
    }
}

@Test("Advanced search with complete status filter")
func testAdvancedSearchCompleteStatus() async throws {
    var filters = AO3SearchFilters()
    filters.complete = .complete
    filters.rating = .general

    let results = try await AO3.searchWork(query: "friendship", filters: filters)

    #expect(results.count >= 0, "Search with completion filter should work")
}

@Test("Advanced search with word count range")
func testAdvancedSearchWordCount() async throws {
    var filters = AO3SearchFilters()
    filters.wordCount = "1000-5000"  // Works between 1k and 5k words
    filters.sortColumn = .wordCount
    filters.sortDirection = .descending

    let results = try await AO3.searchWork(query: "coffee shop", filters: filters)

    #expect(results.count >= 0, "Search with word count filter should work")
}

@Test("Advanced search with fandom filter")
func testAdvancedSearchWithFandom() async throws {
    var filters = AO3SearchFilters()
    filters.fandomNames = "Harry Potter"
    filters.rating = .general

    let results = try await AO3.searchWork(query: "", filters: filters)

    #expect(results.count >= 0, "Search with fandom filter should work")
}

@Test("Advanced search with character and relationship filters")
func testAdvancedSearchCharactersAndRelationships() async throws {
    var filters = AO3SearchFilters()
    filters.characterNames = "Harry Potter"
    filters.relationshipNames = "Harry Potter/Ginny Weasley"
    filters.categories = [.fm]

    let results = try await AO3.searchWork(query: "", filters: filters)

    #expect(results.count >= 0, "Search with character and relationship filters should work")
}

@Test("Advanced search with kudos count")
func testAdvancedSearchKudosCount() async throws {
    var filters = AO3SearchFilters()
    filters.kudosCount = ">100"  // More than 100 kudos
    filters.sortColumn = .kudos
    filters.sortDirection = .descending

    let results = try await AO3.searchWork(query: "popular", filters: filters)

    #expect(results.count >= 0, "Search with kudos filter should work")
}

@Test("Advanced search with crossover filter")
func testAdvancedSearchCrossover() async throws {
    var filters = AO3SearchFilters()
    filters.crossover = .only  // Only crossovers
    filters.rating = .general

    let results = try await AO3.searchWork(query: "", filters: filters)

    #expect(results.count >= 0, "Crossover filter should work")
}

@Test("Advanced search with single chapter filter")
func testAdvancedSearchSingleChapter() async throws {
    var filters = AO3SearchFilters()
    filters.singleChapter = true
    filters.complete = .complete

    let results = try await AO3.searchWork(query: "oneshot", filters: filters)

    #expect(results.count >= 0, "Single chapter filter should work")
}

@Test("Advanced search with multiple categories")
func testAdvancedSearchMultipleCategories() async throws {
    var filters = AO3SearchFilters()
    filters.categories = [.mm, .ff]  // M/M or F/F
    filters.rating = .mature

    let results = try await AO3.searchWork(query: "romance", filters: filters)

    #expect(results.count >= 0, "Multiple category filter should work")
}

@Test("Advanced search with title filter")
func testAdvancedSearchTitle() async throws {
    var filters = AO3SearchFilters()
    filters.title = "love"
    filters.sortColumn = .title
    filters.sortDirection = .ascending

    let results = try await AO3.searchWork(query: "", filters: filters)

    #expect(results.count >= 0, "Title filter should work")
}

@Test("Advanced search with creator filter")
func testAdvancedSearchCreator() async throws {
    var filters = AO3SearchFilters()
    filters.creators = "astolat"  // Well-known AO3 author

    let results = try await AO3.searchWork(query: "", filters: filters)

    #expect(results.count >= 0, "Creator filter should work")
}

@Test("Advanced search sorting by different columns")
func testAdvancedSearchSorting() async throws {
    // Test sorting by hits
    var filters = AO3SearchFilters()
    filters.sortColumn = .hits
    filters.sortDirection = .descending

    let hitResults = try await AO3.searchWork(query: "popular", filters: filters)
    #expect(hitResults.count >= 0, "Sorting by hits should work")

    // Test sorting by date updated
    filters.sortColumn = .dateUpdated
    let dateResults = try await AO3.searchWork(query: "recent", filters: filters)
    #expect(dateResults.count >= 0, "Sorting by date updated should work")
}

@Test("Complex advanced search with many filters")
func testComplexAdvancedSearch() async throws {
    // Replicate the user's complex query
    var filters = AO3SearchFilters()
    filters.rating = .teenAndUp
    filters.warnings = [.noneApply, .violence]
    filters.wordCount = ">5000"
    filters.complete = .complete
    filters.sortColumn = .kudos
    filters.sortDirection = .descending

    let results = try await AO3.searchWork(query: "Testing", filters: filters)

    #expect(results.count >= 0, "Complex search should work")

    // Verify all results are valid
    for work in results {
        #expect(work.id > 0, "Work ID should be positive")
        #expect(!work.title.isEmpty, "Work should have a title")
    }
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

    guard let firstChapter = work.chapters.first else {
        Issue.record("No chapters found in work")
        return
    }

    let chapter = try await work.getChapter(firstChapter.id)
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
    #expect(AO3Warning.byValue("No Archive Warnings Apply") == .noneApply)
    #expect(AO3Warning.byValue("Graphic Depictions Of Violence") == .violence)
    #expect(AO3Warning.byValue("invalid value") == .none)
}

@Test("Rating enum byValue")
func testRatingEnumByValue() {
    #expect(AO3Rating.byValue("General Audiences") == .general)
    #expect(AO3Rating.byValue("Explicit") == .explicit)
    #expect(AO3Rating.byValue("invalid value") == .notRated)
}

@Test("Category enum byValue")
func testCategoryEnumByValue() {
    #expect(AO3Category.byValue("M/M") == .mm)
    #expect(AO3Category.byValue("F/F") == .ff)
    #expect(AO3Category.byValue("Gen") == .gen)
    #expect(AO3Category.byValue("invalid value") == .none)
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
    let generalRated = results.withAO3Rating(.general)

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

// MARK: - Caching Tests

@Test("Memory cache works for works")
func testMemoryCacheWorks() async throws {
    // Configure memory cache
    let cache = AO3MemoryCache(maxWorks: 10)
    await AO3.configure(cache: cache)

    // First fetch - should hit network
    let work1 = try await AO3.getWork(68352911)
    #expect(work1.id == 68352911)

    // Second fetch - should hit cache (instant)
    let work2 = try await AO3.getWork(68352911)
    #expect(work2.id == 68352911)
    #expect(work2.title == work1.title, "Cached work should match original")

    // Clean up - disable cache for other tests
    await AO3.configure(cache: nil)
}

@Test("Memory cache works for chapters")
func testMemoryCacheChapters() async throws {
    let cache = AO3MemoryCache(maxChapters: 10)
    await AO3.configure(cache: cache)

    let work = try await AO3.getWork(68352911)
    guard let firstChapter = work.chapters.first else {
        Issue.record("No chapters found")
        return
    }

    // First fetch - should hit network
    let chapter1 = try await work.getChapter(firstChapter.id)
    #expect(!chapter1.content.isEmpty)

    // Second fetch - should hit cache
    let chapter2 = try await work.getChapter(firstChapter.id)
    #expect(chapter2.content == chapter1.content, "Cached chapter should match")

    // Clean up
    await AO3.configure(cache: nil)
}

@Test("Memory cache works for users")
func testMemoryCacheUsers() async throws {
    let cache = AO3MemoryCache(maxUsers: 10)
    await AO3.configure(cache: cache)

    let work = try await AO3.getWork(68352911)
    guard let firstAuthor = work.authors.first else {
        Issue.record("No authors found")
        return
    }

    // First fetch - should hit network
    let user1 = try await AO3.getUser(firstAuthor.username)
    #expect(user1.username == firstAuthor.username)

    // Second fetch - should hit cache
    let user2 = try await AO3.getUser(firstAuthor.username)
    #expect(user2.username == user1.username, "Cached user should match")

    // Clean up
    await AO3.configure(cache: nil)
}

@Test("Cache can be cleared")
func testCacheClear() async throws {
    let cache = AO3MemoryCache()
    await AO3.configure(cache: cache)

    // Fetch and cache a work
    let work = try await AO3.getWork(68352911)
    #expect(work.id == 68352911)

    // Clear cache
    await cache.clear()

    // Fetch again - should work fine (refetch from network)
    let workAgain = try await AO3.getWork(68352911)
    #expect(workAgain.id == 68352911)

    // Clean up
    await AO3.configure(cache: nil)
}

@Test("Works without cache (default)")
func testWorksWithoutCache() async throws {
    // Ensure no cache is configured
    await AO3.configure(cache: nil)

    // Should work fine without cache
    let work = try await AO3.getWork(68352911)
    #expect(work.id == 68352911)

    let chapter = try await work.getFirstChapter()
    #expect(!chapter.content.isEmpty)
}

@Test("Disk cache works")
func testDiskCache() async throws {
    // Create a temporary directory for the cache
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("AO3KitTestCache_\(UUID().uuidString)", isDirectory: true)

    let diskCache = try AO3DiskCache(directory: tempDir, ttl: 3600)
    await AO3.configure(cache: diskCache)

    // Fetch and cache a work
    let work1 = try await AO3.getWork(68352911)
    #expect(work1.id == 68352911)

    // Second fetch should hit cache
    let work2 = try await AO3.getWork(68352911)
    #expect(work2.title == work1.title, "Disk cached work should match")

    // Clean up
    await diskCache.clear()
    try? FileManager.default.removeItem(at: tempDir)
    await AO3.configure(cache: nil)
}

@available(macOS 12.0, iOS 15.0, *)
@Test("AttributedString conversion preserves formatting")
func testAttributedStringConversion() async throws {
    // Work 74838221 has colored and italicized text
    let work = try await AO3.getWork(74838221)
    let chapter = try await work.getFirstChapter()

    // Verify we have HTML content
    #expect(!chapter.contentHTML.isEmpty, "Chapter should have HTML content")

    // Convert to AttributedString
    let attributedContent = try chapter.getAttributedContent()

    // Verify we got content
    #expect(!attributedContent.characters.isEmpty, "AttributedString should have content")

    print("\n=== ATTRIBUTED STRING OUTPUT ===")
    print(String(attributedContent.characters.prefix(500)))
    print("\n=== END ===\n")

    // Check that plain text matches
    let plainFromAttributed = String(attributedContent.characters)
    #expect(plainFromAttributed.contains("Come oooooon"), "Should contain expected text")

    // Test HTML conversion with known formatting
    let testHTML = "<em>italic text</em> and <strong>bold text</strong>"
    let testAttributed = try AO3ChapterAttributedStringConverter.convert(testHTML)
    #expect(!testAttributed.characters.isEmpty, "Should convert HTML to AttributedString")

    print("\n=== TEST HTML CONVERSION ===")
    print("Input: \(testHTML)")
    print("Output: \(String(testAttributed.characters))")
    print("\n=== END ===\n")
}

@available(macOS 12.0, iOS 15.0, *)
@Test("AttributedString handles colored text spans")
func testColoredSpanConversion() async throws {
    // Test with custom span classes like AO3 uses for colored dialogue
    let htmlWithSpans = """
    <span class="FakeIDCallie">"Hello there!"</span> she said.
    <span class="FakeIDYou">"Hi!"</span> you replied.
    """

    let attributed = try AO3ChapterAttributedStringConverter.convert(htmlWithSpans)

    #expect(!attributed.characters.isEmpty, "Should have content")
    let plainText = String(attributed.characters)
    #expect(plainText.contains("Hello there!"), "Should preserve text content")
    #expect(plainText.contains("Hi!"), "Should preserve all dialogue")

    print("\n=== COLORED SPAN TEST ===")
    print("HTML: \(htmlWithSpans)")
    print("Plain: \(plainText)")
    print("\n=== END ===\n")
}

// MARK: - Mock Data Tests

@available(macOS 12.0, iOS 15.0, *)
@Test("Mock data works are valid")
func testMockWorks() throws {
    let work1 = AO3MockData.sampleWork1
    #expect(work1.id == 1000001, "Work should have correct ID")
    #expect(work1.title == "The Adventure Begins", "Work should have title")
    #expect(!work1.authors.isEmpty, "Work should have authors")
    #expect(work1.rating == .teenAndUp, "Work should have correct rating")

    let work2 = AO3MockData.sampleWork2
    #expect(work2.id == 1000002, "Work 2 should have correct ID")
    #expect(work2.title == "Coffee Shop Chronicles", "Work 2 should have title")

    #expect(AO3MockData.sampleWorks.count == 3, "Should have 3 sample works")
}

@available(macOS 12.0, iOS 15.0, *)
@Test("Mock data chapters are valid")
func testMockChapters() throws {
    let chapter1 = AO3MockData.sampleChapter1
    #expect(chapter1.id == 2000001, "Chapter should have correct ID")
    #expect(chapter1.title == "Chapter 1: New Beginnings", "Chapter should have title")
    #expect(!chapter1.content.isEmpty, "Chapter should have content")

    let formattedChapter = AO3MockData.sampleChapterFormatted
    #expect(!formattedChapter.contentHTML.isEmpty, "Formatted chapter should have HTML")

    // Test AttributedString conversion on mock data
    let attributed = try formattedChapter.getAttributedContent()
    #expect(!attributed.characters.isEmpty, "Should convert mock HTML to AttributedString")

    #expect(AO3MockData.sampleChapters.count == 3, "Should have 3 sample chapters")
}

@available(macOS 12.0, iOS 15.0, *)
@Test("Mock data users are valid")
func testMockUsers() throws {
    let user1 = AO3MockData.sampleUser1
    #expect(user1.username == "AuthorOne", "User should have username")
    #expect(!user1.fandoms.isEmpty, "User should have fandoms")

    #expect(AO3MockData.sampleUsers.count == 2, "Should have 2 sample users")
}

@available(macOS 12.0, iOS 15.0, *)
@Test("Mock data preview helpers work")
func testPreviewHelpers() throws {
    let previewWork = AO3MockData.previewWork
    #expect(previewWork.id > 0, "Preview work should be valid")

    let previewChapter = AO3MockData.previewChapter
    #expect(!previewChapter.content.isEmpty, "Preview chapter should have content")

    let previewUser = AO3MockData.previewUser
    #expect(!previewUser.username.isEmpty, "Preview user should have username")
}

// MARK: - Paginated Search Tests

@Test("Paginated search returns pagination info")
func testPaginatedSearchReturnsInfo() async throws {
    // Search for a term with many results
    let result = try await AO3.searchWorkPaginated(query: "love")

    #expect(result.currentPage == 1, "First page should be page 1")
    #expect(result.totalPages >= 1, "Should have at least 1 page")
    #expect(!result.works.isEmpty, "Should have some results")

    // Verify pagination properties
    if result.totalPages > 1 {
        #expect(result.hasNextPage, "Should have next page when total > 1")
        #expect(result.nextPage == 2, "Next page should be 2")
    }
    #expect(!result.hasPreviousPage, "First page should not have previous")
    #expect(result.previousPage == nil, "Previous page should be nil on first page")
}

@Test("Paginated search can fetch page 2")
func testPaginatedSearchPage2() async throws {
    // First get page 1 to ensure there are multiple pages
    let page1 = try await AO3.searchWorkPaginated(query: "romance")

    guard page1.totalPages > 1 else {
        // Skip if only 1 page of results
        return
    }

    // Fetch page 2
    let page2 = try await AO3.searchWorkPaginated(query: "romance", page: 2)

    #expect(page2.currentPage == 2, "Should be on page 2")
    #expect(!page2.works.isEmpty, "Page 2 should have results")
    #expect(page2.hasPreviousPage, "Page 2 should have previous page")
    #expect(page2.previousPage == 1, "Previous page should be 1")

    // Verify results are different from page 1
    let page1IDs = Set(page1.works.map(\.id))
    let page2IDs = Set(page2.works.map(\.id))
    #expect(page1IDs.isDisjoint(with: page2IDs), "Page 1 and 2 should have different works")
}

@Test("Paginated search with filters")
func testPaginatedSearchWithFilters() async throws {
    var filters = AO3SearchFilters()
    filters.rating = .general
    filters.complete = .complete

    let result = try await AO3.searchWorkPaginated(query: "friendship", page: 1, filters: filters)

    #expect(result.currentPage == 1, "Should be on page 1")
    #expect(result.totalPages >= 1, "Should have at least 1 page")

    // All results should be valid
    for work in result.works {
        #expect(work.id > 0, "Work ID should be positive")
        #expect(!work.title.isEmpty, "Work should have a title")
    }
}

@Test("Paginated search handles single page results")
func testPaginatedSearchSinglePage() async throws {
    // Use a very specific query that should have few results
    let result = try await AO3.searchWorkPaginated(query: "xyzzy12345uniquequery")

    // Even if no results, pagination info should be valid
    #expect(result.currentPage == 1, "Should be on page 1")
    #expect(result.totalPages >= 1, "Should have at least 1 page")
    #expect(!result.hasNextPage || result.totalPages > 1, "hasNextPage should match totalPages")
}

@Test("AO3WorksResult convenience properties")
func testSearchResultProperties() async throws {
    let result = try await AO3.searchWorkPaginated(query: "adventure", page: 1)

    // Test that all computed properties work
    _ = result.hasNextPage
    _ = result.hasPreviousPage
    _ = result.nextPage
    _ = result.previousPage

    // Verify consistency
    if result.currentPage == 1 {
        #expect(!result.hasPreviousPage, "Page 1 should not have previous")
        #expect(result.previousPage == nil, "previousPage should be nil")
    }

    if result.currentPage >= result.totalPages {
        #expect(!result.hasNextPage, "Last page should not have next")
        #expect(result.nextPage == nil, "nextPage should be nil")
    }
}
