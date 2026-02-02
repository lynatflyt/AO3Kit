//
//  AO3WorkBlurb.swift
//  AO3Kit
//
//  Base preview data for a work, parsed from search results and other listing pages
//

import Foundation

/// Base preview data for a work, containing common metadata from search blurbs.
/// This is a lightweight struct used for listing pages - use `AO3Work` for full work data.
public struct AO3WorkBlurb: Codable, Sendable, Identifiable, Hashable {
    /// The work's unique identifier
    public let id: Int

    /// The title of the work
    public let title: String

    /// The authors of the work
    public let authors: [AO3User]

    /// The primary fandom
    public let fandom: String

    /// The content rating
    public let rating: AO3Rating

    /// Archive warnings
    public let archiveWarning: AO3Warning

    /// Category (M/M, F/F, Gen, etc.)
    public let category: AO3Category

    /// Relationship tags
    public let relationships: [String]

    /// Character tags
    public let characters: [String]

    /// Additional freeform tags
    public let additionalTags: [String]

    /// Language of the work
    public let language: String

    /// Work statistics (words, chapters, kudos, etc.)
    public let stats: AO3WorkStats

    /// Publication date
    public let published: Date

    /// Last updated date
    public let updated: Date

    /// Summary text
    public let summary: String

    public init(
        id: Int,
        title: String,
        authors: [AO3User],
        fandom: String,
        rating: AO3Rating,
        archiveWarning: AO3Warning,
        category: AO3Category,
        relationships: [String],
        characters: [String],
        additionalTags: [String],
        language: String,
        stats: AO3WorkStats,
        published: Date,
        updated: Date,
        summary: String
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.fandom = fandom
        self.rating = rating
        self.archiveWarning = archiveWarning
        self.category = category
        self.relationships = relationships
        self.characters = characters
        self.additionalTags = additionalTags
        self.language = language
        self.stats = stats
        self.published = published
        self.updated = updated
        self.summary = summary
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: AO3WorkBlurb, rhs: AO3WorkBlurb) -> Bool {
        lhs.id == rhs.id
    }
}
