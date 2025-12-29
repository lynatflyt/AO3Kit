import SwiftUI
import UIKit
import AO3Kit

/// Font design options that map to both SwiftUI and UIKit
public enum AO3FontDesign: String, Sendable {
    case `default`
    case serif
    case rounded

    var uiFontDescriptorDesign: UIFontDescriptor.SystemDesign {
        switch self {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }

    var swiftUIDesign: Font.Design {
        switch self {
        case .default: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        }
    }
}

/// A high-performance reader view backed by UITableView
///
/// This view provides smooth scrolling for chapter content by using UIKit's
/// UITableView directly. Position tracking only occurs when scrolling stops,
/// eliminating stutter during scroll.
///
/// Example usage:
/// ```swift
/// AO3ChapterView(
///     chapter: chapter,
///     work: work,
///     topVisibleIndex: $scrollPosition,
///     initialPosition: savedPosition,
///     fontSize: 18,
///     fontDesign: .serif,
///     textColor: .label,
///     backgroundColor: .systemBackground
/// )
/// ```
public struct AO3ChapterView<Header: View>: UIViewRepresentable {
    private let views: [AnyView]
    private let parseError: Error?

    @Binding var topVisibleIndex: Int?
    let initialPosition: Int?
    let fontSize: CGFloat
    let fontDesign: AO3FontDesign
    let textColor: UIColor
    let backgroundColor: UIColor
    let headerView: Header?

    public init(
        html: String,
        workSkinCSS: String? = nil,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground,
        @ViewBuilder header: () -> Header
    ) {
        do {
            self.views = try AO3HTMLRenderer.parse(html, workSkinCSS: workSkinCSS)
            self.parseError = nil
        } catch {
            self.views = []
            self.parseError = error
        }
        self._topVisibleIndex = topVisibleIndex
        self.initialPosition = initialPosition
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.headerView = header()
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
        @ViewBuilder header: () -> Header
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
            header: header
        )
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.separatorStyle = .none
        tableView.backgroundColor = backgroundColor
        tableView.showsVerticalScrollIndicator = true

        // Allow content to scroll under navigation bar while respecting safe area
        tableView.contentInsetAdjustmentBehavior = .scrollableAxes
        tableView.contentInset.bottom = 80

        // Register cell
        tableView.register(HostingCell.self, forCellReuseIdentifier: "ContentCell")

        // Store views in coordinator
        context.coordinator.views = views
        context.coordinator.fontSize = fontSize
        context.coordinator.fontDesign = fontDesign
        context.coordinator.textColor = textColor
        context.coordinator.backgroundColor = backgroundColor
        context.coordinator.tableView = tableView

