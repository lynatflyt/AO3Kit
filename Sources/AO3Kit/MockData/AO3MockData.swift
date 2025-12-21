import Foundation

/// Mock data for testing and SwiftUI previews
/// This provides realistic sample data without making actual network requests
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
public struct AO3MockData {
    // All sample data is defined in extensions across separate files:
    // - AO3MockWorks.swift: sampleWork1-3, sampleWorks
    // - AO3MockChapters.swift: sampleChapter1-2, sampleChapterFormatted, sampleChapters
    // - AO3MockUsers.swift: sampleUser1-2, sampleUsers
}

// MARK: - SwiftUI Preview Helpers

#if canImport(SwiftUI)
import SwiftUI

@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension AO3MockData {
    /// Example usage in SwiftUI previews:
    /// ```swift
    /// struct WorkView_Previews: PreviewProvider {
    ///     static var previews: some View {
    ///         WorkView(work: AO3MockData.sampleWork1)
    ///     }
    /// }
    /// ```
    public static var previewWork: AO3Work { sampleWork1 }
    public static var previewChapter: AO3Chapter { sampleChapterFormatted }
    public static var previewUser: AO3User { sampleUser1 }
}
#endif
