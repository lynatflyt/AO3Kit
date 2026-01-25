import Foundation
import UIKit // Added unconditionally

/// Context passed through the rendering pipeline
public struct RenderContext: @unchecked Sendable {
    public var listDepth: Int = 0
    public var listCounters: [Int] = []
    public var currentStyle: TextStyle = TextStyle()
    public var workSkin: WorkSkin = WorkSkin()

    // Font styling for justified text rendering
    public var fontSize: CGFloat = 17
    public var fontDesign: UIFontDescriptor.SystemDesign = .default
    public var textColor: UIColor = .label
    public var backgroundColor: UIColor = .systemBackground

    public init() {}

    public init(workSkin: WorkSkin) {
        self.workSkin = workSkin
    }

    public init(
        workSkin: WorkSkin,
        fontSize: CGFloat,
        fontDesign: UIFontDescriptor.SystemDesign,
        textColor: UIColor,
        backgroundColor: UIColor
    ) {
        self.workSkin = workSkin
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }

    /// Create a new context with incremented list depth
    public func incrementingListDepth() -> RenderContext {
        var copy = self
        copy.listDepth += 1
        copy.listCounters.append(0)
        return copy
    }

    /// Increment the counter for the current list level
    public mutating func incrementCounter() {
        if !listCounters.isEmpty {
            listCounters[listCounters.count - 1] += 1
        }
    }
}
