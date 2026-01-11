import Foundation
import SwiftSoup

public extension String {
    /// Strips HTML tags from a string
    func strippingHTML() -> String {
        do {
            let doc = try SwiftSoup.parse(self)
            return try doc.text()
        } catch {
            // Fallback: simple regex strip
            return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
    }
}
