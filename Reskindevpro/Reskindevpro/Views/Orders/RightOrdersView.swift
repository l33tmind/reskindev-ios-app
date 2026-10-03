import SwiftUI

// MARK: - Panel C: My Orders / Orders Workspace (live from Firestore `orders`)
struct RightOrdersView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showSignIn = false
    @State private var filter: OrderFilter = .active

    enum OrderFilter: String, CaseIterable, Identifiable {
        case active = "Active", completed = "Completed", all = "All"
        var id: String { rawValue }
    }

    private var visibleOrders: [OrderModel] {
        switch filter {
        case .all: session.orders
        case .completed: session.orders.filter { $0.isCompleted || $0.status == "cancelled" }
        case .active: session.orders.filter { !$0.isCompleted && $0.status != "cancelled" }
        }
    }

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(alignment: .center, spacing: 4) {
                Text(session.mode == .seller ? "Orders Workspace" : "My Orders")
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                CircleIconButton(systemName: "cube.transparent", label: "View AR delivery") {
                    openWindow(id: WindowID.deliveryBox)
                }
                CircleIconButton(systemName: "xmark", label: "Close orders") {
                    dismissWindow(id: WindowID.orders, value: WindowID.single)
                }
            }

            if !session.isSignedIn {
                ContentUnavailableView {
                    Label("Sign in to see your orders", systemImage: "person.crop.circle")
                } actions: {
                    Button("Sign In") { showSignIn = true }
                        .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                        .frame(width: 200)
                }
                .frame(maxHeight: .infinity)
            } else {
                Picker("Filter", selection: $filter) {
                    ForEach(OrderFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if session.ordersLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visibleOrders.isEmpty {
                    ContentUnavailableView("No orders here", systemImage: "doc.text",
                                           description: Text(session.mode == .seller
                                                             ? "Orders on your services will show up here."
                                                             : "Orders you place will show up here."))
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(Array(visibleOrders.enumerated()), id: \.element.id) { index, order in
                                Button {
                                    appModel.selectedOrderID = order.id
                                } label: {
                                    OrderCard(order: order, isHighlighted: index == 0)
                                }
                                .buttonStyle(.plain)
                                .gazeLift(scale: 1.02, radius: Radius.medium)
                                .accessibilityHint("Opens order details and actions")
                            }
                        }
                        .padding(4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .padding(28)
        .background(Color.white.opacity(0.03))
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: Radius.large))
        .overlay(RoundedRectangle(cornerRadius: Radius.large).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(item: Binding(get: { appModel.selectedOrderID.map(SelectedOrder.init) },
                             set: { appModel.selectedOrderID = $0?.id })) { selected in
            OrderDetailView(orderID: selected.id)
        }
    }
}

private struct SelectedOrder: Identifiable { let id: String }

struct OrderCard: View {
    let order: OrderModel
    var isHighlighted = false
    @Environment(SessionStore.self) private var session
    @Environment(GigStore.self) private var gigStore

    /// Buyers see the seller, sellers see the buyer. Old orders don't store the seller's name, so fall back to the gig.
    private var counterpart: String {
        if session.mode == .seller { return order.buyerName.isEmpty ? "Buyer" : order.buyerName }
        if !order.sellerName.isEmpty { return order.sellerName }
        let name = gigStore.gig(id: order.gigId)?.sellerName ?? ""
        return name.isEmpty ? "Freelancer" : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(order.gigTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(session.mode == .seller ? "Buyer" : "Seller"): \(counterpart)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Package: \(order.packageName) | Ordered on: \(order.createdAt.formatted(date: .numeric, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Paid").font(.subheadline).foregroundStyle(.secondary)
                    Text(order.price.usd)
                        .font(.title.weight(.bold))
                        .foregroundStyle(order.isPendingPayment ? Color.starYellow : Color.brandGreen)
                }
            }

            if order.isPendingPayment {
                Text("Pending Payment")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.starYellow)
            } else if let step = order.timelineStep {
                OrderTimeline(currentStep: step)
            } else {
                Text(order.statusLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
        .background(Color.white.opacity(isHighlighted ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium)
                .stroke(isHighlighted ? Color.brandGreen.opacity(0.7) : Color.white.opacity(0.12), lineWidth: isHighlighted ? 1.5 : 1)
        )
        .shadow(color: isHighlighted ? Color.brandGreen.opacity(0.35) : .clear, radius: 14)
        .accessibilityElement(children: .combine)
    }
}
