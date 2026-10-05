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

                // Withdraw to Payoneer: one clear button, with the reason when it's switched off
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 14) {
                        Button {
                            showWithdraw = true
                        } label: {
                            Label("Withdraw to Payoneer", systemImage: "arrow.up.right.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .background(e.available >= 20 ? Color.brandGreen : Color.white.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                        .disabled(e.available < 20)

                        Button {
                            openWindow(id: WindowID.earnings3D)
                        } label: {
                            Label("3D Chart", systemImage: "chart.bar.xaxis")
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal, 26)
                                .frame(minHeight: 72)
                                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                        .help("Your last 6 months as 3D bars you can turn around")
                    }
                    if e.available < 20 {
                        Label("Minimum withdrawal is $20. You have \(e.available.usd) available.", systemImage: "info.circle")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        Label("Paid to your Payoneer account in 3-5 business days. $3 processing charge.", systemImage: "checkmark.shield")
                            .font(.callout).foregroundStyle(.secondary)
                    }
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
                            row("Payoneer · \(w.status.capitalized)", detail: w.date?.formatted(date: .abbreviated, time: .omitted) ?? "",
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
    @State private var email = UserDefaults.standard.string(forKey: "lastPayoneerEmail") ?? ""
    @State private var amount = ""
    @State private var working = false
    @State private var errorMessage: String?
    @State private var done = false
    @State private var confirm = false

    private static let charge = 3.0
    private var value: Double { Double(amount) ?? 0 }
    private var emailOK: Bool { email.trimmed.contains("@") && email.trimmed.contains(".") }
    private var problem: String? {
        if value <= 0 { return nil }
        if value < 20 { return "Minimum withdrawal is $20." }
        if value > seller.earnings.available { return "You only have \(seller.earnings.available.usd) available." }
        return nil
    }
    private var canSubmit: Bool { emailOK && value >= 20 && problem == nil && !working }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.right.circle.fill").font(.title).foregroundStyle(Color.brandGreen)
                Text("Withdraw to Payoneer").font(.title.weight(.semibold))
            }
            if done {
                Label("Request sent. Your Payoneer payment is reviewed within 3-5 business days.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.brandGreen)
                Button("Done") { dismiss() }.buttonStyle(GlassOutlineButtonStyle(prominent: true))
            } else {
                HStack {
                    Text("Available").foregroundStyle(.secondary)
                    Spacer()
                    Text(seller.earnings.available.usd).font(.system(.title3, design: .rounded).weight(.semibold))
                }
                .padding(16)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                GlassField(title: "Payoneer email", text: $email, prompt: "you@example.com")
                GlassField(title: "Amount (USD, minimum $20)", text: $amount, prompt: "50")

                if let problem {
                    Label(problem, systemImage: "exclamationmark.circle.fill").font(.callout).foregroundStyle(.orange)
                } else if value >= 20 {
                    VStack(spacing: 6) {
                        HStack { Text("Withdraw"); Spacer(); Text(value.usd) }
                        HStack { Text("Processing charge"); Spacer(); Text("−\(Self.charge.usd)") }
                        Divider()
                        HStack { Text("You receive").fontWeight(.semibold); Spacer(); Text((value - Self.charge).usd).fontWeight(.semibold) }
                    }
                    .font(.callout).monospacedDigit()
                    .padding(16)
                    .background(Color.brandGreen.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red) }

                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }.buttonStyle(GlassOutlineButtonStyle())
                    Button {
                        confirm = true
                    } label: {
                        if working { ProgressView() } else { Text("Continue") }
                    }
                    .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                    .disabled(!canSubmit)
                }
            }
        }
        .padding(32)
        .frame(width: 540)
        // Money leaves your balance: always ask once more, spelling out where it goes
        .alert("Send \((value - Self.charge).usd) to Payoneer?", isPresented: $confirm) {
            Button("Cancel", role: .cancel) {}
            Button("Withdraw") { Task { await submit() } }
        } message: {
            Text("\(value.usd) leaves your balance. After the \(Self.charge.usd) charge, \((value - Self.charge).usd) goes to \(email.trimmed). Check the email: payments to a wrong Payoneer account can't be undone.")
        }
    }

    private func submit() async {
        working = true
        errorMessage = nil
        do {
            try await seller.requestWithdrawal(amount: value, email: email, session: session)
            UserDefaults.standard.set(email.trimmed, forKey: "lastPayoneerEmail")
            done = true
        } catch {
            errorMessage = error.friendlyMessage
        }
        working = false
    }
}
