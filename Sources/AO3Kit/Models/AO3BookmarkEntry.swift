//
//  AO3BookmarkEntry.swift
//  AO3Kit
//
//  Bookmark context wrapper combining work blurb with bookmark-specific metadata
//

import Foundation

/// An entry from a user's bookmarks, combining work blurb data with bookmark metadata.
public struct AO3BookmarkEntry: Codable, Sendable, Identifiable {
    /// The work blurb data
    public let blurb: AO3WorkBlurb

    /// User's notes on the bookmark
    public let bookmarkNotes: String?

    /// Tags the user applied to the bookmark
    public let bookmarkTags: [String]

    /// When the bookmark was created
    public let bookmarkDate: Date?

    /// Whether the bookmark is private
    public let isPrivate: Bool

    /// Whether this is a rec (recommendation)
    public let isRec: Bool

    /// The work ID (convenience accessor)
    public var id: Int { blurb.id }

    public init(
        blurb: AO3WorkBlurb,
        bookmarkNotes: String? = nil,
        bookmarkTags: [String] = [],
        bookmarkDate: Date? = nil,
        isPrivate: Bool = false,
        isRec: Bool = false
    ) {
        self.blurb = blurb
        self.bookmarkNotes = bookmarkNotes
        self.bookmarkTags = bookmarkTags
        self.bookmarkDate = bookmarkDate
        self.isPrivate = isPrivate
        self.isRec = isRec
    }
}
