import Foundation

/// Sample chapters for testing and SwiftUI previews
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension AO3MockData {
    /// A sample chapter with plain text
    public static let sampleChapter1: AO3Chapter = {
        let chapter = try! AO3MockDataFactory.createMockChapter(
            workID: 1000001,
            chapterID: 2000001,
            title: "Chapter 1: New Beginnings",
            summary: "Our heroes meet for the first time.",
            content: """
            The sun was setting over the horizon, painting the sky in shades of orange and pink.

            "This is it," Character A said, adjusting their backpack. "The start of our adventure."

            Character B nodded, a small smile playing on their lips. "I'm ready. Are you?"

            "Always," came the reply.

            Together, they stepped forward into the unknown, ready to face whatever challenges lay ahead.
            """,
            notes: ["Author's Note: Thanks for reading! Updates every Monday."]
        )
        return chapter
    }()

    /// A sample chapter with formatted HTML content
    public static let sampleChapter2: AO3Chapter = {
        let chapter = try! AO3MockDataFactory.createMockChapter(
            workID: 1000002,
            chapterID: 2000002,
            title: "Chapter 2: The First Meeting",
            summary: "A chance encounter at the coffee shop.",
            content: "\"Hi, can I get a latte?\" Character D asked.\n\nCharacter E smiled warmly. \"Of course! Coming right up.\"\n\nThere was something about that smile that made Character D's heart skip a beat.",
            contentHTML: """
            <span class="DialogueD">"Hi, can I get a latte?"</span> Character D asked.

            <span class="DialogueE">Character E smiled warmly. "Of course! <em>Coming right up.</em>"</span>

            There was something about that smile that made Character D's heart <strong>skip a beat</strong>.
            """,
            notes: ["Content Warning: Excessive caffeine consumption"]
        )
        return chapter
    }()

    /// A sample chapter with rich formatting
    public static let sampleChapterFormatted: AO3Chapter = {
        let chapter = try! AO3MockDataFactory.createMockChapter(
            workID: 1000003,
            chapterID: 2000003,
            title: "Chapter 5: The Confrontation",
            summary: "The truth comes out.",
            content: "\"You lied to me,\" Character F said quietly.\n\n\"I had to,\" Character G replied. \"You wouldn't have understood.\"\n\n\"Try me.\"\n\nThere was a long pause before Character G spoke again. \"I was trying to protect you.\"",
            contentHTML: """
            <h3>The Confrontation</h3>

            <p><span class="SpeakerF">"You <em>lied</em> to me,"</span> Character F said quietly.</p>

            <p><span class="SpeakerG">"I had to,"</span> Character G replied. <span class="SpeakerG">"You wouldn't have understood."</span></p>

            <p><span class="SpeakerF">"<strong>Try me.</strong>"</span></p>

            <p>There was a long pause before Character G spoke again. <span class="SpeakerG">"I was trying to <em>protect</em> you."</span></p>

            <h4>What Happened Next</h4>

            <p>The silence stretched between them, heavy and oppressive. Character F's eyes searched Character G's face, looking for <strong>any sign</strong> of the truth.</p>

            <p>"You don't trust me," Character F finally said, their voice barely above a whisper.</p>

            <p><span class="SpeakerG">"I trust you with my <em>life</em>,"</span> Character G responded. <span class="SpeakerG">"That's exactly why I did what I did."</span></p>
            """,
            notes: ["TW: Emotional confrontation", "Next chapter coming soon!"]
        )
        return chapter
    }()

    /// Array of sample chapters
    public static let sampleChapters: [AO3Chapter] = [
        sampleChapter1,
        sampleChapter2,
        sampleChapterFormatted
    ]
}
