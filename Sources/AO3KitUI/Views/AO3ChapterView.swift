import SwiftUI
import AO3Kit
import UIKit
import WebKit

/// A high-performance reader view that supports both native text and web content
///
/// This view renders chapter content as a composite of UITextViews (for native text)
/// and WKWebViews (for tables, images, and other web content).
public struct AO3ChapterView<Header: View, Footer: View>: UIViewRepresentable {
    private let segments: [ContentSegment]
    private let workSkinCSS: String?
    private let parseError: Error?

    /// Unique ID for this content - used to detect when content actually changes
    private let contentID: Int

    @Binding var topVisibleIndex: Int?
    let initialPosition: Int?
    let fontSize: CGFloat
    let fontDesign: AO3FontDesign
    let textColor: UIColor
    let backgroundColor: UIColor
    let textAlignment: AO3TextAlignment
    let headerView: Header?
    let footerView: Footer?

    /// Optional callback for custom "Share as Quote" functionality
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
        textAlignment: AO3TextAlignment = .leading,
        onShareQuote: ((String) -> Void)? = nil,
        shareQuoteMaxLength: Int = 500,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        // Generate content ID from inputs
        var hasher = Hasher()
        hasher.combine(html)
        hasher.combine(workSkinCSS)
        hasher.combine(fontSize)
        hasher.combine(fontDesign)
        hasher.combine(textColor.hashValue)
        hasher.combine(textAlignment)
        self.contentID = hasher.finalize()

        self.workSkinCSS = workSkinCSS

        do {
            let workSkin = CSSParser.parse(workSkinCSS)
            let nodes = try HTMLParser.parse(html, workSkin: workSkin)
            self.segments = ContentSegmenter.segment(nodes)
            self.parseError = nil
        } catch {
            self.segments = []
            self.parseError = error
        }

        self._topVisibleIndex = topVisibleIndex
        self.initialPosition = initialPosition
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.textColor = textColor
        self.backgroundColor = backgroundColor
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

    public func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = backgroundColor
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        context.coordinator.stackView = stackView

