import SwiftUI

/// Seller's own services (website /profile/gigs)
struct MyGigsView: View {
    @Environment(SellerStore.self) private var seller
    @Environment(\.openWindow) private var openWindow
    @State private var editing: EditTarget?
    @State private var deleting: MyGig?
    @State private var errorMessage: String?

    struct EditTarget: Identifiable {
        let id: String
        var gigID: String? { id == "new" ? nil : id }
    }

    var body: some View {
        Group {
            if seller.gigsLoading && seller.gigs.isEmpty {
                ProgressView()
            } else if seller.gigs.isEmpty {
                ContentUnavailableView {
                    Label("You haven't created any gigs yet", systemImage: "square.stack.3d.up")
                } description: {
                    Text("Create a service and it goes live after admin approval.")
                } actions: {
                    Button("Create New Gig") { editing = EditTarget(id: "new") }
                        .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                        .frame(width: 240)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 20)], spacing: 20) {
                        ForEach(seller.gigs) { gig in
                            MyGigCard(gig: gig,
                                      onView: { openWindow(id: WindowID.gigDetail, value: gig.id) },
                                      onEdit: { editing = EditTarget(id: gig.id) },
                                      onDelete: { deleting = gig })
                        }
                    }
                    .padding(28)
                }
            }
        }
        .navigationTitle("My Gigs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editing = EditTarget(id: "new") } label: { Label("Create New Gig", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { target in GigEditorView(gigID: target.gigID) }
        .confirmationDialog("Delete this gig?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            presenting: deleting) { gig in
            Button("Delete \"\(gig.title)\"", role: .destructive) {
                Task {
                    do { try await seller.delete(gigID: gig.id) } catch { errorMessage = error.friendlyMessage }
                }
            }
        }
        .errorAlert("Couldn't delete gig", message: $errorMessage)
    }
}

private struct MyGigCard: View {
    let gig: MyGig
    var onView: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                CachedImage(url: gig.imageUrl)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                Text(gig.statusLabel)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(gig.statusColor.opacity(0.85), in: Capsule())
                    .padding(10)
            }
            Text(gig.title).font(.headline).lineLimit(2)
            HStack {
                Text(gig.category).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("From \(gig.price.usd)").font(.headline).foregroundStyle(Color.brandGreen)
            }
            HStack(spacing: 8) {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                    .buttonStyle(.bordered)
                if gig.status == "active" || gig.status == "published" {
                    Button(action: onView) { Label("View", systemImage: "eye") }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Delete gig")
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}
