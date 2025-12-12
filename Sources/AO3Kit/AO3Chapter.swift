import Foundation
import SwiftSoup

/// Object exposing information about a chapter. Contains the title, the content itself and author notes.
public class AO3Chapter: AO3Data, @unchecked Sendable {
    public let workID: Int
    public let id: Int
    public private(set) var title: String = ""
    public private(set) var content: String = ""
    public private(set) var notes: [String] = []
    public private(set) var summary: String = ""

    internal init(workID: Int, chapterID: Int) async throws {
        self.workID = workID
        self.id = chapterID
        super.init()
        try await loadChapterData()
    }

    private enum CodingKeys: String, CodingKey {
        case workID, id, title, content, notes, summary
    }

    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workID = try container.decode(Int.self, forKey: .workID)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        notes = try container.decode([String].self, forKey: .notes)
        summary = try container.decode(String.self, forKey: .summary)
        super.init()
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(workID, forKey: .workID)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(notes, forKey: .notes)
        try container.encode(summary, forKey: .summary)
    }

    private func loadChapterData() async throws {
        let document = try await getDocument()

        // Parse title
        if let prefaceDiv = try document.select("div.chapter.preface.group").first(),
           let h3 = try prefaceDiv.select("h3").first() {
            let ownText = h3.ownText()
            title = ownText.replacingOccurrences(of: ": ", with: "").trimmingCharacters(in: .whitespaces)
        }

        // Parse content
        if let article = try document.select("[role=article]").first() {
            let paragraphs = try article.select("p")
            let contentArray = try paragraphs.map { try $0.text() }
            content = contentArray.joined(separator: "\n")
        }

        // Parse notes
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
        notes = tempNotes

        // Parse summary
        if let summaryDiv = try document.select("div.summary.module").first(),
           let blockquote = try summaryDiv.select("blockquote.userstuff").first() {
            let paragraphs = try blockquote.select("p")
            let summaryArray = try paragraphs.map { try $0.html() }
            summary = summaryArray.joined(separator: "\n")
        }
    }

    internal override func buildURL() -> String {
        return "https://archiveofourown.org/works/\(workID)/chapters/\(id)"
    }
}
