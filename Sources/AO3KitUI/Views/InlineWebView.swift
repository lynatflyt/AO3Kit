import SwiftUI
import WebKit

/// A self-sizing WKWebView that renders HTML content inline
/// Used for rendering unsupported HTML elements like tables, images, and ruby annotations
public struct InlineWebView: UIViewRepresentable {
    let html: String
    let workSkinCSS: String?
    let fontSize: CGFloat
    let textColor: UIColor
    let backgroundColor: UIColor
    @Binding var height: CGFloat

    public init(
        html: String,
        workSkinCSS: String? = nil,
        fontSize: CGFloat = 17,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        height: Binding<CGFloat>
    ) {
        self.html = html
        self.workSkinCSS = workSkinCSS
        self.fontSize = fontSize
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self._height = height
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor

        // Disable user interaction except for links
        webView.scrollView.isUserInteractionEnabled = true

        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if content changed
        let contentHash = html.hashValue ^ (workSkinCSS?.hashValue ?? 0)
        if context.coordinator.lastContentHash != contentHash {
            context.coordinator.lastContentHash = contentHash
            context.coordinator.parent = self

            let fullHTML = buildFullHTML()
            webView.loadHTMLString(fullHTML, baseURL: nil)
        }

        webView.backgroundColor = backgroundColor
        webView.scrollView.backgroundColor = backgroundColor
    }

    private func buildFullHTML() -> String {
        let textColorHex = textColor.hexString
        let bgColorHex = backgroundColor.hexString

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                html, body {
                    background-color: \(bgColorHex);
                    color: \(textColorHex);
                    font-family: -apple-system, system-ui, sans-serif;
                    font-size: \(fontSize)px;
                    line-height: 1.5;
                    -webkit-text-size-adjust: none;
                    overflow: hidden;
                }
                body {
                    padding: 0;
                }
                img {
                    max-width: 100%;
                    height: auto;
                }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 0.5em 0;
                }
                th, td {
                    border: 1px solid \(textColorHex)40;
                    padding: 0.5em;
                    text-align: left;
                }
                th {
                    background-color: \(textColorHex)10;
                    font-weight: bold;
                }
                ruby {
                    ruby-align: center;
                }
                rt {
                    font-size: 0.6em;
                    color: \(textColorHex)CC;
                }
                figure {
                    margin: 0.5em 0;
                    text-align: center;
                }
                figcaption {
                    font-size: 0.9em;
                    color: \(textColorHex)CC;
                    margin-top: 0.5em;
                }
                a {
                    color: \(textColorHex);
                    text-decoration: underline;
                }
                /* Work skin CSS */
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
                // Report height after load
                function reportHeight() {
                    const height = document.body.scrollHeight;
                    window.webkit.messageHandlers.heightHandler.postMessage(height);
                }
                window.onload = reportHeight;
                // Also report on resize
                new ResizeObserver(reportHeight).observe(document.body);
            </script>
        </body>
        </html>
        """
    }

    public class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: InlineWebView
        var lastContentHash: Int = 0

        init(_ parent: InlineWebView) {
            self.parent = parent
            super.init()
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Calculate content height
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self?.parent.height = height
                    }
                }
            }

            // Add height message handler
            webView.configuration.userContentController.add(self, name: "heightHandler")
        }

        public func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.height = height
                }
            }
        }

        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow initial load, but open links externally
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// Convert UIColor to hex string for CSS
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
