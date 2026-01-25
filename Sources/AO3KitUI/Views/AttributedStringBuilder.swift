import UIKit // Added unconditionally
import SwiftUI

/// Converts HTMLNode tree to a single NSAttributedString for UITextView rendering
struct AttributedStringBuilder {
    
    /// Build an NSAttributedString from HTMLNode array
    static func build(
        from nodes: [HTMLNode],
        baseStyle: TextStyle,
        fontSize: CGFloat,
        fontDesign: UIFontDescriptor.SystemDesign,
        textColor: UIColor,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        let context = BuilderContext(
            baseStyle: baseStyle,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            alignment: alignment
        )
        
        for node in nodes {
            result.append(buildNode(node, context: context))
        }
        
        // Trim trailing newlines
        while result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        
        return result
    }
    
    // MARK: - Internal Builder
    
    private struct BuilderContext {
        var baseStyle: TextStyle
        var fontSize: CGFloat
        var fontDesign: UIFontDescriptor.SystemDesign
        var textColor: UIColor
        var alignment: NSTextAlignment
        var indentLevel: Int = 0
        var listDepth: Int = 0
    }
    
    private static func buildNode(_ node: HTMLNode, context: BuilderContext) -> NSAttributedString {
        switch node {
        // --- Block Elements ---
        case .paragraph(let children):
            let text = buildChildren(children, context: context)
            return applyBlockStyle(text, context: context, marginBottom: 12)
            
        case .heading(let level, let children):
            var headingContext = context
            // Scale font size based on level
            let multiplier = fontSizeForHeading(level)
            headingContext.fontSize *= multiplier
            headingContext.baseStyle.isBold = true
            
            let text = buildChildren(children, context: headingContext)
            return applyBlockStyle(text, context: headingContext, marginBottom: 12, marginTop: 8)
            
        case .blockquote(let children):
            var quoteContext = context
            quoteContext.indentLevel += 1
            // Optional: make blockquotes italic or lighter
            // quoteContext.baseStyle.isItalic = true
            
            let text = buildChildren(children, context: quoteContext)
            return applyBlockStyle(text, context: quoteContext, marginBottom: 12)
            
        case .codeBlock(let code, _):
            var codeContext = context
            codeContext.baseStyle.isCode = true
            // Use monospace font design
            codeContext.fontDesign = .monospaced
            
            let text = NSAttributedString(string: code, attributes: attributes(for: codeContext.baseStyle, context: codeContext))
            return applyBlockStyle(text, context: codeContext, marginBottom: 12)
            
        case .preformatted(let textString):
            var preContext = context
            preContext.fontDesign = .monospaced
            let text = NSAttributedString(string: textString, attributes: attributes(for: preContext.baseStyle, context: preContext))
            return applyBlockStyle(text, context: preContext, marginBottom: 12)
            
        case .horizontalRule:
            // Render as a centered line of dashes or similar
            let paraStyle = NSMutableParagraphStyle()
            paraStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .paragraphStyle: paraStyle,
                .foregroundColor: context.textColor.withAlphaComponent(0.5),
                .font: UIFont.systemFont(ofSize: context.fontSize)
            ]
            return NSAttributedString(string: "\n─────\n", attributes: attrs)
            
        case .list(let ordered, let items):
            let result = NSMutableAttributedString()
            var listContext = context
            listContext.listDepth += 1
            listContext.indentLevel += 1
            
            for (index, item) in items.enumerated() {
                let prefix = ordered ? "\(index + 1). " : "• "
                let prefixAttr = NSAttributedString(string: prefix, attributes: attributes(for: listContext.baseStyle, context: listContext))
                
                let itemContent = buildChildren(item, context: listContext)
                
                let line = NSMutableAttributedString()
                line.append(prefixAttr)
                line.append(itemContent)
                
                result.append(applyBlockStyle(line, context: listContext, marginBottom: 4))
            }
            return result
            
        case .listItem(let children):
            // Should usually be handled inside .list, but just in case
            let text = buildChildren(children, context: context)
            return applyBlockStyle(text, context: context, marginBottom: 4)
            
        case .div(let children, let attributes):
            // Check alignment attribute
            var divContext = context
            if let align = attributes["align"] {
                divContext.alignment = alignment(from: align)
            }
            return buildChildren(children, context: divContext)
            
        case .details(let summary, let content):
            // Render summary as bold, content indented
            let result = NSMutableAttributedString()
            
            var summaryContext = context
            summaryContext.baseStyle.isBold = true
            let summaryText = buildChildren(summary, context: summaryContext)
            result.append(applyBlockStyle(summaryText, context: summaryContext, marginBottom: 4))
            
            var contentContext = context
            contentContext.indentLevel += 1
            let contentText = buildChildren(content, context: contentContext)
            result.append(contentText)
            
            return result

        // --- Inline Elements ---
        case .text(let string):
            return NSAttributedString(string: string, attributes: attributes(for: context.baseStyle, context: context))
            
        case .formatted(let children, let nodeStyle):
            var childContext = context
            childContext.baseStyle = context.baseStyle.merging(nodeStyle)
            return buildChildren(children, context: childContext)
            
        case .link(_, let children):
            var linkContext = context
            linkContext.baseStyle.isUnderlined = true
            linkContext.baseStyle.color = ColorInfo(red: 0, green: 0.478, blue: 1.0)
            return buildChildren(children, context: linkContext)
            
        case .span(let children, _):
            return buildChildren(children, context: context)
            
        case .lineBreak:
            return NSAttributedString(string: "\n", attributes: attributes(for: context.baseStyle, context: context))
        }
    }
    
    private static func buildChildren(_ nodes: [HTMLNode], context: BuilderContext) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for node in nodes {
            result.append(buildNode(node, context: context))
        }
        return result
    }
    
    // MARK: - Styling Helpers
    
    private static func applyBlockStyle(_ text: NSAttributedString, context: BuilderContext, marginBottom: CGFloat = 0, marginTop: CGFloat = 0) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        
        // Ensure it ends with newline if it's a block
        if !result.string.hasSuffix("\n") {
            result.append(NSAttributedString(string: "\n", attributes: attributes(for: context.baseStyle, context: context)))
        }
        
        // Add margin using line spacing (approximate)?
        // Better: Apply paragraph style to the WHOLE range
        
        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = context.alignment
        pStyle.lineBreakMode = .byWordWrapping
        pStyle.lineHeightMultiple = 1.2
        pStyle.hyphenationFactor = 1.0
        pStyle.paragraphSpacing = marginBottom
        pStyle.paragraphSpacingBefore = marginTop
        
        // Indentation
        let indentSize: CGFloat = 20.0
        let indent = CGFloat(context.indentLevel) * indentSize
        if indent > 0 {
            pStyle.firstLineHeadIndent = indent
            pStyle.headIndent = indent
        }
        
        result.addAttribute(.paragraphStyle, value: pStyle, range: NSRange(location: 0, length: result.length))
        
        return result
    }
    
    private static func attributes(for style: TextStyle, context: BuilderContext) -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [:]
        
        // Font
        var traits: UIFontDescriptor.SymbolicTraits = []
        if style.isBold { traits.insert(.traitBold) }
        if style.isItalic { traits.insert(.traitItalic) }
        
        var fontDesign = context.fontDesign
        if style.isCode { fontDesign = .monospaced }
        
        var baseFont = UIFont.systemFont(ofSize: context.fontSize)
        if let descriptor = baseFont.fontDescriptor.withDesign(fontDesign) {
            baseFont = UIFont(descriptor: descriptor, size: context.fontSize)
        }
        
        if !traits.isEmpty, let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
            attrs[.font] = UIFont(descriptor: descriptor, size: context.fontSize)
        } else {
            attrs[.font] = baseFont
        }
        
        // Color
        if let colorInfo = style.color {
            attrs[.foregroundColor] = UIColor(
                red: colorInfo.red,
                green: colorInfo.green,
                blue: colorInfo.blue,
                alpha: 1.0
            )
        } else {
            attrs[.foregroundColor] = context.textColor
        }
        
        // Decoration
        if style.isUnderlined {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if style.isStrikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if style.isSuperscript {
            attrs[.baselineOffset] = context.fontSize * 0.3
            attrs[.font] = (attrs[.font] as? UIFont)?.withSize(context.fontSize * 0.7)
        }
        if style.isSubscript {
            attrs[.baselineOffset] = -(context.fontSize * 0.2)
            attrs[.font] = (attrs[.font] as? UIFont)?.withSize(context.fontSize * 0.7)
        }
        
        return attrs
    }
    
    private static func fontSizeForHeading(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 2.0
        case 2: return 1.65
        case 3: return 1.35
        case 4: return 1.18
        case 5: return 1.06
        case 6: return 0.94
        default: return 1.0
        }
    }
    
    private static func alignment(from string: String) -> NSTextAlignment {
        switch string.lowercased() {
        case "center": return .center
        case "right": return .right
        case "left": return .left
        case "justify": return .justified
        default: return .left
        }
    }
}