        // Setup constraints
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -80),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        // Setup Header
        if let headerView = headerView {
            let hc = UIHostingController(rootView: AnyView(headerView))
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false
            context.coordinator.headerController = hc
            stackView.addArrangedSubview(hc.view)
        }

        return scrollView
    }

    public func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // Check if content actually changed
        let contentChanged = coordinator.lastContentID != contentID
        if contentChanged {
            coordinator.lastContentID = contentID
            rebuildContent(scrollView, context: context)
        }

        scrollView.backgroundColor = backgroundColor

        // Update header if needed
        if let hc = coordinator.headerController, let headerView = headerView {
            hc.rootView = AnyView(headerView)
        }

        // Update footer if needed
        if let fc = coordinator.footerController, let footerView = footerView {
            fc.rootView = AnyView(footerView)
        }

        // Handle Initial Scroll
        if !coordinator.didInitialScroll, let initialPos = initialPosition {
            coordinator.didInitialScroll = true
            DispatchQueue.main.async {
                scrollView.setContentOffset(CGPoint(x: 0, y: CGFloat(initialPos)), animated: false)
            }
        }
    }

    private func rebuildContent(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        guard let stackView = coordinator.stackView else { return }

        // Clear existing segment views (keep header)
        for view in coordinator.segmentViews {
            view.removeFromSuperview()
        }
        coordinator.segmentViews.removeAll()
        coordinator.webViewHeights.removeAll()

        // Remove footer if exists
        if let fc = coordinator.footerController {
            fc.view.removeFromSuperview()
        }

        // Convert alignment
        let nsAlignment: NSTextAlignment
        switch textAlignment {
        case .leading: nsAlignment = .left
        case .center: nsAlignment = .center
        case .trailing: nsAlignment = .right
        case .justified: nsAlignment = .justified
        }

        // Add segments
        for segment in segments {
            switch segment {
            case .nativeText(let nodes, let id):
                let textView = createTextView(for: nodes, alignment: nsAlignment, context: context)
                stackView.addArrangedSubview(textView)
                coordinator.segmentViews.append(textView)
                coordinator.segmentIDToView[id] = textView

            case .webContent(let html, _, let id):
                let webViewContainer = createWebViewContainer(for: html, id: id, context: context)
                stackView.addArrangedSubview(webViewContainer)
                coordinator.segmentViews.append(webViewContainer)
                coordinator.segmentIDToView[id] = webViewContainer
            }
        }

        // Add footer
        if let footerView = footerView {
            let fc = UIHostingController(rootView: AnyView(footerView))
            fc.view.backgroundColor = .clear
            fc.view.translatesAutoresizingMaskIntoConstraints = false
            coordinator.footerController = fc
            stackView.addArrangedSubview(fc.view)
        }
    }

    private func createTextView(for nodes: [HTMLNode], alignment: NSTextAlignment, context: Context) -> UITextView {
        let textView = ShareableTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0

        // Set up share quote callback
        textView.onShareQuote = onShareQuote
        textView.shareQuoteMaxLength = shareQuoteMaxLength

        let attributedString = AttributedStringBuilder.build(
            from: nodes,
            baseStyle: TextStyle(),
            fontSize: fontSize,
            fontDesign: fontDesign.uiFontDescriptorDesign,
            textColor: textColor,
            alignment: alignment
        )
        textView.attributedText = attributedString

        return textView
    }

    private func createWebViewContainer(for html: String, id: UUID, context: Context) -> UIView {
        let container = WebViewContainer(
            html: html,
            workSkinCSS: workSkinCSS,
            fontSize: fontSize,
            textColor: textColor,
            backgroundColor: backgroundColor,
            coordinator: context.coordinator,
            segmentID: id
        )
        return container
    }

    public class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: AO3ChapterView
        var stackView: UIStackView?
        var headerController: UIHostingController<AnyView>?
        var footerController: UIHostingController<AnyView>?
        var didInitialScroll = false
        var lastContentID: Int = 0

        /// Views for each content segment
        var segmentViews: [UIView] = []
        var segmentIDToView: [UUID: UIView] = [:]

        /// Track web view heights for layout
        var webViewHeights: [UUID: CGFloat] = [:]

        init(_ parent: AO3ChapterView) {
            self.parent = parent
        }

        func updateWebViewHeight(for id: UUID, height: CGFloat) {
            webViewHeights[id] = height
            if let container = segmentIDToView[id] as? WebViewContainer {
                container.updateHeight(height)
            }
        }

        // MARK: - UIScrollViewDelegate

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
    }
}

// MARK: - WebViewContainer

/// A container view that hosts a WKWebView and manages its height
class WebViewContainer: UIView, WKNavigationDelegate, WKScriptMessageHandler {
    private let webView: WKWebView
    private var heightConstraint: NSLayoutConstraint?
    private let segmentID: UUID
    private var contentHash: Int = 0

