import SwiftUI

// MARK: - Panel B: Center Stage (Carousel & AI)
struct CenterStageView: View {
    @Environment(GigStore.self) private var store
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @State private var centeredID: String?
    @FocusState private var searchFocused: Bool

    /// 1 normally; 0 while a sheet is open so the floating cards don't poke through it
    private var depth: CGFloat { appModel.openSheets > 0 ? 0 : 1 }

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
                        // Budget set by Siri ("under 20 dollars"): tap to clear
                        if let max = store.maxPrice {
                            FilterPill(title: "Under \(max.usd)", icon: "xmark.circle.fill", isActive: true) {
                                withAnimation { store.maxPrice = nil }
                            }
                            .accessibilityHint("Removes the budget filter")
                        }
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
            .offset(z: 40 * depth)

            // Below the search bar the home scrolls up/down: spotlight carousel, then a row per section.
            // Every row scrolls left/right on its own.
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 30) {
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
                            carousel(Self.fanned(store.spotlightGigs))
                        }
                    }
                    .frame(height: 430)

                    if !store.isLoading && !gigs.isEmpty {
                        ForEach(sections(gigs), id: \.title) { section in
                            gigRow(section)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .frame(height: 690)
            // Fade the bottom edge so the next row reads as "scroll for more", not as cut off
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.9),
                                         .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: Home rows

    private struct GigSection {
        let title: String
        let icon: String
        let gigs: [GigModel]
    }

    /// Searching / filtering: one results row. Otherwise: Recently Viewed, All Services, then one row per category.
    private func sections(_ gigs: [GigModel]) -> [GigSection] {
        let isFiltering = store.selectedCategory != nil || store.maxPrice != nil
            || !store.searchText.trimmingCharacters(in: .whitespaces).isEmpty
        if isFiltering {
            return [GigSection(title: "Results (\(gigs.count))", icon: "magnifyingglass", gigs: gigs)]
        }
        var rows: [GigSection] = []
        let recent = store.recentIDs.compactMap { store.gig(id: $0) }
        if !recent.isEmpty {
            rows.append(GigSection(title: "Recently Viewed", icon: "clock.arrow.circlepath", gigs: recent))
        }
        rows.append(GigSection(title: "All Services", icon: "square.grid.2x2.fill", gigs: gigs))
        for category in store.categories {
            let inCategory = gigs.filter { $0.category == category }
            if !inCategory.isEmpty {
                rows.append(GigSection(title: category, icon: FilterPill.icon(for: category), gigs: inCategory))
            }
        }
        return rows
    }

    private func gigRow(_ section: GigSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label(section.title, systemImage: section.icon)
                    .font(.title3.weight(.bold))
                Text("\(section.gigs.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.14), in: Capsule())
                    .accessibilityLabel("\(section.gigs.count) services")
                Spacer()
            }
            .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(section.gigs) { gig in
                        Button {
                            openWindow(id: WindowID.gigDetail, value: gig.id)
                        } label: {
                            CompactGigCard(gig: gig)
                        }
                        .buttonStyle(.plain)
                        .gazeLift(scale: 1.10, radius: Radius.medium)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .frame(height: 250)
            // Soft left/right edges: cards slide in and out instead of being chopped off
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                                         .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
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
            HStack(spacing: -150) { // coverflow: side cards tuck behind the focused one
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
                    .gazeLift(scale: offset == 0 ? 1.08 : 1.15)
                    .rotation3DEffect(.degrees(Double(offset.signum()) * -32), axis: (x: 0, y: 1, z: 0))
                    // keep every card in front of the window plane, focused card closest — flat while a sheet is up
                    .offset(z: max(0, 3 - distance) * 30 * depth)
                    .scaleEffect(distance == 0 ? 1 : (distance == 1 ? 0.86 : 0.74))
                    .opacity(distance > 2 ? 0 : (distance == 2 ? 0.75 : 1))
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
        .opacity(appModel.openSheets > 0 ? 0.35 : 1)
        .animation(.easeInOut(duration: 0.25), value: appModel.openSheets > 0)
        .animation(.spring(duration: 0.45), value: centeredID)
        .onAppear { recenter(gigs) }
        .onChange(of: gigs.map(\.id)) { recenter(gigs) }
    }

    /// Puts the most relevant gig (index 0) in the middle and fans the next ones out to either side:
    /// [a, b, c, d, e] → [d, b, a, c, e]
    static func fanned(_ gigs: [GigModel]) -> [GigModel] {
        var left: [GigModel] = []
        var right: [GigModel] = []
        for (index, gig) in gigs.dropFirst().enumerated() {
            if index.isMultiple(of: 2) { left.insert(gig, at: 0) } else { right.append(gig) }
        }
        return left + Array(gigs.prefix(1)) + right
    }

    private func recenter(_ gigs: [GigModel]) {
        guard !gigs.isEmpty else { return }
        // Focus the most relevant card (recently viewed / first match), which fanned() put in the middle
        let focus = gigs[gigs.count / 2].id
        if centeredID != focus {
            centeredID = gigs[gigs.count / 2].id
        }
    }
}
