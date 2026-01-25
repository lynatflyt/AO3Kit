import SwiftUI
import UIKit // Added unconditionally

/// A UIViewRepresentable wrapping UITextView for justified text rendering
/// The parent view is responsible for providing the correct frame size
struct AttributedTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    let backgroundColor: UIColor
    let textSelectionEnabled: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isSelectable = textSelectionEnabled
        textView.isUserInteractionEnabled = textSelectionEnabled
        // Ensure the text view can be interacted with
        textView.dataDetectorTypes = []
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedString
        textView.backgroundColor = backgroundColor
        textView.isSelectable = textSelectionEnabled
        textView.isUserInteractionEnabled = textSelectionEnabled
    }
}
