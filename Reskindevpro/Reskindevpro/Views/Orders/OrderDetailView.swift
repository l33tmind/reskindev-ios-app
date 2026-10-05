import SwiftUI

/// Order sheet from the orders panel: workspace timeline + every action for the current role and status
struct OrderDetailView: View {
    let orderID: String
    @Environment(SessionStore.self) private var session
    @Environment(ChatStore.self) private var chat
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var action: OrderAction?
    @State private var confirmation: String?
    @State private var errorMessage: String?
    @State private var invoiceOrder: OrderModel?

    var body: some View {
        Group {
            if let order = session.order(id: orderID) ?? chat.chatOrders.first(where: { $0.id == orderID }) {
                content(order)
            } else {
                ContentUnavailableView("Order not found", systemImage: "doc.questionmark",
                                       description: Text("Switch between Buyer and Seller to see this order."))
                    .frame(width: 600, height: 400)
            }
        }
        .overlay(alignment: .topTrailing) {
            CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
                .padding(16)
        }
        .errorAlert("Something went wrong", message: $errorMessage)
        .sheetPresence()
    }

    private func content(_ order: OrderModel) -> some View {
        let isBuyer = order.isBuyer(session.uid)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(order, isBuyer: isBuyer)

                if let confirmation {
                    Label(confirmation, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Color.brandGreen)
                }

                if let action {
                    OrderActionForm(order: order, action: action, onCancel: { self.action = nil }) { message in
                        confirmation = message
                        self.action = nil
                    }
                    .padding(22)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                } else {
                    WorkspaceTimeline(order: order) { action = $0 }
                        .padding(22)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))

                    HStack(spacing: 12) {
                        Button {
                            openWindow(id: WindowID.orderTimeline3D, value: order.id)
                        } label: {
                            Label("View in 3D", systemImage: "cube.transparent")
                        }
                        .buttonStyle(GlassOutlineButtonStyle())

                        Button {
                            invoiceOrder = order
                        } label: {
                            Label("Invoice", systemImage: "doc.text")
                        }
                        .buttonStyle(GlassOutlineButtonStyle())

                        Button {
                            openChat(for: order)
                        } label: {
                            Label("Open WorkStream Chat", systemImage: "bubble.left.and.bubble.right")
                        }
                        .buttonStyle(GlassOutlineButtonStyle())

                        if order.isCancellable || order.isDelivered {
                            Menu {
                                Button { action = .cancel } label: { Label("Request Cancellation", systemImage: "xmark.octagon") }
                                Button { action = .escalate } label: { Label("Escalate to Admin", systemImage: "exclamationmark.shield") }
                            } label: {
                                Label("Resolution Center", systemImage: "exclamationmark.shield")
                                    .frame(maxWidth: .infinity, minHeight: Hit.min)
                            }
                            .buttonStyle(GlassOutlineButtonStyle())
                        }
                    }
                }
            }
            .padding(36)
            .padding(.trailing, 40)
        }
        .frame(width: 720, height: 780)
        .animation(.snappy, value: action)
        .sheet(item: $invoiceOrder) { InvoiceView(order: $0).sheetPresence() }
    }

    private func header(_ order: OrderModel, isBuyer: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                StatusBadge(order: order)
                Text(order.gigTitle)
                    .font(.title.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                // Name → public profile (website links /user/[id])
                Button {
                    openWindow(id: WindowID.sellerProfile, value: isBuyer ? order.sellerId : order.buyerId)
                } label: {
                    Text(isBuyer
                         ? "Seller: \(order.sellerName.isEmpty ? "Freelancer" : order.sellerName)"
                         : "Buyer: \(order.buyerName.isEmpty ? "Client" : order.buyerName)")
                        .font(.headline)
                        .foregroundStyle(Color.brandGreen)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                Text("#\(String(order.id.suffix(6)).uppercased()) · \(order.packageName) package · \(order.deliveryDays)-day delivery")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Amount Secured").font(.subheadline).foregroundStyle(.secondary)
                Text(order.price.usd)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(Color.brandGreen)
            }
        }
    }

    private func openChat(for order: OrderModel) {
        guard let conversation = chat.conversation(forOrder: order.id) else {
            errorMessage = "No chat found for this order yet."
            return
        }
        chat.activeChatID = conversation.id
        appModel.selectedTab = .messages
        dismiss()
    }
}

/// Coloured status pill
struct StatusBadge: View {
    let order: OrderModel

    var body: some View {
        Text(order.statusLabel.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var color: Color {
        if order.isCompleted || order.isDelivered { return .brandGreen }
        if order.isPendingPayment || order.status == "revision" { return .starYellow }
        if ["cancelled", "disputed"].contains(order.status) || order.isCancelRequested { return .red }
        if order.isInProgress { return .blue }
        return .brandGreen
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
