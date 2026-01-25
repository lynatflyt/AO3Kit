import SwiftUI

/// Renders a code block with monospaced font
struct HTMLCodeBlock: View {
    let code: String
    let language: String?
    var textSelectionEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language = language {
                Text(language.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                let codeText = Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                if textSelectionEnabled {
                    codeText.textSelection(.enabled)
                } else {
                    codeText
                }
            }
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .padding(.vertical, 4)
    }
}
