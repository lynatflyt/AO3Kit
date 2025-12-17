import Foundation

/// Parses work skin CSS to extract color definitions
public struct CSSParser {

    /// Parse CSS string and extract color mappings for #workskin classes
    /// - Parameter css: The CSS string from a work's <style> tag
    /// - Returns: A WorkSkin with parsed color mappings
    public static func parse(_ css: String?) -> WorkSkin {
        guard let css = css, !css.isEmpty else {
            return WorkSkin()
        }

        var colorMap: [String: String] = [:]

        // Match: #workskin .ClassName { ... color: #hexcolor; ... }
        // Regex explanation:
        // - #workskin\s+ : match "#workskin" followed by whitespace
        // - \.(\w+) : match "." followed by class name (captured)
        // - \s*\{ : match opening brace
        // - [^}]* : match any content except closing brace
        // - color:\s* : match "color:" with optional whitespace
        // - #([0-9a-fA-F]{6}) : match # followed by 6 hex digits (captured)
        let pattern = #"#workskin\s+\.(\w+)\s*\{[^}]*color:\s*#([0-9a-fA-F]{6})"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return WorkSkin()
        }

        let nsString = css as NSString
        let matches = regex.matches(in: css, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            // Extract class name (first capture group)
            if match.numberOfRanges > 1,
               let classRange = Range(match.range(at: 1), in: css) {
                let className = String(css[classRange])

                // Extract hex color (second capture group)
                if match.numberOfRanges > 2,
                   let colorRange = Range(match.range(at: 2), in: css) {
                    let hexColor = String(css[colorRange])
                    colorMap[className] = hexColor.lowercased()
                }
            }
        }

        return WorkSkin(colorMap: colorMap)
    }
}
