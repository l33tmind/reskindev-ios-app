import SwiftUI
import AVKit
import WebKit

// MARK: - Delivery Theater: the seller's delivered work on a big screen in your room
// Reads the delivery link and shows it the best way: YouTube or video files play, images fill the screen,
// Google Drive / Dropbox files preview, .usdz models open in your room, anything else loads as a web page.

/// What the Theater window shows (window value, so it must be Codable)
struct TheaterItem: Codable, Hashable {
    let orderID: String
    let title: String
    let link: String
    let message: String
}

enum DeliveryContent: Equatable {
    case youtube(String)
    case video(URL)
    case image(URL)
    case model(String)
    case web(URL)

    private static let videoTypes: Set<String> = ["mp4", "mov", "m4v", "m3u8"]
    private static let imageTypes: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "webp"]

    init?(link raw: String) {
        let link = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty, var url = URL(string: link.hasPrefix("http") ? link : "https://\(link)") else { return nil }

        if let id = GigModel.youtubeID(from: link) { self = .youtube(id); return }

        // Google Drive: …/file/d/<id>/view → the embeddable preview player
        if url.host()?.contains("drive.google.com") == true,
           let match = link.range(of: #"/file/d/([^/?]+)"#, options: .regularExpression) {
            let id = link[match].replacingOccurrences(of: "/file/d/", with: "")
            if let preview = URL(string: "https://drive.google.com/file/d/\(id)/preview") { self = .web(preview); return }
        }
        // Dropbox: ?dl=0 → raw file, then judge it by its extension
        if url.host()?.contains("dropbox.com") == true, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            parts.queryItems = (parts.queryItems ?? []).filter { $0.name != "dl" } + [URLQueryItem(name: "raw", value: "1")]
            url = parts.url ?? url
        }

        let ext = url.pathExtension.lowercased()
        if ext == "usdz" || ext == "reality" { self = .model(url.absoluteString) }
        else if Self.videoTypes.contains(ext) { self = .video(url) }
        else if Self.imageTypes.contains(ext) { self = .image(url) }
        else { self = .web(url) }
    }

    var label: String {
        switch self {
        case .youtube, .video: "Video"
        case .image: "Image"
        case .model: "3D Model"
        case .web: "Files"
        }
    }
}

struct DeliveryTheaterView: View {
    let item: TheaterItem

    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private var content: DeliveryContent? { DeliveryContent(link: item.link) }

    /// Live order (from My Orders or the open chat) so the buttons follow its status
    private var order: OrderModel? {
        session.orders.first { $0.id == item.orderID } ?? chat.chatOrders.first { $0.id == item.orderID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
                .padding(.horizontal, 24)
            footer
        }
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
        .onAppear { appModel.openTheaters.insert(item) }
        .onDisappear { appModel.openTheaters.remove(item) }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "play.rectangle.on.rectangle.fill")
                .font(.title2)
                .foregroundStyle(Color.brandGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Delivery Theater").font(.title2.weight(.bold))
                Text(item.title).font(.headline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if let content {
                Text(content.label)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var screen: some View {
        switch content {
        case .youtube(let id):
            YouTubePlayer(videoID: id)
        case .video(let url):
            VideoPlayer(player: AVPlayer(url: url))
        case .image(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else if phase.error != nil {
                    Label("Couldn't load this image", systemImage: "photo.badge.exclamationmark").foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
        case .model(let url):
            VStack(spacing: 18) {
                Image(systemName: "cube.transparent.fill").font(.system(size: 80)).foregroundStyle(Color.brandGreen)
                Text("This delivery is a 3D model").font(.title.weight(.bold))
                Button {
                    openWindow(id: WindowID.model3D, value: url)
                } label: {
                    Label("View in Your Room", systemImage: "arkit")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandGreen)
            }
        case .web(let url):
            WebView(url: url)
        case nil:
            ContentUnavailableView("No files attached", systemImage: "doc",
                                   description: Text("The seller's note is below."))
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            if !item.message.isEmpty {
                Text(item.message)
                    .font(.callout)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }
            if let url = URL(string: item.link), !item.link.isEmpty {
                Link(destination: url) { Label("Open in Safari", systemImage: "safari") }
                    .buttonStyle(.bordered)
            }
            // Buyer, still waiting on them: straight to accept / ask for changes
            if let order, order.isDelivered, order.isBuyer(session.uid) {
                Button {
                    appModel.selectedOrderID = order.id
                    openWindow(id: WindowID.orders, value: WindowID.single)
                    dismissWindow(id: WindowID.theater, value: item)
                } label: {
                    Label("Accept or Ask for Changes", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandGreen)
            }
        }
        .padding(24)
    }
}

/// "Watch in Theater" button used on delivery cards (chat, workspace, gift box)
struct TheaterButton: View {
    let item: TheaterItem
    var prominent = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: WindowID.theater, value: item)
        } label: {
            Label("View in Theater", systemImage: "play.rectangle.on.rectangle")
        }
        .buttonStyle(GlassOutlineButtonStyle(prominent: prominent))
        .help("Open the delivered work on a big screen")
    }
}
