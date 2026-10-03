import SwiftUI
import UIKit

/// Help & Policies window: the pages the admin manages in /admin/pages (Privacy Policy, Terms, Refund…)
struct PagesView: View {
    @Environment(GigStore.self) private var gigStore
    @State private var selection: String?

    private var pages: [SitePage] { gigStore.pages }

    var body: some View {
        NavigationSplitView {
            List(pages, selection: $selection) { page in
                Label(page.title, systemImage: page.isLink ? "arrow.up.right.square" : "doc.text").tag(page.id)
            }
            .overlay { if pages.isEmpty { ProgressView() } }
            .navigationTitle("Help & Policies")
        } detail: {
            if let page = pages.first(where: { $0.id == selection }) {
                PageDetail(page: page)
            } else {
                ContentUnavailableView("Select a page", systemImage: "doc.text")
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onAppear { if selection == nil { selection = preferredPage?.id } }
        .onChange(of: pages) { if selection == nil { selection = preferredPage?.id } }
    }

    /// Opens on the privacy policy when there is one
    private var preferredPage: SitePage? {
        pages.first { $0.slug.contains("privacy") || $0.title.lowercased().contains("privacy") } ?? pages.first
    }
}

private struct PageDetail: View {
    let page: SitePage
    @State private var text: AttributedString?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(page.title).font(.extraLargeTitle2.weight(.bold))
                if page.isLink {
                    Text("This page opens on the web.").foregroundStyle(.secondary)
                } else if let text {
                    Text(text).textSelection(.enabled)
                } else {
                    ProgressView()
                }
                if let url = page.webURL {
                    Link(destination: url) { Label("Open on reskindev.com", systemImage: "safari") }
                        .buttonStyle(.bordered)
                }
            }
            .padding(40)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle(page.title)
        .task(id: page.id) { text = Self.render(page.html) }
    }

    /// Admin content is HTML from the website editor
    private static func render(_ html: String) -> AttributedString {
        let styled = "<style>body{font-family:-apple-system;font-size:19px;color:#fff;line-height:1.5}a{color:#10B981}</style>" + html
        guard let data = styled.data(using: .utf8),
              let ns = try? NSAttributedString(data: data,
                                               options: [.documentType: NSAttributedString.DocumentType.html,
                                                         .characterEncoding: String.Encoding.utf8.rawValue],
                                               documentAttributes: nil),
              let attributed = try? AttributedString(ns, including: \.uiKit) else {
            return AttributedString(GigModel.plainText(fromHTML: html))
        }
        return attributed
    }
}
