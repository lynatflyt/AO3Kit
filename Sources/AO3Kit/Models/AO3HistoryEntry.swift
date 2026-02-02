//
//  AO3HistoryEntry.swift
//  AO3Kit
//
//  History context wrapper combining work blurb with visit date
//

import Foundation

/// An entry from the user's reading history, combining work blurb data with the last visited date.
/// The `lastVisitedDate` is always present and non-optional since it's guaranteed in history context.
public struct AO3HistoryEntry: Codable, Sendable, Identifiable {
    /// The work blurb data
    public let blurb: AO3WorkBlurb

    /// When the user last visited this work (always present in history context)
    public let lastVisitedDate: Date

    /// The work ID (convenience accessor)
    public var id: Int { blurb.id }

    public init(blurb: AO3WorkBlurb, lastVisitedDate: Date) {
        self.blurb = blurb
        self.lastVisitedDate = lastVisitedDate
    }
}
