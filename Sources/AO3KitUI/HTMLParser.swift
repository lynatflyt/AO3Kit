import Foundation
import SwiftSoup

/// Converts HTML string to HTMLNode tree
public struct HTMLParser: Sendable {

    /// Parse HTML string into intermediate representation
    public static func parse(_ html: String, workSkin: WorkSkin = WorkSkin()) throws -> [HTMLNode] {
        // Wrap in a uniquely-identified div to ensure we get the right root
        let wrappedHTML = "<div id=\"ao3kit-parser-root\">\(html)</div>"
        let document = try SwiftSoup.parse(wrappedHTML)
        guard let root = try document.select("#ao3kit-parser-root").first() else {
            return []
        }

        return try parseChildElements(of: root, style: TextStyle(), workSkin: workSkin)
    }

    /// Parse direct child elements of a container, respecting webContent boundaries
    private static func parseChildElements(of container: Element, style: TextStyle, workSkin: WorkSkin) throws -> [HTMLNode] {
        var nodes: [HTMLNode] = []

        for child in container.getChildNodes() {
            if let element = child as? Element {
                nodes.append(contentsOf: try parseElement(element, style: style, workSkin: workSkin))
            } else if let textNode = child as? TextNode {
                let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    nodes.append(.text(text))
                }
            }
        }

