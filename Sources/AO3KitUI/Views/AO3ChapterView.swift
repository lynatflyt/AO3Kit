import SwiftUI
import AO3Kit
import UIKit // Added unconditionally

/// A high-performance reader view backed by a single UITextView
///
/// This view renders the entire chapter as a single rich text document, allowing
/// for correct multi-line selection and native text handling.
public struct AO3ChapterView<Header: View, Footer: View>: UIViewRepresentable {
    private let attributedContent: NSAttributedString?
    private let parseError: Error?

    /// Unique ID for this content - used to detect when content actually changes
    /// without expensive O(n) attributed string comparison
    private let contentID: Int

    @Binding var topVisibleIndex: Int?
    let initialPosition: Int?
    let fontSize: CGFloat
    let fontDesign: AO3FontDesign
    let textColor: UIColor
    let backgroundColor: UIColor
    let textSelectionEnabled: Bool
    let textAlignment: AO3TextAlignment
    let headerView: Header?
    let footerView: Footer?

    /// Optional callback for custom "Share as Quote" functionality
    /// When provided, adds a "Share as Quote" option to the text selection menu
    /// The callback receives the selected text string
    let onShareQuote: ((String) -> Void)?

    /// Maximum character count for showing the share quote option (default: 500)
    let shareQuoteMaxLength: Int

    public init(
        html: String,
        workSkinCSS: String? = nil,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        onShareQuote: ((String) -> Void)? = nil,
        shareQuoteMaxLength: Int = 500,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        // Generate content ID from inputs that affect the attributed string
        // This avoids expensive O(n) NSAttributedString comparison
        var hasher = Hasher()
        hasher.combine(html)
        hasher.combine(workSkinCSS)
        hasher.combine(fontSize)
        hasher.combine(fontDesign)
        hasher.combine(textColor.hashValue)
        hasher.combine(textAlignment)
        self.contentID = hasher.finalize()

        do {
            self.attributedContent = try AO3HTMLRenderer.parseToAttributed(
                html,
                workSkinCSS: workSkinCSS,
                fontSize: fontSize,
                fontDesign: fontDesign,
                textColor: textColor,
                textAlignment: textAlignment
            )
            self.parseError = nil
        } catch {
            self.attributedContent = nil
            self.parseError = error
        }
        self._topVisibleIndex = topVisibleIndex
        self.initialPosition = initialPosition
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.textSelectionEnabled = textSelectionEnabled
        self.textAlignment = textAlignment
        self.onShareQuote = onShareQuote
        self.shareQuoteMaxLength = shareQuoteMaxLength
        self.headerView = header()
        self.footerView = footer()
    }

    // Convenience init for Chapter object
    public init(
        chapter: AO3Chapter,
        work: AO3Work,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        onShareQuote: ((String) -> Void)? = nil,
        shareQuoteMaxLength: Int = 500,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            html: chapter.contentHTML,
            workSkinCSS: work.workSkinCSS,
            topVisibleIndex: topVisibleIndex,
            initialPosition: initialPosition,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            backgroundColor: backgroundColor,
            textSelectionEnabled: textSelectionEnabled,
            textAlignment: textAlignment,
            onShareQuote: onShareQuote,
            shareQuoteMaxLength: shareQuoteMaxLength,
            header: header,
            footer: footer
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true // Always allow selection logic, controlled via delegate or property
        textView.backgroundColor = backgroundColor
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero

        // Remove padding to fix "cropping" issues at edges
        textView.contentInset = UIEdgeInsets(top: 0, left: 20, bottom: 80, right: 20)

        textView.delegate = context.coordinator

        // Setup Header/Footer Controllers
        if let headerView = headerView {
            let hc = UIHostingController(rootView: AnyView(headerView))
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            context.coordinator.headerController = hc
            textView.addSubview(hc.view)
        }

        if let footerView = footerView {
            let fc = UIHostingController(rootView: AnyView(footerView))
            fc.view.backgroundColor = .clear
            fc.view.translatesAutoresizingMaskIntoConstraints = false
            context.coordinator.footerController = fc
            textView.addSubview(fc.view)
        }

        return textView
    }

    public func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // Check if content actually changed using fast hash comparison (O(1))
        // instead of expensive NSAttributedString comparison (O(n))
        let contentChanged = coordinator.lastContentID != contentID
        if contentChanged {
            coordinator.lastContentID = contentID
            coordinator.needsTextHeightRecalculation = true
            textView.attributedText = attributedContent
            // Force layout to apply content insets immediately
            textView.layoutIfNeeded()
        }

        textView.backgroundColor = backgroundColor
        textView.isSelectable = textSelectionEnabled

