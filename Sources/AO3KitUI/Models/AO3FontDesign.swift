import SwiftUI
import UIKit // Added unconditionally for properties that will use it

/// Font design options that map to both SwiftUI and UIKit
public enum AO3FontDesign: String, Sendable {
    case `default`
    case serif
    case rounded

    #if canImport(UIKit)
    var uiFontDescriptorDesign: UIFontDescriptor.SystemDesign {
        switch self {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }
    #endif

    var swiftUIDesign: Font.Design {
        switch self {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }
}
