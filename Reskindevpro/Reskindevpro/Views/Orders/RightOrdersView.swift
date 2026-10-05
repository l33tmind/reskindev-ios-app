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
                    .font(.largeTitle.weight(.semibold))
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
                EmptyStateView(icon: "shippingbox", title: "Sign in to see your orders",
                               message: "Track every order from payment to delivery, right here.",
                               actionTitle: "Sign In") { showSignIn = true }
                    .frame(maxHeight: .infinity)
            } else {
                Picker("Filter", selection: $filter) {
                    ForEach(OrderFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if session.ordersLoading {
                    VStack(spacing: 14) {
                        ForEach(0..<3, id: \.self) { _ in SkeletonRow(height: 150) }
                        Spacer()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Loading orders")
                } else if visibleOrders.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: filter == .completed ? "No finished orders yet" : "No orders here",
                        message: session.mode == .seller
                            ? "Orders on your services will show up here."
                            : "Orders you place will show up here.",
                        actionTitle: session.mode == .seller ? nil : "Browse services",
                        action: session.mode == .seller ? nil : { openWindow(id: WindowID.main) }
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(visibleOrders) { order in
                                OrderCard(order: order, onOpen: { appModel.selectedOrderID = order.id }) {
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
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        .offlineBanner()
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
            .buttonStyle(GlassOutlineButtonStyle(prominent: true, tint: Color(red: 1, green: 0.62, blue: 0.2)))
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

// MARK: - One order = one clear message: whose turn it is, how far along, what to do next

/// Traffic-light logic: orange = your turn, blue = waiting on someone else, green = going well / done,
/// amber = money step, red = a problem
private enum OrderPhase {
    case yourTurn, waiting, payment, active, done, problem

    var color: Color {
        switch self {
        case .yourTurn: Color(red: 1, green: 0.62, blue: 0.2)
        case .waiting: Color(red: 0.4, green: 0.7, blue: 1)
        case .payment: Color.starYellow
        case .active, .done: Color.brandGreen
        case .problem: Color(red: 1, green: 0.4, blue: 0.4)
        }
    }
    var icon: String {
        switch self {
        case .yourTurn: "hand.point.right.fill"
        case .waiting: "clock.fill"
        case .payment: "creditcard.fill"
        case .active: "bolt.fill"
        case .done: "checkmark.circle.fill"
        case .problem: "exclamationmark.triangle.fill"
        }
    }
}

struct OrderCard<Footer: View>: View {
    let order: OrderModel
    var onOpen: () -> Void = {}
    @ViewBuilder var footer: () -> Footer
    @Environment(SessionStore.self) private var session
    @Environment(GigStore.self) private var gigStore

    private static var steps: [String] { ["Payment", "Requirements", "Processing", "Delivered", "Completed"] }

    private var phase: OrderPhase {
        if order.status == "cancelled" || order.isCancelRequested || order.status == "disputed" { return .problem }
        if order.nextAction(for: session.uid) != nil { return .yourTurn }
        if order.isCompleted { return .done }
        if order.isPendingPayment { return .payment }
        if order.isInProgress { return .active }
        return .waiting
    }

    private var chipText: String {
        switch phase {
        case .yourTurn: "Your turn"
        case .waiting: "Waiting"
        case .payment: "Payment pending"
        case .active: "In progress"
        case .done: "Completed"
        case .problem: order.statusLabel
        }
    }

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
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Opens order details and actions")
            VStack(spacing: 0) { footer() }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
        }
        .background(phase.color.opacity(phase == .yourTurn ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(phase.color.opacity(phase == .yourTurn ? 0.6 : 0.18), lineWidth: phase == .yourTurn ? 1.5 : 1)
        )
        .gazeLift(scale: 1.02, radius: 28)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. The one thing to know: whose turn is it
            HStack {
                Label(chipText, systemImage: phase.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(phase.color)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(phase.color.opacity(0.18), in: Capsule())
                Spacer()
                Text(order.price.usd)
                    .font(.system(.title2, design: .rounded).weight(.semibold)).monospacedDigit()
            }

            // 2. What and with whom
            VStack(alignment: .leading, spacing: 4) {
                Text(order.gigTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(session.mode == .seller ? "Buyer" : "Seller"): \(counterpart) · \(order.createdAt.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Order \(order.orderNumber) · \(order.invoiceLabel)")
                    .font(.footnote.weight(.semibold).monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if !order.isPendingPayment && order.status != "cancelled" {
                    Label("Payment verified", systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.brandGreen)
                        .padding(.top, 2)
                }
            }

            // 3. How far along (one bar, one sentence)
            if let step = order.timelineStep {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            Capsule()
                                // Finished steps are always green (payment verified = green); the current one takes the status colour
                                .fill(i < step || phase == .done ? Color.brandGreen : (i == step ? phase.color : Color.white.opacity(0.16)))
                                .frame(height: 8)
                        }
                    }
                    Text(step == 4 ? "All steps done" : "Step \(step + 1) of 5 · \(Self.steps[step])")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(step + 1) of 5, \(Self.steps[step])")
            }

            // 4. Time left, only while the seller is working
            if order.isTimerRunning {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let left = order.dueDate.timeIntervalSince(context.date)
                    Label(left < 0 ? "Late by \(Self.short(-left))" : "Due in \(Self.short(left))", systemImage: "timer")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(left < 0 ? Color(red: 1, green: 0.4, blue: 0.4) : .primary)
                }
            }

            // 5. If it's someone else's turn, say whose
            if phase != .yourTurn, let waiting = order.waitingText(for: session.uid) {
                Label(waiting, systemImage: "hourglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