        // Ensure horizontal content insets are always applied (fixes initial render without padding)
        if textView.contentInset.left != 20 {
            textView.contentInset.left = 20
        }
        if textView.contentInset.right != 20 {
            textView.contentInset.right = 20
        }

        // Update Headers/Footers layout
        updateLayout(textView, context: context, contentChanged: contentChanged)

        // Handle Initial Scroll
        if !coordinator.didInitialScroll, let initialPos = initialPosition {
            coordinator.didInitialScroll = true
            // Map initialPos (assumed Y offset) to scroll
            // Note: If initialPos was "paragraph index", this will be wrong.
            // We assume the caller handles the semantic change or we accept the break.
            DispatchQueue.main.async {
                textView.setContentOffset(CGPoint(x: 0, y: CGFloat(initialPos)), animated: false)
            }
        }
    }
    
    private func updateLayout(_ textView: UITextView, context: Context, contentChanged: Bool) {
        let coordinator = context.coordinator
        let width = textView.bounds.width > 0 ? textView.bounds.width : UIScreen.main.bounds.width
        let safeWidth = width - textView.contentInset.left - textView.contentInset.right

        // Check if width changed significantly
        let widthChanged = abs(coordinator.lastLayoutWidth - safeWidth) > 0.5
        if widthChanged {
            coordinator.lastLayoutWidth = safeWidth
            coordinator.needsTextHeightRecalculation = true
        }

        // Skip expensive layout operations if nothing meaningful changed
        guard contentChanged || widthChanged || coordinator.needsTextHeightRecalculation else {
            return
        }

        var topInset: CGFloat = 0

        // Layout Header - only update rootView when content changed
        if let hc = coordinator.headerController {
            if contentChanged, let headerView = headerView {
                hc.rootView = AnyView(headerView)
            }

            // Only re-measure if width changed or frame is not set
            if widthChanged || hc.view.frame.height == 0 {
                let size = hc.view.systemLayoutSizeFitting(
                    CGSize(width: safeWidth, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                hc.view.frame = CGRect(x: 0, y: 0, width: safeWidth, height: size.height)
                topInset = size.height
            } else {
                hc.view.frame = CGRect(x: 0, y: 0, width: safeWidth, height: hc.view.frame.height)
                topInset = hc.view.frame.height
            }
        }

        // Update text container
        if textView.textContainerInset.top != topInset {
            textView.textContainerInset.top = topInset
        }

        // Layout Footer
        if let fc = coordinator.footerController {
            // Always update rootView to ensure bindings (like "mark as read" button state) are reflected
            // SwiftUI's diffing will handle actual re-renders efficiently
            if let footerView = footerView {
                fc.rootView = AnyView(footerView)
            }

            // Re-measure footer size if needed
            var footerHeight = fc.view.frame.height
            if widthChanged || footerHeight == 0 {
                let size = fc.view.systemLayoutSizeFitting(
                    CGSize(width: safeWidth, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                footerHeight = size.height
            }

            // Only recalculate text height when needed (expensive operation!)
            if coordinator.needsTextHeightRecalculation {
                // Force layout before measuring to ensure accurate height
                textView.layoutIfNeeded()

                if #available(iOS 16.0, *), let textLayoutManager = textView.textLayoutManager {
                    // Use TextKit 2 if available
                    textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
                    coordinator.cachedTextHeight = textLayoutManager.usageBoundsForTextContainer.height
                } else {
                    // Fallback to contentSize
                    coordinator.cachedTextHeight = max(
                        textView.contentSize.height - textView.textContainerInset.top - textView.textContainerInset.bottom,
                        0
                    )
                }
                coordinator.needsTextHeightRecalculation = false
            }

            let footerYPos = topInset + coordinator.cachedTextHeight + 20

            // Position footer aligned with content (matching contentInset.left)
            fc.view.frame = CGRect(x: textView.contentInset.left, y: footerYPos, width: safeWidth, height: footerHeight)

            let bottomInset = footerHeight + 40
            if textView.contentInset.bottom != bottomInset {
                textView.contentInset.bottom = bottomInset
            }
        }
    }

    public class Coordinator: NSObject, UITextViewDelegate {
        var parent: AO3ChapterView
        var headerController: UIHostingController<AnyView>?
        var footerController: UIHostingController<AnyView>?
        var didInitialScroll = false
        var lastLayoutWidth: CGFloat = 0

        /// Cached content ID to detect when attributed content actually changes
        var lastContentID: Int = 0

        /// Cached text height to avoid expensive ensureLayout calls
        var cachedTextHeight: CGFloat = 0

        /// Whether text height needs recalculation (set when content changes)
        var needsTextHeightRecalculation = true

        init(_ parent: AO3ChapterView) {
            self.parent = parent
        }

        // MARK: - UITextViewDelegate

        // Only update binding when scrolling stops to prevent "multiple updates per frame" and excessive re-renders

        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateVisibleIndex(scrollView)
        }

        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                updateVisibleIndex(scrollView)
            }
        }

        private func updateVisibleIndex(_ scrollView: UIScrollView) {
            let newIndex = Int(scrollView.contentOffset.y)
            if parent.topVisibleIndex != newIndex {
                parent.topVisibleIndex = newIndex
            }
        }

        // MARK: - Edit Menu Customization

        /// Adds "Share as Quote" option to text selection menu (iOS 16+)
        public func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            // Only add share option if callback is provided
            guard let onShareQuote = parent.onShareQuote else {
                return UIMenu(children: suggestedActions)
            }

            // Get selected text and validate length
            guard let text = textView.text,
                  let swiftRange = Range(range, in: text) else {
                return UIMenu(children: suggestedActions)
            }

            let selectedText = String(text[swiftRange])

            // Don't show option if selection is empty or too long
            guard !selectedText.isEmpty,
                  selectedText.count <= parent.shareQuoteMaxLength else {
                return UIMenu(children: suggestedActions)
            }

            let shareAction = UIAction(
                title: "Share as Quote",
                image: UIImage(systemName: "quote.bubble")
            ) { _ in
                onShareQuote(selectedText)
            }

            return UIMenu(children: suggestedActions + [shareAction])
        }
    }
}

