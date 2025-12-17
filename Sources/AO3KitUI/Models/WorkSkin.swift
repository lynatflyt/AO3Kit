import Foundation

/// Stores color mappings from work skin CSS
public struct WorkSkin: Sendable {
    /// Maps class names to hex color values (without #)
    private let colorMap: [String: String]

    /// Create an empty work skin (will use fallback colors)
    public init() {
        self.colorMap = [:]
    }

    /// Create a work skin from parsed CSS
    public init(colorMap: [String: String]) {
        self.colorMap = colorMap
    }

    /// Get the hex color for a class name, if defined
    /// - Parameter className: The CSS class name (e.g., "FogLandry")
    /// - Returns: Hex color string without # (e.g., "fc4e47"), or nil if not found
    public func color(for className: String) -> String? {
        return colorMap[className]
    }

    /// Check if a color is defined for the given class
    public func hasColor(for className: String) -> Bool {
        return colorMap[className] != nil
    }

    /// Get all class names that have colors defined
    public var classNames: [String] {
        return Array(colorMap.keys)
    }
}
