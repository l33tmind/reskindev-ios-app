import SwiftUI

// MARK: - Panel B: Center Stage (Carousel & AI)
struct CenterStageView: View {
    @Environment(GigStore.self) private var store
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @State private var centeredID: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var store = store
        let gigs = store.filteredGigs

        VStack(spacing: 28) {

            // Top Floating Filter Bar
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search services...", text: $store.searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onChange(of: appModel.searchFocusRequest) { searchFocused = true }
                    if !store.searchText.isEmpty {
                        Button { store.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 20)
                .frame(width: 290, height: 52)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterPill(title: "All", icon: "square.grid.2x2.fill", isActive: store.selectedCategory == nil) {
                            store.selectedCategory = nil
                        }
                        ForEach(store.categories, id: \.self) { category in
                            FilterPill(title: category, icon: FilterPill.icon(for: category), isActive: store.selectedCategory == category) {
                                store.selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: 560)
            }
            .padding(8)
            .glassBackgroundEffect(in: Capsule())
            .offset(z: 40)

            // Curved 3D Gig Carousel
            Group {
                if store.isLoading {
                    skeletonRow
                } else if let error = store.errorMessage {
                    ContentUnavailableView("Couldn't load services", systemImage: "wifi.exclamationmark",
                                           description: Text(error))
                } else if gigs.isEmpty {
                    ContentUnavailableView.search(text: store.searchText)
                } else {
                    carousel(gigs)
                }
            }
            .frame(height: 430)

            // Second row: compact service cards (same live, filtered gigs)
            if !store.isLoading && !gigs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(gigs) { gig in
                            Button {
                                openWindow(id: WindowID.gigDetail, value: gig.id)
                            } label: {
                                CompactGigCard(gig: gig)
                            }
                            .buttonStyle(.plain)
                            .gazeLift(scale: 1.05, radius: Radius.medium)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                }
                .frame(height: 250)
                .offset(z: 60)
            }
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: -40) {
            ForEach(0..<3, id: \.self) { i in
                SkeletonGigCard()
                    .rotation3DEffect(.degrees(Double(i - 1) * -14), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(i == 1 ? 1 : 0.9)
                    .zIndex(i == 1 ? 1 : 0)
            }
        }
    }

    @ViewBuilder
    private func carousel(_ gigs: [GigModel]) -> some View {
        let centerIndex = gigs.firstIndex { $0.id == centeredID } ?? gigs.count / 2

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -40) { // overlap like a fanned deck
                ForEach(Array(gigs.enumerated()), id: \.element.id) { index, gig in
                    let offset = index - centerIndex
                    let distance = CGFloat(abs(offset))

                    Button {
                        if offset == 0 {
                            openWindow(id: WindowID.gigDetail, value: gig.id)       // focused → open details
                        } else {
                            withAnimation(.spring(duration: 0.45)) { centeredID = gig.id } // side → bring forward
                        }
                    } label: {
                        GigCardView(gig: gig, isFocused: offset == 0)
                    }
                    .buttonStyle(.plain)
                    .gazeLift(scale: offset == 0 ? 1.04 : 1.06)
                    .rotation3DEffect(.degrees(Double(offset) * -14), axis: (x: 0, y: 1, z: 0))
                    .offset(z: max(0, 3 - distance) * 30) // keep every card in front of the window plane, focused card closest
                    .scaleEffect(max(0.72, 1.0 - distance * 0.1))
                    .opacity(distance > 3 ? 0 : 1)
                    .zIndex(Double(-abs(offset)))
                    .accessibilityHint(offset == 0 ? "Opens service details" : "Brings this service to the front")
                    .id(gig.id)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 20)
        }
        .contentMargins(.horizontal, 300, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centeredID, anchor: .center)
        .animation(.spring(duration: 0.45), value: centeredID)
        .onAppear { recenter(gigs) }
        .onChange(of: gigs.map(\.id)) { recenter(gigs) }
    }

    private func recenter(_ gigs: [GigModel]) {
        guard !gigs.isEmpty else { return }
        if centeredID == nil || !gigs.contains(where: { $0.id == centeredID }) {
            centeredID = gigs[gigs.count / 2].id
        }
    }
}
