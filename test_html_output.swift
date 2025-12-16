#!/usr/bin/env swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Simple script to fetch a chapter and show the HTML we get from AO3
// Usage: swift test_html_output.swift <work_id> <chapter_id>

let args = CommandLine.arguments
guard args.count == 3,
      let workID = Int(args[1]),
      let chapterID = Int(args[2]) else {
    print("Usage: swift test_html_output.swift <work_id> <chapter_id>")
    print("Example: swift test_html_output.swift 56582692 142188587")
    exit(1)
}

let url = URL(string: "https://archiveofourown.org/works/\(workID)/chapters/\(chapterID)?view_adult=true")!
print("Fetching: \(url)\n")

let task = URLSession.shared.dataTask(with: url) { data, response, error in
    if let error = error {
        print("Error: \(error)")
        exit(1)
    }

    guard let data = data,
          let html = String(data: data, encoding: .utf8) else {
        print("Failed to get data")
        exit(1)
    }

    // Find the article content
    if let articleStart = html.range(of: "<div class=\"userstuff module\""),
       let articleEnd = html.range(of: "</div>", range: articleStart.upperBound..<html.endIndex) {
        let articleHTML = String(html[articleStart.lowerBound..<articleEnd.upperBound])

        print("=== RAW HTML FROM AO3 ===")
        print(articleHTML)
        print("\n=== SAMPLE PARAGRAPHS ===")

        // Extract first few paragraphs to show formatting
        let regex = try! NSRegularExpression(pattern: "<p[^>]*>(.*?)</p>", options: [.dotMatchesLineSeparators])
        let nsString = articleHTML as NSString
        let matches = regex.matches(in: articleHTML, range: NSRange(location: 0, length: nsString.length))

        for (index, match) in matches.prefix(5).enumerated() {
            if match.numberOfRanges > 1 {
                let paragraphHTML = nsString.substring(with: match.range(at: 1))
                print("\nParagraph \(index + 1):")
                print(paragraphHTML)
            }
        }
    } else {
        print("Could not find article content in HTML")
    }

    exit(0)
}

task.resume()
RunLoop.main.run()
