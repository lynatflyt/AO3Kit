# AO3Kit

A Swift library for accessing data from [Archive of Our Own (AO3)](https://archiveofourown.org). This is a port of the [ao3-java](https://github.com/glorantq/ao3-java) library to Swift.

> **Note:** This is **not** an official API. AO3 does not provide an official API, so this library works by scraping HTML pages. As such, it may break if AO3 changes their HTML structure. It is also not as fast as it could be. We implement a cache to help mitigate this but there is not much we can do.

## Features

- Retrieve work metadata (title, authors, ratings, statistics, etc.)
- Advanced search with filters (rating, warnings, word count, completion status, etc.)
- Get chapter content with **rich text formatting** (bold, italic, colors)
  - Plain text access via `.content`
  - HTML access via `.contentHTML`
  - `AttributedString` support for native iOS/macOS rendering
- Access user profile information
- Full async/await support
- Codable support for JSON serialization
- Built-in caching (memory and disk)

## Requirements

- iOS 17.0+ / macOS 12.0+ / tvOS 17.0+ / watchOS 8.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/lynatflyt/ao3kit.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File -> Add Package Dependencies
2. Enter the repository URL
3. Select your desired version

## Usage

### Getting a Work

```swift
import AO3Kit

// Get a work by its ID
let work = try await AO3.getWork(12345678)

print("Title: \(work.title)")
print("Authors: \(work.authors.map { $0.username }.joined(separator: ", "))")
print("Rating: \(work.rating.rawValue)")
print("Fandom: \(work.fandom)")
print("Word Count: \(work.stats["words"] ?? "N/A")")
print("Kudos: \(work.stats["kudos"] ?? "N/A")")

// Access chapters
for (chapterID, chapterTitle) in work.chapters.sorted(by: { $0.key < $1.key }) {
    print("Chapter \(chapterID): \(chapterTitle)")
}
```

### Getting Chapter Content

```swift
// Get a specific chapter
let chapter = try await work.getChapter(12345678)

print("Chapter Title: \(chapter.title)")
print("Summary: \(chapter.summary)")
print("Content: \(chapter.content)") // Plain text content

// Author's notes
for note in chapter.notes {
    print("Note: \(note)")
}

// Get formatted content with AttributedString (iOS 15+, macOS 12+)
// This preserves bold, italic, and colored text from AO3
let attributedContent = try chapter.getAttributedContent()
// Use attributedContent in your UI for rich text display

// Access raw HTML if you need custom rendering
print("HTML: \(chapter.contentHTML)")

// Convert any HTML to AttributedString
let customHTML = "<em>italic</em> and <strong>bold</strong> and <span class=\"custom\">colored</span>"
let customAttributed = try AO3Chapter.htmlToAttributedString(customHTML)
```

### Getting User Information

```swift
// Get a user by username
let user = try await AO3.getUser("username")

print("Username: \(user.username)")
print("Profile Image: \(user.imageURL)")
print("Fandoms: \(user.fandoms.joined(separator: ", "))")

// Get recent works
for workID in user.recentWorks {
    let work = try await AO3.getWork(workID)
    print("Recent work: \(work.title)")
}
```

### Getting a User with Pseudonym

```swift
// Get a user with a specific pseud
let userWithPseud = try await AO3.getPseud(username: "username", pseud: "pseudonym")
```

### Searching for Works

AO3Kit provides two search methods: **Simple Search** for quick queries, and **Advanced Search** with comprehensive filtering options.

#### Simple Search

Perfect for quick queries with basic rating and warning filters:

```swift
// Basic search by query
let results = try await AO3.searchWork(query: "coffee shop AU")

for work in results {
    print("\(work.title) by \(work.authors.map { $0.username }.joined(separator: ", "))")
}

// Search with rating filters
let generalResults = try await AO3.searchWork(
    query: "friendship",
    warnings: [],
    ratings: [.general]
)

// Search with warning filters
let safeResults = try await AO3.searchWork(
    query: "fluff",
    warnings: [.noneApply],
    ratings: []
)

// Search with both filters
let teenSafeResults = try await AO3.searchWork(
    query: "hurt/comfort",
    warnings: [.noneApply],
    ratings: [.teenAndUp]
)
```

#### Advanced Search with Filters

For complex searches with detailed criteria, use `AO3SearchFilters`:

```swift
// Search by creator/author
var filters = AO3SearchFilters()
filters.creators = "astolat"
let works = try await AO3.searchWork(query: "", filters: filters)

// Search with rating and warnings (note: only one rating can be selected)
var filters = AO3SearchFilters()
filters.rating = .teenAndUp
filters.warnings = [.noneApply, .violence]
let results = try await AO3.searchWork(query: "Testing", filters: filters)

// Search with word count range
var filters = AO3SearchFilters()
filters.wordCount = "1000-5000"  // Between 1k and 5k words
filters.sortColumn = .wordCount
filters.sortDirection = .descending
let results = try await AO3.searchWork(query: "coffee shop", filters: filters)

// Search by fandom and characters
var filters = AO3SearchFilters()
filters.fandomNames = "Harry Potter"
filters.characterNames = "Harry Potter"
filters.relationshipNames = "Harry Potter/Ginny Weasley"
filters.categories = [.fm]
filters.rating = .general
let results = try await AO3.searchWork(query: "", filters: filters)

// Complex search with many filters
var filters = AO3SearchFilters()
filters.rating = .teenAndUp
filters.warnings = [.noneApply, .violence]
filters.wordCount = ">5000"
filters.complete = .complete
filters.sortColumn = .kudos
filters.sortDirection = .descending
let results = try await AO3.searchWork(query: "adventure", filters: filters)

// Crossovers only
var filters = AO3SearchFilters()
filters.crossover = .only
filters.rating = .general
let results = try await AO3.searchWork(query: "", filters: filters)

// Single chapter/oneshots
var filters = AO3SearchFilters()
filters.singleChapter = true
filters.complete = .complete
let results = try await AO3.searchWork(query: "oneshot", filters: filters)

// Popular works (minimum kudos)
var filters = AO3SearchFilters()
filters.kudosCount = ">100"
filters.sortColumn = .kudos
filters.sortDirection = .descending
let results = try await AO3.searchWork(query: "popular", filters: filters)
```

**Available Filter Options:**

- **Completion Status**: `.all`, `.complete`, `.incomplete`
- **Crossover**: `.include`, `.exclude`, `.only`
- **Sort Columns**: `.bestMatch`, `.author`, `.title`, `.datePosted`, `.dateUpdated`, `.wordCount`, `.hits`, `.kudos`, `.comments`, `.bookmarks`
- **Sort Direction**: `.ascending`, `.descending`
- **Numeric Ranges** (word count, kudos, hits, etc.): `">1000"`, `"<5000"`, `"1000-5000"`, `"=2500"`

#### Fluent Search API

Build searches declaratively with a fluent interface:

```swift
// Simple fluent search
let results = try await AO3.search()
    .term("coffee shop")
    .AO3Rating(.general)
    .execute()

// Advanced fluent search
let results = try await AO3.search()
    .term("romance")
    .fandom("Harry Potter")
    .characters("Harry Potter")
    .rating(.general)  // Only one rating can be selected
    .complete(.complete)
    .wordCount("1000-10000")
    .sortBy(.kudos, direction: .descending)
    .execute()

// Search for completed works with high kudos
let popular = try await AO3.search()
    .term("adventure")
    .complete(.complete)
    .minKudos(100)
    .sortBy(.kudos)
    .execute()

// Search for single chapter fics
let oneshots = try await AO3.search()
    .singleChapter(true)
    .wordCount("5000-15000")
    .rating(.teenAndUp)
    .execute()
```

#### Convenience Properties

```swift
let work = try await AO3.getWork(12345678)

// Access stats as integers
let words = work.wordCount        // Int?
let kudos = work.kudosCount       // Int?
let hits = work.hitsCount          // Int?
let bookmarks = work.bookmarksCount // Int?
let comments = work.commentsCount  // Int?

// Quick access to chapters
let firstChapter = try await work.getFirstChapter()
let allChapters = try await work.getAllChapters()
```

### Mock Data for Testing & Previews

AO3Kit provides realistic mock data for testing and SwiftUI previews without making network requests:

```swift
import AO3Kit

// Use sample works
let work = AO3MockData.sampleWork1  // Completed adventure story
let work2 = AO3MockData.sampleWork2 // In-progress coffee shop AU
let work3 = AO3MockData.sampleWork3 // Mature-rated work

// Use sample chapters with formatting
let chapter = AO3MockData.sampleChapter1         // Plain text
let formattedChapter = AO3MockData.sampleChapterFormatted  // With colors/italics

// Use sample users
let user = AO3MockData.sampleUser1

// Collections for lists
let works = AO3MockData.sampleWorks
let chapters = AO3MockData.sampleChapters
let users = AO3MockData.sampleUsers
```

#### SwiftUI Preview Example

```swift
import SwiftUI
import AO3Kit

struct WorkDetailView: View {
    let work: AO3Work
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(work.title).font(.title)
            Text("by \(work.authors.map(\.username).joined(separator: ", "))")
            Text("\(work.wordCount ?? 0) words")
        }
    }
}

#Preview {
    WorkDetailView(work: AO3MockData.previewWork)
}
```

#### Collection Extensions

```swift
let results = try await AO3.searchWork(query: "harry potter")

// Sort results
let mostKudosed = results.sortedByKudos()
let longest = results.sortedByWordCount()
let mostPopular = results.sortedByHits()
let newest = results.sortedByPublished()

// Filter results
let longFics = results.withMinimumWords(50000)
let explicitOnly = results.withRating(.explicit)
let safeWorks = results.withWarning(.noneApply)
let slashFics = results.withCategory(.mm)

// Chain operations
let longExplicitFics = results
    .withMinimumWords(50000)
    .withRating(.explicit)
    .sortedByKudos()
```

#### String Extensions

```swift
// Extract work IDs from URLs
let url = "https://archiveofourown.org/works/68352911"
if let workID = url.ao3WorkID {
    let work = try await AO3.getWork(workID)
}
```

### Caching

AO3Kit includes optional caching to avoid refetching data you've already loaded. This is perfect for apps where users navigate back and forth between chapters.

#### Memory Cache (In-Memory)

```swift
// Configure at app startup
AO3.configure(cache: AO3MemoryCache(
    maxWorks: 100,       // Max works to cache
    maxChapters: 500,    // Max chapters to cache
    maxUsers: 100,       // Max users to cache
    ttl: 3600            // Time to live: 1 hour
))

// Now use the API normally - caching happens automatically!
let work = try await AO3.getWork(123)
let chapter = try await work.getChapter(456)  // Fetches from network

// Navigate away and come back
let chapterAgain = try await work.getChapter(456)  // Returns instantly from cache!
```

#### Disk Cache (Persistent)

```swift
// Configure disk cache for persistence between app launches
let diskCache = try AO3DiskCache(
    directory: nil,  // Uses system cache directory
    ttl: 86400       // 24 hours
)
AO3.configure(cache: diskCache)

// Works the same way, but survives app restarts
```

#### Custom Cache

Implement your own cache backend:

```swift
class MyDatabaseCache: AO3CacheProtocol {
    func getWork(_ id: Int) async -> AO3Work? {
        // Load from your database
    }

    func setWork(_ work: AO3Work) async {
        // Save to your database
    }

    // ... implement other methods
}

AO3.configure(cache: MyDatabaseCache())
```

#### Without Cache (Default)

```swift
// No configuration needed - works as before
// Every request fetches from network
let work = try await AO3.getWork(123)
```

#### Clear Cache

```swift
if let cache = AO3.cache as? AO3MemoryCache {
    await cache.clear()
}
```

### Working with Enums

The library provides three main enumerations:

#### Archive Warnings

```swift
public enum Warning: String {
    case noWarnings = "Creator Chose Not To Use Archive Warnings"
    case noneApply = "No Archive Warnings Apply"
    case violence = "Graphic Depictions Of Violence"
    case majorCharacterDeath = "Major Character Death"
    case nonCon = "Rape/Non-Con"
    case underage = "Underage"
}
```

#### Ratings

```swift
public enum Rating: String {
    case notRated = "Not Rated"
    case general = "General Audiences"
    case teenAndUp = "Teen And Up Audiences"
    case mature = "Mature"
    case explicit = "Explicit"
}
```

#### Categories

```swift
public enum Category: String {
    case ff = "F/F"
    case fm = "F/M"
    case gen = "Gen"
    case mm = "M/M"
    case multi = "Multi"
    case other = "Other"
    case none = "None"
}
```

### JSON Serialization

All data models conform to `Codable`:

```swift
// Convert to JSON
let work = try await AO3.getWork(12345678)
let jsonString = try work.toJSON()
print(jsonString)

// Convert from JSON
let decodedWork = try AO3Work.fromJSON(jsonString, as: AO3Work.self)
```

### Error Handling

The library uses `AO3Exception` for error handling:

```swift
do {
    let work = try await AO3.getWork(99999999)
} catch AO3Exception.workNotFound(let id) {
    print("Work with ID \(id) not found")
} catch AO3Exception.invalidStatusCode(let code, let message) {
    print("HTTP error \(code): \(message ?? "Unknown error")")
} catch AO3Exception.registeredUsersOnly {
    print("This work is only available to registered users")
} catch {
    print("An error occurred: \(error)")
}
```

## Data Models

### AO3Work

Contains comprehensive work metadata:
- `id`: Work ID
- `title`: Work title
- `authors`: Array of AO3User objects
- `archiveWarning`: Content warning
- `rating`: Age rating
- `category`: Relationship category
- `fandom`: Primary fandom
- `relationships`: Array of relationship tags
- `characters`: Array of character tags
- `additionalTags`: Array of additional tags
- `language`: Work language
- `stats`: Dictionary of statistics (words, kudos, hits, etc.)
- `published`: Publication date
- `updated`: Last update date
- `chapters`: Dictionary mapping chapter IDs to titles

### AO3Chapter

Contains chapter content:
- `workID`: Parent work ID
- `id`: Chapter ID
- `title`: Chapter title
- `content`: Chapter text content
- `notes`: Array of author's notes
- `summary`: Chapter summary

### AO3User

Contains user profile information:
- `username`: User's username
- `pseud`: User's pseudonym
- `imageURL`: Profile image URL
- `fandoms`: Array of user's fandoms
- `recentWorks`: Array of recent work IDs

## Credits

- Original Kotlin/Java library by [glorantq](https://github.com/glorantq)
- Swift port uses [SwiftSoup](https://github.com/scinfu/SwiftSoup) for HTML parsing

## Disclaimer

This library is not affiliated with or endorsed by the Organization for Transformative Works (the organization behind AO3). Please be respectful of AO3's servers and implement appropriate rate limiting in your applications.
