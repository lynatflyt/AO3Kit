import Foundation
import SwiftSoup

/// Parses AO3 chapter HTML into structured data
internal struct AO3ChapterParser {
    func parse(document: Document, into chapter: AO3Chapter) throws {
        chapter.title = try parseTitle(from: document)
        chapter.content = try parseContent(from: document)
        chapter.contentHTML = try parseContentHTML(from: document)
        chapter.notes = try parseNotes(from: document)
        chapter.summary = try parseSummary(from: document)
    }

    // MARK: - Parsing Methods

    private func parseTitle(from document: Document) throws -> String {
        if let prefaceDiv = try document.select("div.chapter.preface.group").first(),
           let h3 = try prefaceDiv.select("h3").first() {
            let ownText = h3.ownText()
            return ownText.replacingOccurrences(of: ": ", with: "").trimmingCharacters(in: .whitespaces)
        }
        return ""
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
