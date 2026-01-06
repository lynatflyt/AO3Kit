import Foundation

/// Parses work skin CSS to extract color definitions
public struct CSSParser {
    // Static regexes to avoid expensive re-compilation
    private static let ruleRegex = try! NSRegularExpression(
        pattern: #"(?:#workskin\s+)?(?:\w+)?\.([a-zA-Z_][\w-]*)\s*\{([^}]*)\}"#,
        options: [.caseInsensitive]
    )

    private static let colorRegex = try! NSRegularExpression(
        pattern: #"(?:^|;)\s*color\s*:\s*([^;]+)"#,
        options: [.caseInsensitive]
    )

    private static let rgbRegex = try! NSRegularExpression(
        pattern: #"rgba?\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)"#,
        options: []
    )

    /// Parse CSS string and extract color mappings for #workskin classes
    /// - Parameter css: The CSS string from a work's <style> tag
    /// - Returns: A WorkSkin with parsed color mappings
    public static func parse(_ css: String?) -> WorkSkin {
        guard let css = css, !css.isEmpty else {
            return WorkSkin()
        }

        var colorMap: [String: String] = [:]

        let nsString = css as NSString
        let ruleMatches = Self.ruleRegex.matches(in: css, range: NSRange(location: 0, length: nsString.length))

        for match in ruleMatches {
            guard match.numberOfRanges > 2,
                  let classRange = Range(match.range(at: 1), in: css),
                  let propsRange = Range(match.range(at: 2), in: css) else {
                continue
            }

            let className = String(css[classRange])
            let properties = String(css[propsRange])

            // Extract color from properties
            if let hexColor = extractColor(from: properties) {
                colorMap[className] = hexColor
            }
        }

        return WorkSkin(colorMap: colorMap)
    }

    /// Extract color value from CSS properties string
    private static func extractColor(from properties: String) -> String? {
        // Match color property with various formats
        // - color: #RGB or #RRGGBB
        // - color: rgb(r, g, b)
        // - color: rgba(r, g, b, a)
        // - color: colorname

        guard let match = Self.colorRegex.firstMatch(in: properties, range: NSRange(location: 0, length: properties.utf16.count)),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: properties) else {
            return nil
        }

        let colorValue = String(properties[valueRange]).trimmingCharacters(in: .whitespaces)

        // Handle different color formats
        if colorValue.hasPrefix("#") {
            // Hex color
            var hex = String(colorValue.dropFirst())
            // Convert #RGB to #RRGGBB
            if hex.count == 3 {
                hex = hex.map { "\($0)\($0)" }.joined()
            }
            if hex.count == 6, hex.allSatisfy({ $0.isHexDigit }) {
                return hex.lowercased()
            }
        } else if colorValue.lowercased().hasPrefix("rgb") {
            // RGB or RGBA format
            if let hex = rgbToHex(colorValue) {
                return hex
            }
        } else {
            // Named color
            if let hex = namedColorToHex(colorValue.lowercased()) {
                return hex
            }
        }

        return nil
    }

    /// Convert rgb(r,g,b) or rgba(r,g,b,a) to hex
    private static func rgbToHex(_ rgb: String) -> String? {
        guard let match = Self.rgbRegex.firstMatch(in: rgb, range: NSRange(location: 0, length: rgb.utf16.count)),
              match.numberOfRanges > 3,
              let rRange = Range(match.range(at: 1), in: rgb),
              let gRange = Range(match.range(at: 2), in: rgb),
              let bRange = Range(match.range(at: 3), in: rgb),
              let r = Int(rgb[rRange]),
              let g = Int(rgb[gRange]),
              let b = Int(rgb[bRange]) else {
            return nil
        }

        return String(format: "%02x%02x%02x", min(r, 255), min(g, 255), min(b, 255))
    }

    /// Convert named CSS color to hex
    private static func namedColorToHex(_ name: String) -> String? {
        let colors: [String: String] = [
            "black": "000000",
            "white": "ffffff",
            "red": "ff0000",
            "green": "008000",
            "blue": "0000ff",
            "yellow": "ffff00",
            "orange": "ffa500",
            "purple": "800080",
            "pink": "ffc0cb",
            "gray": "808080",
            "grey": "808080",
            "brown": "a52a2a",
            "cyan": "00ffff",
            "magenta": "ff00ff",
            "lime": "00ff00",
            "navy": "000080",
            "teal": "008080",
            "maroon": "800000",
            "olive": "808000",
            "silver": "c0c0c0",
            "aqua": "00ffff",
            "fuchsia": "ff00ff",
            "gold": "ffd700",
            "indigo": "4b0082",
            "violet": "ee82ee",
            "coral": "ff7f50",
            "salmon": "fa8072",
            "crimson": "dc143c",
            "darkred": "8b0000",
            "darkblue": "00008b",
            "darkgreen": "006400",
            "darkorange": "ff8c00",
            "darkviolet": "9400d3",
            "deeppink": "ff1493",
            "lightblue": "add8e6",
            "lightgreen": "90ee90",
            "lightpink": "ffb6c1",
            "lightyellow": "ffffe0",
            "lightgray": "d3d3d3",
            "lightgrey": "d3d3d3",
        ]
        return colors[name]
    }
}
