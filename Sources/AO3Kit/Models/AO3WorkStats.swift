//
//  AO3WorkStats.swift
//  AO3Kit
//
//  Structured statistics for a work, replacing the untyped [String: String] dictionary
//

import Foundation

/// Structured statistics for a work
public struct AO3WorkStats: Codable, Sendable, Hashable {
    /// Word count of the work
    public let words: Int

    /// Chapter progress string (e.g., "3/5" or "1/?")
    public let chapters: String

    /// Number of kudos received
    public let kudos: Int?

    /// Number of hits/views
    public let hits: Int?

    /// Number of bookmarks
    public let bookmarks: Int?

    /// Number of comments
    public let comments: Int?

    public init(
        words: Int = 0,
        chapters: String = "1/1",
        kudos: Int? = nil,
        hits: Int? = nil,
        bookmarks: Int? = nil,
        comments: Int? = nil
    ) {
        self.words = words
        self.chapters = chapters
        self.kudos = kudos
        self.hits = hits
        self.bookmarks = bookmarks
        self.comments = comments
    }

    /// Initialize from the legacy [String: String] stats dictionary
    internal init(from dictionary: [String: String]) {
        self.words = dictionary["words"].flatMap { Int($0) } ?? 0
        self.chapters = dictionary["chapters"] ?? "1/1"
        self.kudos = dictionary["kudos"].flatMap { Int($0) }
        self.hits = dictionary["hits"].flatMap { Int($0) }
        self.bookmarks = dictionary["bookmarks"].flatMap { Int($0) }
        self.comments = dictionary["comments"].flatMap { Int($0) }
    }

    /// Convert to the legacy dictionary format for backward compatibility
    internal func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        dict["words"] = String(words)
        dict["chapters"] = chapters
        if let kudos = kudos { dict["kudos"] = String(kudos) }
        if let hits = hits { dict["hits"] = String(hits) }
        if let bookmarks = bookmarks { dict["bookmarks"] = String(bookmarks) }
        if let comments = comments { dict["comments"] = String(comments) }
        return dict
    }

    /// Current chapter count (parsed from chapters string)
    public var currentChapterCount: Int {
        let parts = chapters.split(separator: "/")
        return parts.first.flatMap { Int($0) } ?? 1
    }

    /// Total chapter count, nil if unknown (e.g., "?")
    public var totalChapterCount: Int? {
        let parts = chapters.split(separator: "/")
        guard parts.count > 1 else { return nil }
        return Int(parts[1])
    }

    /// Whether the work is complete (current chapters == total chapters)
    public var isComplete: Bool {
        guard let total = totalChapterCount else { return false }
        return currentChapterCount == total
    }
}