    init<Header: View, Footer: View>(
        html: String,
        workSkinCSS: String?,
        fontSize: CGFloat,
        textColor: UIColor,
        backgroundColor: UIColor,
        coordinator: AO3ChapterView<Header, Footer>.Coordinator,
        segmentID: UUID
    ) {
        self.segmentID = segmentID

        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        // Add message handler for height updates
        let userController = WKUserContentController()
        config.userContentController = userController

        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init(frame: .zero)

        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
        webView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Initial height constraint
        heightConstraint = heightAnchor.constraint(equalToConstant: 100)
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true

        // Add height message handler
        config.userContentController.add(self, name: "heightHandler")

        // Load content
        let fullHTML = buildFullHTML(
            html: html,
            workSkinCSS: workSkinCSS,
            fontSize: fontSize,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
        contentHash = html.hashValue
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateHeight(_ height: CGFloat) {
        heightConstraint?.constant = height
        setNeedsLayout()
    }

    private func buildFullHTML(
        html: String,
        workSkinCSS: String?,
        fontSize: CGFloat,
        textColor: UIColor,
        backgroundColor: UIColor
    ) -> String {
        let textColorHex = textColor.hexString
        let bgColorHex = backgroundColor.hexString

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                /* Minimal reset - don't override work skin styles */
                html, body {
                    margin: 0;
                    padding: 0;
                    background-color: \(bgColorHex);
                    color: \(textColorHex);
                    font-family: -apple-system, system-ui, sans-serif;
                    font-size: \(fontSize)px;
                    line-height: 1.5;
                    -webkit-text-size-adjust: none;
                    overflow: hidden;
                }
                body {
                    padding: 8px 0;
                }
                /* Only constrain large images, don't force block display */
                img {
                    max-width: 100%;
                    height: auto;
                }
                /* Default table styling (work skin can override) */
                table:not([class]) {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 0.5em 0;
                }
                table:not([class]) th,
                table:not([class]) td {
                    border: 1px solid \(textColorHex)40;
                    padding: 0.5em;
                    text-align: left;
                }
                table:not([class]) th {
                    background-color: \(textColorHex)10;
                    font-weight: bold;
                }
                ruby {
                    ruby-align: center;
                }
                rt {
                    font-size: 0.6em;
                }
                figure {
                    margin: 0.5em 0;
                    text-align: center;
                }
                figcaption {
                    font-size: 0.9em;
                    margin-top: 0.5em;
                }
                /* Work skin CSS - loaded after base styles so it takes precedence */
                #workskin {
                    width: 100%;
                }
                \(workSkinCSS ?? "")
            </style>
        </head>
        <body>
            <div id="workskin">
                \(html)
            </div>
            <script>
                function reportHeight() {
                    const height = document.body.scrollHeight;
                    window.webkit.messageHandlers.heightHandler.postMessage(height);
                }
                window.onload = function() {
                    // Wait for images to load
                    const images = document.getElementsByTagName('img');
                    let loadedCount = 0;
                    const totalImages = images.length;

                    if (totalImages === 0) {
                        reportHeight();
                        return;
                    }

                    for (let img of images) {
                        if (img.complete) {
                            loadedCount++;
                            if (loadedCount === totalImages) {
                                reportHeight();
                            }
                        } else {
                            img.onload = img.onerror = function() {
                                loadedCount++;
                                if (loadedCount === totalImages) {
                                    reportHeight();
                                }
                            };
                        }
                    }
                };
                new ResizeObserver(reportHeight).observe(document.body);
            </script>
        </body>
        </html>
        """
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
            if let height = result as? CGFloat, height > 0, let self = self {
                DispatchQueue.main.async {
                    self.updateHeight(height)
                }
            }
        }
        
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if message.name == "heightHandler", let height = message.body as? CGFloat {
            DispatchQueue.main.async {
                self.updateHeight(height)
            }
        }
    }
}

// MARK: - ShareableTextView

/// A UITextView subclass that supports the "Share as Quote" edit menu action
class ShareableTextView: UITextView, UITextViewDelegate {
    var onShareQuote: ((String) -> Void)?
    var shareQuoteMaxLength: Int = 500

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    func textView(
        _ textView: UITextView,
        editMenuForTextIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard let onShareQuote = onShareQuote else {
            return UIMenu(children: suggestedActions)
        }

        guard let text = textView.text,
              let swiftRange = Range(range, in: text) else {
            return UIMenu(children: suggestedActions)
        }

        let selectedText = String(text[swiftRange])

        guard !selectedText.isEmpty,
              selectedText.count <= shareQuoteMaxLength else {
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
            textAlignment: textAlignment,
            onShareQuote: onShareQuote,
            shareQuoteMaxLength: shareQuoteMaxLength,
            header: { EmptyView() },
            footer: { EmptyView() }
        )
    }
}

// MARK: - Preview

#Preview("AO3ChapterView with Mixed Content") {
    struct PreviewWrapper: View {
        @State private var scrollPosition: Int? = nil

        var body: some View {
            AO3ChapterView(
                html: """
                <p>This is a test chapter with some content.</p>
                <p>Here's a table:</p>
                <table>
                    <tr><th>Character</th><th>Role</th></tr>
                    <tr><td>Alice</td><td>Protagonist</td></tr>
                    <tr><td>Bob</td><td>Antagonist</td></tr>
                </table>
                <p>And here's more text after the table.</p>
                <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
                """,
                topVisibleIndex: $scrollPosition
            ) {
                VStack {
                    Text("Chapter 1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Test Chapter")
                        .font(.title2)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
            } footer: {
                VStack(spacing: 12) {
                    Divider()

                    Text("Footer content goes here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
            }
        }
    }

    return PreviewWrapper()
}