// MARK: - Extensions for Init

extension AO3ChapterView where Footer == EmptyView {
    public init(
        html: String,
        workSkinCSS: String? = nil,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        onShareQuote: ((String) -> Void)? = nil,
        shareQuoteMaxLength: Int = 500,
        @ViewBuilder header: () -> Header
    ) {
        self.init(
            html: html,
            workSkinCSS: workSkinCSS,
            topVisibleIndex: topVisibleIndex,
            initialPosition: initialPosition,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            backgroundColor: backgroundColor,
            textSelectionEnabled: textSelectionEnabled,
            textAlignment: textAlignment,
            onShareQuote: onShareQuote,
            shareQuoteMaxLength: shareQuoteMaxLength,
            header: header,
            footer: { EmptyView() }
        )
    }

    public init(
        chapter: AO3Chapter,
        work: AO3Work,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        onShareQuote: ((String) -> Void)? = nil,
        shareQuoteMaxLength: Int = 500,
        @ViewBuilder header: () -> Header
    ) {
        self.init(
            chapter: chapter,
            work: work,
            topVisibleIndex: topVisibleIndex,
            initialPosition: initialPosition,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            backgroundColor: backgroundColor,
            textSelectionEnabled: textSelectionEnabled,
            textAlignment: textAlignment,
            onShareQuote: onShareQuote,
            shareQuoteMaxLength: shareQuoteMaxLength,
            header: header,
            footer: { EmptyView() }
        )
    }
}

extension AO3ChapterView where Header == EmptyView, Footer == EmptyView {
    public init(
        html: String,
        workSkinCSS: String? = nil,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        onShareQuote: ((String) -> Void)? = nil,
        shareQuoteMaxLength: Int = 500
    ) {
        self.init(
            html: html,
            workSkinCSS: workSkinCSS,
            topVisibleIndex: topVisibleIndex,
            initialPosition: initialPosition,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            backgroundColor: backgroundColor,
            textSelectionEnabled: textSelectionEnabled,
            textAlignment: textAlignment,
            onShareQuote: onShareQuote,
            shareQuoteMaxLength: shareQuoteMaxLength,
            header: { EmptyView() },
            footer: { EmptyView() }
        )
    }

    public init(
        chapter: AO3Chapter,
        work: AO3Work,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        textSelectionEnabled: Bool = false,
        textAlignment: AO3TextAlignment = .leading,
        onShareQuote: ((String) -> Void)? = nil,
        shareQuoteMaxLength: Int = 500
    ) {
        self.init(
            chapter: chapter,
            work: work,
            topVisibleIndex: topVisibleIndex,
            initialPosition: initialPosition,
            fontSize: fontSize,
            fontDesign: fontDesign,
            textColor: textColor,
            backgroundColor: backgroundColor,
            textSelectionEnabled: textSelectionEnabled,
            textAlignment: textAlignment,
            onShareQuote: onShareQuote,
            shareQuoteMaxLength: shareQuoteMaxLength,
            header: { EmptyView() },
            footer: { EmptyView() }
        )
    }
}
