//
//  AO3Bookmark.swift
//  AO3Kit
//
//  Model for AO3 bookmark data (for creating and displaying bookmarks)
//

import Foundation

/// Represents bookmark metadata for an AO3 work
public struct AO3Bookmark: Codable, Sendable {
    /// The work ID this bookmark is for
    public let workID: Int

    /// User's notes/comments on the bookmark (max 5000 chars)
    public var notes: String

    /// User's tags for this bookmark (comma-separated on AO3)
    public var tags: [String]

    /// Whether this bookmark is private (not visible to others)
    public var isPrivate: Bool

    /// Whether this is a recommendation
    public var isRec: Bool

    /// Collections to add this bookmark to (optional)
    public var collections: [String]

    /// Date the bookmark was created (when parsing existing bookmarks)
    public var dateBookmarked: Date?

    /// The bookmarked work (when fetched with bookmark data)
    public var work: AO3Work?

    /// Creates a new bookmark for submission
    public init(
        workID: Int,
        notes: String = "",
        tags: [String] = [],
        isPrivate: Bool = false,
        isRec: Bool = false,
        collections: [String] = []
    ) {
        self.workID = workID
        self.notes = notes
        self.tags = tags
        self.isPrivate = isPrivate
        self.isRec = isRec
        self.collections = collections
    }

    /// Creates a bookmark from parsed data (includes work and date)
    internal init(
        workID: Int,
        notes: String,
        tags: [String],
        isPrivate: Bool,
        isRec: Bool,
        collections: [String],
        dateBookmarked: Date?,
        work: AO3Work?
    ) {
        self.workID = workID
        self.notes = notes
        self.tags = tags
        self.isPrivate = isPrivate
        self.isRec = isRec
        self.collections = collections
        self.dateBookmarked = dateBookmarked
        self.work = work
    }

    // MARK: - Form Data

    /// Converts bookmark to form data for POST request
    internal func toFormData(pseudID: String, csrfToken: String) -> [String: String] {
        var formData: [String: String] = [
            "authenticity_token": csrfToken,
            "bookmark[pseud_id]": pseudID,
            "bookmark[bookmarker_notes]": notes,
            "bookmark[tag_string]": tags.joined(separator: ", "),
            "bookmark[private]": isPrivate ? "1" : "0",
            "bookmark[rec]": isRec ? "1" : "0"
        ]

        if !collections.isEmpty {
            formData["bookmark[collection_names]"] = collections.joined(separator: ", ")
        }

        return formData
    }
}

/// Result type for bookmark operations
public enum AO3BookmarkResult: Sendable {
    case created
    case updated
    case deleted
    case alreadyExists
}
