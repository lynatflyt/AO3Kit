import Foundation

/// Context passed through the rendering pipeline
public struct RenderContext: Sendable {
    public var listDepth: Int = 0
    public var listCounters: [Int] = []
    public var currentStyle: TextStyle = TextStyle()
    public var workSkin: WorkSkin = WorkSkin()

    public init() {}

    public init(workSkin: WorkSkin) {
        self.workSkin = workSkin
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
