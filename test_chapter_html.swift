#!/usr/bin/env swift

import Foundation

// Add the package dependencies
import PackageDescription

// This needs to be run as: swift run in the package directory
// For now, let's create a simpler test

print("To test chapter HTML content, add this code to your test file:")
print("""

@Test("Show chapter HTML formatting")
func testChapterHTMLFormatting() async throws {
    // Use a known work with formatted text
    let chapter = try await AO3.getChapter(workID: 56582692, chapterID: 142188587)

    print("\\n=== CHAPTER CONTENT (plain text) ===")
    print(chapter.content)
    print("\\n=== END ===\\n")
}

""")

print("\nBetter yet, let me create a proper test in the package...")