        // Set up header view if provided
        if let headerView = headerView {
            let hostingController = UIHostingController(rootView: AnyView(headerView))
            hostingController.view.backgroundColor = backgroundColor
            context.coordinator.headerHostingController = hostingController

            // Size the header to fit
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            let size = hostingController.view.systemLayoutSizeFitting(
                CGSize(width: UIScreen.main.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            hostingController.view.frame = CGRect(origin: .zero, size: size)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = true
            tableView.tableHeaderView = hostingController.view
        }

        return tableView
    }

    public func updateUIView(_ tableView: UITableView, context: Context) {
        let coordinator = context.coordinator

        // Check if styling changed
        let stylingChanged = coordinator.fontSize != fontSize ||
                            coordinator.fontDesign != fontDesign ||
                            coordinator.textColor != textColor ||
                            coordinator.backgroundColor != backgroundColor

        // Update coordinator properties
        coordinator.parent = self
        coordinator.fontSize = fontSize
        coordinator.fontDesign = fontDesign
        coordinator.textColor = textColor
        coordinator.backgroundColor = backgroundColor

        // Scroll to initial position once
        if !coordinator.didInitialScroll, let position = initialPosition, position > 0 {
            coordinator.didInitialScroll = true
            DispatchQueue.main.async {
                let indexPath = IndexPath(row: position, section: 0)
                if position < self.views.count {
                    tableView.scrollToRow(at: indexPath, at: .top, animated: false)
                }
            }
        } else if !coordinator.didInitialScroll {
            coordinator.didInitialScroll = true
        }

        // Update background color
        tableView.backgroundColor = backgroundColor

        // Update header if styling changed
        if stylingChanged, let headerView = headerView {
            if let hostingController = coordinator.headerHostingController {
                hostingController.rootView = AnyView(headerView)
                hostingController.view.backgroundColor = backgroundColor

                // Re-size the header
                hostingController.view.translatesAutoresizingMaskIntoConstraints = false
                let size = hostingController.view.systemLayoutSizeFitting(
                    CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                hostingController.view.frame = CGRect(origin: .zero, size: size)
                hostingController.view.translatesAutoresizingMaskIntoConstraints = true
                tableView.tableHeaderView = hostingController.view
            }
        }

        // Reload visible cells if styling changed
        if stylingChanged {
            tableView.reloadData()
        }
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
        var parent: AO3ChapterView<Header>
        var views: [AnyView] = []
        var fontSize: CGFloat = 17
        var fontDesign: AO3FontDesign = .default
        var textColor: UIColor = .label
        var backgroundColor: UIColor = .systemBackground
        var didInitialScroll = false
        weak var tableView: UITableView?
        var headerHostingController: UIHostingController<AnyView>?

        init(_ parent: AO3ChapterView<Header>) {
            self.parent = parent
        }

        private func makeFont() -> UIFont {
            let baseFont = UIFont.systemFont(ofSize: fontSize)
            if let descriptor = baseFont.fontDescriptor.withDesign(fontDesign.uiFontDescriptorDesign) {
                return UIFont(descriptor: descriptor, size: fontSize)
            }
            return baseFont
        }

        // MARK: - UITableViewDataSource

        public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            views.count
        }

        public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ContentCell", for: indexPath) as! HostingCell

            let font = makeFont()
            let view = views[indexPath.row]
                .font(Font(font))
                .fontDesign(fontDesign.swiftUIDesign)
                .foregroundStyle(Color(textColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            cell.configure(with: view, backgroundColor: backgroundColor)
            return cell
        }

        // MARK: - UIScrollViewDelegate

        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                updateTopVisibleIndex(scrollView as! UITableView)
            }
        }

        public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            updateTopVisibleIndex(scrollView as! UITableView)
        }

        public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            updateTopVisibleIndex(scrollView as! UITableView)
        }

        private func updateTopVisibleIndex(_ tableView: UITableView) {
            guard didInitialScroll else { return }

            if let topIndexPath = tableView.indexPathsForVisibleRows?.first {
                parent.topVisibleIndex = topIndexPath.row
            }
        }
    }
}

// MARK: - No Header Convenience

extension AO3ChapterView where Header == EmptyView {
    public init(
        html: String,
        workSkinCSS: String? = nil,
        topVisibleIndex: Binding<Int?>,
        initialPosition: Int? = nil,
        fontSize: CGFloat = 17,
        fontDesign: AO3FontDesign = .default,
        textColor: UIColor = .label,
        backgroundColor: UIColor = .systemBackground
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
            header: { EmptyView() }
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
        backgroundColor: UIColor = .systemBackground
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
            header: { EmptyView() }
        )
    }
}

// MARK: - Hosting Cell

/// A UITableViewCell that hosts SwiftUI content
private class HostingCell: UITableViewCell {
    private var hostingController: UIHostingController<AnyView>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with view: some View, backgroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        contentView.backgroundColor = backgroundColor

        let wrappedView = AnyView(view)

        if let hostingController = hostingController {
            hostingController.rootView = wrappedView
            hostingController.view.invalidateIntrinsicContentSize()
        } else {
            let hc = UIHostingController(rootView: wrappedView)
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false

            contentView.addSubview(hc.view)
            NSLayoutConstraint.activate([
                hc.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hc.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hc.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            hostingController = hc
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }
}

#if DEBUG
import struct AO3Kit.AO3MockData

#Preview("Chapter View") {
    AO3ChapterView(
        chapter: AO3MockData.sampleChapter1,
        work: AO3MockData.sampleWork1,
        topVisibleIndex: .constant(nil),
        fontSize: 18,
        fontDesign: .serif
    )
}
#endif
