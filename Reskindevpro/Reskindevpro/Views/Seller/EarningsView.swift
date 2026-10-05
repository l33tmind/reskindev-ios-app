import SwiftUI

/// Seller earnings + Payoneer withdrawals (website /profile/earnings)
struct EarningsView: View {
    @Environment(SellerStore.self) private var seller
    @Environment(SessionStore.self) private var session
    @State private var showWithdraw = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let e = seller.earnings
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 16) {
                    tile("Available for Withdrawal", e.available.usd, "dollarsign.circle.fill", highlight: true)
                    tile("Pending Clearance", e.pendingClearance.usd, "clock")
                    tile("Total Earnings", e.totalEarnings.usd, "chart.line.uptrend.xyaxis")
                    tile("Withdrawn", e.withdrawn.usd, "arrow.up.right.circle")
                }

                HStack {
                    Label("\(e.completedOrders) completed orders · \(e.platformFee.formatted())% platform fee · funds clear 15 days after completion",
                          systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                if !seller.earningsLoading && e.pending.isEmpty && e.withdrawals.isEmpty && e.completedOrders == 0 {
                    EmptyStateView(icon: "dollarsign.circle", title: "No earnings yet",
                                   message: "When a buyer accepts a delivery, the payment shows up here and clears after 15 days.")
                }

                if !e.pending.isEmpty {
                    list("Clearing Soon") {
                        ForEach(e.pending.indices, id: \.self) { i in
                            let item = e.pending[i]
                            row(item.title, detail: "Clears \(item.clearsAt.formatted(.relative(presentation: .named)))",
                                amount: item.amount.usd)
                        }
                    }
                }

                if !e.withdrawals.isEmpty {
                    list("Withdrawals") {
                        ForEach(e.withdrawals.indices, id: \.self) { i in
                            let w = e.withdrawals[i]
                            row(w.status.capitalized, detail: w.date?.formatted(date: .abbreviated, time: .omitted) ?? "",
                                amount: w.amount.usd)
                        }
                    }
                }
            }
            .padding(32)
        }
        .overlay {
            if seller.earningsLoading {
                VStack(spacing: 14) {
                    HStack(spacing: 16) { ForEach(0..<4, id: \.self) { _ in SkeletonRow(height: 120) } }
                    SkeletonRow(height: 70)
                    SkeletonRow(height: 70)
                    Spacer()
                }
                .padding(32)
                .background(.background)
                .accessibilityLabel("Loading earnings")
            }
        }
        .offlineBanner()
        // Quick actions float beside the window so the numbers stay uncluttered
        .ornament(attachmentAnchor: .scene(.bottom)) {
            HStack(spacing: 12) {
                Button {
                    openWindow(id: WindowID.earnings3D)
                } label: {
                    Label("3D Chart", systemImage: "chart.bar.xaxis")
                }
                .help("Your last 6 months as 3D bars you can turn around")
                Button {
                    showWithdraw = true
                } label: {
                    Label("Withdraw Funds", systemImage: "arrow.up.right.circle.fill")
                }
                .tint(Color.brandGreen)
                .disabled(seller.earnings.available < 20)
            }
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(12)
            .glassBackgroundEffect()
        }
        .navigationTitle("Earnings")
        .task { await seller.loadEarnings(session: session) }
        .sheet(isPresented: $showWithdraw) { WithdrawSheet().sheetPresence() }
    }

    private func tile(_ title: String, _ value: String, _ icon: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.brandGreen)
            Text(value)
                .font(.system(.title, design: .rounded).weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlight ? Color.brandGreen.opacity(0.16) : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func list<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }

    private func row(_ title: String, detail: String, amount: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount).font(.system(.headline, design: .rounded)).monospacedDigit()
        }
        .padding(18)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct WithdrawSheet: View {
    @Environment(SellerStore.self) private var seller
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var amount = ""
    @State private var working = false
    @State private var errorMessage: String?
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Withdraw via Payoneer").font(.title.weight(.semibold))
            if done {
                Label("Withdrawal request submitted! It will be reviewed within 3-5 business days.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.brandGreen)
                Button("Done") { dismiss() }.buttonStyle(GlassOutlineButtonStyle(prominent: true))
            } else {
                Text("Available: \(seller.earnings.available.usd) · Minimum $20 · $3 processing charge")
                    .font(.subheadline).foregroundStyle(.secondary)
                GlassField(title: "Payoneer email", text: $email, prompt: "you@example.com")
                GlassField(title: "Amount (USD)", text: $amount, prompt: "50")
                if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red) }
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }.buttonStyle(GlassOutlineButtonStyle())
                    Button {
                        Task {
                            working = true
                            errorMessage = nil
                            do {
                                try await seller.requestWithdrawal(amount: Double(amount) ?? 0, email: email, session: session)
                                done = true
                            } catch {
                                errorMessage = error.friendlyMessage
                            }
                            working = false
                        }
                    } label: {
                        if working { ProgressView() } else { Text("Request Withdrawal") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .disabled(working || email.trimmed.isEmpty || (Double(amount) ?? 0) <= 0)
                }
            }
        }
        .padding(32)
        .frame(width: 520)
    }
}