        return nodes
    }

    /// Parse a single element recursively
    private static func parseElement(_ element: Element, style: TextStyle, workSkin: WorkSkin) throws -> [HTMLNode] {
        let tag = element.tagName().lowercased()

        switch tag {
        // Block elements
        case "p":
            return [.paragraph(children: try parseChildren(element, style: style, workSkin: workSkin))]

        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(tag.dropFirst()) ?? 1
            return [.heading(level: level, children: try parseChildren(element, style: style, workSkin: workSkin))]

        case "blockquote":
            return [.blockquote(children: try parseChildren(element, style: style, workSkin: workSkin))]

        case "pre":
            // Check if it contains a <code> child
            if let codeElement = try? element.select("code").first() {
                let codeText = try codeElement.text()
                let language = try? codeElement.attr("class").replacingOccurrences(of: "language-", with: "")
                return [.codeBlock(code: codeText, language: language?.isEmpty == false ? language : nil)]
            } else {
                return [.preformatted(text: try element.text())]
            }

        case "code":
            // Inline code
            var codeStyle = style
            codeStyle.isCode = true
            return [.formatted(children: try parseChildren(element, style: codeStyle, workSkin: workSkin), style: codeStyle)]

        case "hr":
            return [.horizontalRule]

        case "ul":
            let items = try element.select("> li").map { li in
                try parseChildren(li, style: style, workSkin: workSkin)
            }
            return [.list(ordered: false, items: items)]

        case "ol":
            let items = try element.select("> li").map { li in
                try parseChildren(li, style: style, workSkin: workSkin)
            }
            return [.list(ordered: true, items: items)]

        case "li":
            // Usually handled by ul/ol, but support standalone
            return [.listItem(children: try parseChildren(element, style: style, workSkin: workSkin))]

        case "div":
            // Check if this is an AO3 structural div (parse inside) or a work-skin styled div (webContent)
            let className = (try? element.className()) ?? ""

            // AO3 structural classes - these are containers, parse inside them
            let ao3StructuralClasses = [
                "chapter", "preface", "group", "userstuff", "module", "notes",
                "end", "endnotes", "summary", "byline", "landmark", "wrapper",
                "meta", "tags", "stats", "series", "associations", "children",
                "parent", "work", "header", "footer", "nav", "navigation"
            ]

            // Check if ALL of the div's classes are AO3 structural classes
            let divClasses = className.split(separator: " ").map { String($0).lowercased() }
            let isStructuralDiv = !divClasses.isEmpty && divClasses.allSatisfy { divClass in
                ao3StructuralClasses.contains(where: { divClass.contains($0) })
            }

            if isStructuralDiv || className.isEmpty {
                // This is a structural container or unstyled div - parse its children
                return try parseChildElements(of: element, style: style, workSkin: workSkin)
            } else {
                // This is a work-skin styled div (like wpp, article, etc.) - capture as webContent
                let rawHTML = try element.outerHtml()
                return [.webContent(rawHTML: rawHTML, elementType: .unknownBlock)]
            }

        case "details":
            let summary = try element.select("> summary").first()
            let summaryNodes = summary != nil ? try parseChildren(summary!, style: style, workSkin: workSkin) : [.text("Details")]

            // Get all children except summary
            var contentNodes: [HTMLNode] = []
            for child in element.getChildNodes() {
                if let elem = child as? Element, elem.tagName() != "summary" {
                    contentNodes.append(contentsOf: try parseElement(elem, style: style, workSkin: workSkin))
                }
            }

            return [.details(summary: summaryNodes, content: contentNodes)]

        case "summary":
            // Handled by details
            return try parseChildren(element, style: style, workSkin: workSkin)

        // Inline formatting elements
        case "strong", "b":
            var boldStyle = style
            boldStyle.isBold = true
            return [.formatted(children: try parseChildren(element, style: boldStyle, workSkin: workSkin), style: boldStyle)]

        case "em", "i":
            var italicStyle = style
            italicStyle.isItalic = true
            return [.formatted(children: try parseChildren(element, style: italicStyle, workSkin: workSkin), style: italicStyle)]

        case "u", "ins":
            var underlineStyle = style
            underlineStyle.isUnderlined = true
            return [.formatted(children: try parseChildren(element, style: underlineStyle, workSkin: workSkin), style: underlineStyle)]

        case "s", "strike", "del":
            var strikeStyle = style
            strikeStyle.isStrikethrough = true
            return [.formatted(children: try parseChildren(element, style: strikeStyle, workSkin: workSkin), style: strikeStyle)]

        case "sup":
            var supStyle = style
            supStyle.isSuperscript = true
            return [.formatted(children: try parseChildren(element, style: supStyle, workSkin: workSkin), style: supStyle)]

        case "sub":
            var subStyle = style
            subStyle.isSubscript = true
            return [.formatted(children: try parseChildren(element, style: subStyle, workSkin: workSkin), style: subStyle)]

        case "span":
            let className = try? element.className()
            var spanStyle = style

            // Apply color from work skin if present, otherwise use hash-based fallback
            if let className = className, !className.isEmpty {
                if let hexColor = workSkin.color(for: className) {
                    spanStyle.color = ColorInfo.fromHex(hexColor)
                } else {
                    spanStyle.color = ColorInfo.fromClassName(className)
                }
            }

            // Check for dir attribute
            if let dir = try? element.attr("dir"), dir == "rtl" {
                spanStyle.isRTL = true
            }

            let children = try parseChildren(element, style: spanStyle, workSkin: workSkin)

            // If span has styling (color, RTL), wrap in .formatted to preserve it
            // Otherwise just return children directly (span is just a container)
            if spanStyle.color != nil || spanStyle.isRTL {
                return [.formatted(children: children, style: spanStyle)]
            } else {
                return children
            }

        case "a":
            let href = try element.attr("href")
            return [.link(url: href, children: try parseChildren(element, style: style, workSkin: workSkin))]

        case "br":
            return [.lineBreak]

        // Semantic elements we can approximate
        case "cite", "q", "abbr", "var":
            // Render as italic for semantic emphasis
            var semanticStyle = style
            semanticStyle.isItalic = true
            return [.formatted(children: try parseChildren(element, style: semanticStyle, workSkin: workSkin), style: semanticStyle)]

        case "kbd", "samp":
            // Render as code (monospace)
            var codeStyle = style
            codeStyle.isCode = true
            return [.formatted(children: try parseChildren(element, style: codeStyle, workSkin: workSkin), style: codeStyle)]

        case "small":
            // Can't easily do small text in attributed string concatenation, just pass through
            return try parseChildren(element, style: style, workSkin: workSkin)

        case "big":
            // Can't easily do big text, pass through
            return try parseChildren(element, style: style, workSkin: workSkin)

        // Web content elements (rendered via WKWebView)
        case "table":
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .table)]

        case "thead", "tbody", "tr", "th", "td":
            // These should be handled by their parent table element
            // If we encounter them standalone, wrap them
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .table)]

        case "img":
            let src = (try? element.attr("src")) ?? ""
            let alt = try? element.attr("alt")
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .image(src: src, alt: alt))]

        case "ruby":
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .ruby)]

        case "rt", "rp":
            // These should be handled by their parent ruby element
            // If encountered standalone, treat as web content
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .ruby)]

        case "figure", "figcaption":
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .figure)]

        case "embed", "object", "iframe", "video", "audio":
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .embed)]

        default:
            // Unknown/unrecognized tag - don't parse inside, just capture as web content
            let rawHTML = try element.outerHtml()
            return [.webContent(rawHTML: rawHTML, elementType: .unknownBlock)]
        }
    }

    /// Parse all children of an element
    private static func parseChildren(_ element: Element, style: TextStyle, workSkin: WorkSkin) throws -> [HTMLNode] {
        var result: [HTMLNode] = []
        let children = element.getChildNodes()
        let parentTag = element.tagName().lowercased()
        let parentIsBlock = isBlockTag(parentTag)

        for (index, child) in children.enumerated() {
            if let textNode = child as? TextNode {
                // Use getWholeText() to preserve whitespace at boundaries between elements
                // e.g., "This is <b>bold</b> text" should keep spaces around "bold"
                var text = textNode.getWholeText()

                // Normalize excessive whitespace (newlines, multiple spaces) to single space
                text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

                // Skip whitespace-only text nodes that are just formatting whitespace
                // ONLY for block-level parents - inline elements (span, em, etc.) preserve trailing spaces
                if text == " " && parentIsBlock {
                    let isFirst = index == 0
                    let isLast = index == children.count - 1

                    // Check if adjacent to block-level elements
                    let prevIsBlock = index > 0 && isBlockElement(children[index - 1])
                    let nextIsBlock = index < children.count - 1 && isBlockElement(children[index + 1])

                    // Skip if it's just formatting whitespace around blocks or at boundaries of block parents
                    if isFirst || isLast || prevIsBlock || nextIsBlock {
                        continue
                    }
                }

                if !text.isEmpty && text != " " || (text == " " && !result.isEmpty) {
                    result.append(.text(text))
                }
            } else if let elem = child as? Element {
                result.append(contentsOf: try parseElement(elem, style: style, workSkin: workSkin))
            }
        }

        return result
    }

    /// Check if a tag name is a block-level element
    private static func isBlockTag(_ tag: String) -> Bool {
        let blockTags = ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre", "ul", "ol", "li", "hr", "table", "details", "figure", "article", "section", "header", "footer", "nav", "main", "aside"]
        return blockTags.contains(tag)
    }

    /// Check if a node is a block-level element
    private static func isBlockElement(_ node: Node) -> Bool {
        guard let element = node as? Element else { return false }
        let tag = element.tagName().lowercased()
        let blockTags = ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre", "ul", "ol", "li", "hr", "br", "table", "details"]
        return blockTags.contains(tag)
    }

    /// Extract attributes from element
    private static func extractAttributes(_ element: Element) throws -> [String: String] {
        var attrs: [String: String] = [:]

        if let dir = try? element.attr("dir"), !dir.isEmpty {
            attrs["dir"] = dir
        }

        if let align = try? element.attr("align"), !align.isEmpty {
            attrs["align"] = align
        }

        if let className = try? element.className(), !className.isEmpty {
            attrs["class"] = className
        }

        return attrs
    }
}
