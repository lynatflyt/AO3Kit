# AO3Kit

A Swift library for accessing data from [Archive of Our Own (AO3)](https://archiveofourown.org). This is a port of the [ao3-java](https://github.com/glorantq/ao3-java) library to Swift.

> **Note:** This is **not** an official API. AO3 does not provide an official API, so this library works by scraping HTML pages. As such, it may break if AO3 changes their HTML structure.

## Features

- Retrieve work metadata (title, authors, ratings, statistics, etc.)
- Search for works with optional filtering by rating and content warnings
- Get chapter content including notes and summaries
- Access user profile information
- Full async/await support
- Codable support for JSON serialization

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/ao3kit.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File � Add Package Dependencies
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
print("Content: \(chapter.content)")

// Author's notes
for note in chapter.notes {
    print("Note: \(note)")
}
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

```swift
// Simple search
let results = try await AO3.searchWork(query: "sherlock watson")

for work in results {
    print("\(work.title) by \(work.authors.map { $0.username }.joined(separator: ", "))")
}

// Search with filters
let explicitWorks = try await AO3.searchWork(
    query: "romance",
    warning: nil,
    rating: .explicit
)

let noWarningWorks = try await AO3.searchWork(
    query: "fluff",
    warning: .noneApply,
    rating: nil
)

// Search with both filters
let filteredWorks = try await AO3.searchWork(
    query: "adventure",
    warning: .noneApply,
    rating: .teenAndUp
)
```

#### Fluent Search API

```swift
// Use the fluent API for more readable search queries
let results = try await AO3.search()
    .term("coffee shop AU")
    .rating(.general)
    .warning(.noneApply)
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

## License

This project is licensed under the GPL-3.0 License - see the original [ao3-java](https://github.com/glorantq/ao3-java) repository for details.

## Credits

- Original Kotlin/Java library by [glorantq](https://github.com/glorantq)
- Swift port uses [SwiftSoup](https://github.com/scinfu/SwiftSoup) for HTML parsing

## Disclaimer

This library is not affiliated with or endorsed by the Organization for Transformative Works (the organization behind AO3). Please be respectful of AO3's servers and implement appropriate rate limiting in your applications.
