import SwiftUI

// MARK: - My Orders / Orders Workspace window (live from Firestore `orders`)
struct RightOrdersView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showSignIn = false
    @State private var filter: OrderFilter = .active
    @State private var nextStep: NextStep?
    @State private var toast: String?

    /// Order + the action its "next step" button starts
    private struct NextStep: Identifiable {
        let order: OrderModel
        let action: OrderAction
        var id: String { order.id + action.rawValue }
    }

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
            }

            // Sellers switch here between orders they placed and orders on their gigs
            if session.isSignedIn && session.canSell {
                Picker("Mode", selection: Binding(get: { session.mode }, set: { mode in withAnimation { session.mode = mode } })) {
                    Label("Buying", systemImage: "cart").tag(SessionStore.Mode.buyer)
                    Label("Selling", systemImage: "briefcase").tag(SessionStore.Mode.seller)
                }
                .pickerStyle(.segmented)
            }

            if let toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.brandGreen)
                    .transition(.opacity)
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
                                VStack(spacing: 8) {
                                    Button {
                                        appModel.selectedOrderID = order.id
                                    } label: {
                                        OrderCard(order: order, isHighlighted: index == 0)
                                    }
                                    .buttonStyle(.plain)
                                    .gazeLift(scale: 1.02, radius: Radius.medium)
                                    .accessibilityHint("Opens order details and actions")

                                    nextStepRow(order)
                                }
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
        .sheet(item: $nextStep) { step in
            OrderActionSheet(order: step.order, action: step.action) { message in show(message) }
        }
        .sheet(item: Binding(get: { appModel.selectedOrderID.map(SelectedOrder.init) },
                             set: { appModel.selectedOrderID = $0?.id })) { selected in
            OrderDetailView(orderID: selected.id)
        }
    }
}

extension RightOrdersView {
    /// One big button for whatever this person should do next; otherwise who we're waiting on
    @ViewBuilder
    fileprivate func nextStepRow(_ order: OrderModel) -> some View {
        if let action = order.nextAction(for: session.uid) {
            Button {
                nextStep = NextStep(order: order, action: action)
            } label: {
                Label(order.nextActionTitle(for: session.uid) ?? action.title, systemImage: action.icon)
            }
            .buttonStyle(GlassOutlineButtonStyle(prominent: true))
        } else if let waiting = order.waitingText(for: session.uid) {
            Label(waiting, systemImage: "hourglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
        }
    }

    fileprivate func show(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toast = nil }
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

    /// "2d 4h" / "5h 12m"
    static func short(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        return m >= 1440 ? "\(m / 1440)d \((m % 1440) / 60)h" : "\(m / 60)h \(m % 60)m"
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

            // Live delivery countdown (starts when requirements are in)
            if order.isTimerRunning {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let left = order.dueDate.timeIntervalSince(context.date)
                    Label(left < 0 ? "Late by \(Self.short(-left))" : "Due in \(Self.short(left))",
                          systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(left < 0 ? Color.red : Color.brandGreen)
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
