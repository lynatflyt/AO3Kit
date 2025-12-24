import Foundation
import SwiftSoup

/// Parses AO3 chapter HTML into structured data
internal struct AO3ChapterParser {
    func parse(document: Document, into chapter: AO3Chapter) throws {
        let (number, title) = try parseChapterInfo(from: document)
        chapter.number = number
        chapter.title = title
        chapter.content = try parseContent(from: document)
        chapter.contentHTML = try parseContentHTML(from: document)
        chapter.notes = try parseNotes(from: document)
        chapter.summary = try parseSummary(from: document)
    }

    // MARK: - Parsing Methods

    private func parseChapterInfo(from document: Document) throws -> (number: Int, title: String) {
        guard let prefaceDiv = try document.select("div.chapter.preface.group").first(),
              let h3 = try prefaceDiv.select("h3").first() else {
            return (1, "")
        }

        // Get full text like "Chapter 1: The Text"
        let fullText = try h3.text().trimmingCharacters(in: .whitespaces)

        // Use regex to extract chapter number and title
        // Pattern matches "Chapter <number>: <title>" or just "Chapter <number>"
        let pattern = #"^Chapter\s+(\d+)(?::\s*(.*))?$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)) {

            // Extract chapter number
            var chapterNumber = 1
            if let numberRange = Range(match.range(at: 1), in: fullText) {
                chapterNumber = Int(fullText[numberRange]) ?? 1
            }

            // Extract title (if present after colon)
            var chapterTitle = ""
            if match.numberOfRanges > 2,
               let titleRange = Range(match.range(at: 2), in: fullText) {
                chapterTitle = String(fullText[titleRange]).trimmingCharacters(in: .whitespaces)
            }

            return (chapterNumber, chapterTitle)
        }

        // Fallback: if pattern doesn't match, return defaults
        return (1, fullText)
    }

    private func parseContent(from document: Document) throws -> String {
        if let article = try document.select("[role=article]").first() {
            let paragraphs = try article.select("p")
            let contentArray = try paragraphs.map { try $0.text() }
            return contentArray.joined(separator: "\n")
        }
        return ""
    }

    private func parseContentHTML(from document: Document) throws -> String {
        if let article = try document.select("[role=article]").first() {
            let paragraphs = try article.select("p")
            let htmlArray = try paragraphs.map { try $0.outerHtml() }
            return htmlArray.joined(separator: "\n")
        }
        return ""
    }

    private func parseNotes(from document: Document) throws -> [String] {
        var tempNotes: [String] = []
        let notesModules = try document.select("div.notes.module")

        for noteModule in notesModules {
            if let userstuff = try noteModule.select(".userstuff").first() {
                let paragraphs = try userstuff.select("p")
                let noteText = try paragraphs.map { try $0.text() }.joined(separator: "\n")
                if !noteText.isEmpty {
                    tempNotes.append(noteText)
                }
            }
        }

        return tempNotes
    }

    private func parseSummary(from document: Document) throws -> String {
        if let summaryDiv = try document.select("div.summary.module").first(),
           let blockquote = try summaryDiv.select("blockquote.userstuff").first() {
            let paragraphs = try blockquote.select("p")
            let summaryArray = try paragraphs.map { try $0.html() }
            return summaryArray.joined(separator: "\n")
        }
        return ""
    }
}
