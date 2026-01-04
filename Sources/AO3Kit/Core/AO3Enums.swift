import Foundation

/// Types of autocomplete available on AO3
public enum AO3AutocompleteType: String, Codable, CaseIterable {
    case fandom = "fandom"
    case relationship = "relationship"
    case character = "character"
    case freeform = "freeform"  // Additional tags
}

/// Enumeration of archive warnings
public enum AO3Warning: String, Codable, CaseIterable {
    case noWarnings = "Creator Chose Not To Use Archive Warnings"
    case noneApply = "No Archive Warnings Apply"
    case violence = "Graphic Depictions Of Violence"
    case majorCharacterDeath = "Major Character Death"
    case nonCon = "Rape/Non-Con"
    case underage = "Underage"
    case none = "None"

    public static func byValue(_ value: String) -> AO3Warning {
        return AO3Warning.allCases.first { $0.rawValue.lowercased() == value.lowercased() } ?? .none
    }
}

/// Enumeration of archive ratings
public enum AO3Rating: String, Codable, CaseIterable {
    case notRated = "Not Rated"
    case general = "General Audiences"
    case teenAndUp = "Teen And Up Audiences"
    case mature = "Mature"
    case explicit = "Explicit"

    public static func byValue(_ value: String) -> AO3Rating {
        return AO3Rating.allCases.first { $0.rawValue.lowercased() == value.lowercased() } ?? .notRated
    }
}

/// Enumeration of archive categories
public enum AO3Category: String, Codable, CaseIterable {
    case ff = "F/F"
    case fm = "F/M"
    case gen = "Gen"
    case mm = "M/M"
    case multi = "Multi"
    case other = "Other"
    case none = "None"

    public static func byValue(_ value: String) -> AO3Category {
        return AO3Category.allCases.first { $0.rawValue.lowercased() == value.lowercased() } ?? .none
    }
}
