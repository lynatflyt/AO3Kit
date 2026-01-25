import SwiftUI
import UIKit

/// Renders inline text with justified alignment using UITextView
/// This is used when the user selects justified text alignment, as SwiftUI Text
/// doesn't support justified alignment natively.
struct JustifiedFormattedText: View {
    let nodes: [HTMLNode]
    let baseStyle: TextStyle
    let fontSize: CGFloat
    let fontDesign: UIFontDescriptor.SystemDesign
    let textColor: UIColor
    let backgroundColor: UIColor
    let textSelectionEnabled: Bool
    let alignment: TextAlignment

    // Pre-built attributed string for efficiency
    private let attributedString: NSAttributedString

    init(
        nodes: [HTMLNode],
        baseStyle: TextStyle,
        fontSize: CGFloat = 17,
        fontDesign: UIFontDescriptor.SystemDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textSelectionEnabled: Bool = false,
        alignment: TextAlignment = .justified
    ) {
        self.nodes = nodes
        self.baseStyle = baseStyle
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textSelectionEnabled = textSelectionEnabled
        self.alignment = alignment

        // Build attributed string once at init
        let nsAlignment = JustifiedFormattedText.nsTextAlignment(from: alignment)
        self.attributedString = AttributedStringBuilder.build(
            from: nodes,
            baseStyle: baseStyle,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            alignment: nsAlignment
        )
    }

    var body: some View {
        JustifiedTextContainer(
            attributedString: attributedString,
            backgroundColor: backgroundColor,
            textSelectionEnabled: textSelectionEnabled
        )
    }

    private static func nsTextAlignment(from alignment: TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        case .justified: return .justified
        }
    }
}

/// Container view that measures width and calculates correct height
private struct JustifiedTextContainer: View {
    let attributedString: NSAttributedString
    let backgroundColor: UIColor
    let textSelectionEnabled: Bool

    @State private var height: CGFloat = 10 // Start with minimal height

    var body: some View {
        AttributedTextView(
            attributedString: attributedString,
            backgroundColor: backgroundColor,
            textSelectionEnabled: textSelectionEnabled
        )
        .frame(height: height)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: WidthPreferenceKey.self,
                    value: geometry.size.width
                )
            }
        )
        .onPreferenceChange(WidthPreferenceKey.self) { width in
            if width > 0 {
                let calculatedHeight = calculateHeight(for: width)
                if abs(calculatedHeight - height) > 1 { // Avoid unnecessary updates
                    height = calculatedHeight
                }
            }
        }
    }

    private func calculateHeight(for width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(attributedString: attributedString)
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()

        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)

        return ceil(rect.height) + 4 // Add buffer to prevent cropping
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
