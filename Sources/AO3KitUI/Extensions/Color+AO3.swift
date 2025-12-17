import SwiftUI

extension Color {
    /// Generate a deterministic color from a class name (matching AO3Kit logic)
    static func fromAO3ClassName(_ className: String) -> Color {
        let hash = className.hashValue
        let red = Double((hash & 0xFF0000) >> 16) / 255.0
        let green = Double((hash & 0x00FF00) >> 8) / 255.0
        let blue = Double(hash & 0x0000FF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    /// Create color from hex string
    static func fromHex(_ hex: String) -> Color {
        let colorInfo = ColorInfo.fromHex(hex)
        return Color(red: colorInfo.red, green: colorInfo.green, blue: colorInfo.blue)
    }
}
