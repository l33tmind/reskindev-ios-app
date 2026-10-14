import SwiftUI

/// Order invoice (website /invoice/[id]) with a shareable PDF
struct InvoiceView: View {
    let order: OrderModel
    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Invoice").font(.title.weight(.semibold))
                Spacer()
                if let pdfURL {
                    ShareLink(item: pdfURL) { Label("Share PDF", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brandGreen)
                }
                if let web = URL(string: "https://reskindev.com/invoice/\(order.id)") {
                    Link(destination: web) { Label("Open on Website", systemImage: "safari") }
                        .buttonStyle(.bordered)
                }
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            ScrollView {
                InvoicePaper(order: order)
                    .frame(width: 700)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            }
        }
        .padding(28)
        .frame(width: 800, height: 820)
        .task { pdfURL = renderPDF() }
    }

    /// Renders the same invoice into a single-page PDF in the temp folder
    @MainActor
    private func renderPDF() -> URL? {
        let renderer = ImageRenderer(content: InvoicePaper(order: order).frame(width: 700))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Reskindev-\(order.invoiceNumber).pdf")
        var ok = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            ok = true
        }
        return ok ? url : nil
    }
}

/// White "paper" layout, same sections as the website invoice
private struct InvoicePaper: View {
    let order: OrderModel
    private let ink = Color(white: 0.1)
    private let muted = Color(white: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("reskindev").font(.title2.weight(.semibold)).foregroundStyle(Color.brandGreen)
                    Text("INVOICE").font(.system(size: 40, weight: .black)).foregroundStyle(ink)
                    Text("Invoice No. \(order.invoiceNumber)").font(.headline).foregroundStyle(ink)
                    Text("Order \(order.orderNumber)").font(.caption.weight(.semibold)).foregroundStyle(muted)
                    Text("Order ID: \(order.id)").font(.caption2).foregroundStyle(muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("STATUS").font(.caption2.weight(.bold)).foregroundStyle(muted)
                    Text(order.status.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brandGreen)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.brandGreen.opacity(0.12), in: Capsule())
                    Text("Date: \(order.createdAt.formatted(date: .numeric, time: .omitted))")
                        .font(.caption).foregroundStyle(muted)
                }
            }

            HStack(alignment: .top) {
                party("BILLED TO (CLIENT)", order.buyerName.isEmpty ? "Valued Client" : order.buyerName, order.buyerId)
                Spacer()
                party("SERVICE PROVIDER (FREELANCER)", order.sellerName.isEmpty ? "Reskindev Provider" : order.sellerName, order.sellerId)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("SERVICE DESCRIPTION").frame(maxWidth: .infinity, alignment: .leading)
                    Text("PACKAGE").frame(width: 140, alignment: .leading)
                    Text("AMOUNT").frame(width: 100, alignment: .trailing)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(muted)
                .padding(12)
                .background(Color(white: 0.95))

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.gigTitle).font(.callout.weight(.semibold)).foregroundStyle(ink)
                        Text("Delivery Time: \(order.deliveryDays) Days").font(.caption).foregroundStyle(muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(order.packageName).font(.callout).foregroundStyle(ink).frame(width: 140, alignment: .leading)
                    Text(order.price.usd).font(.callout.weight(.semibold)).foregroundStyle(ink).frame(width: 100, alignment: .trailing)
                }
                .padding(12)
            }
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(white: 0.88)))

            HStack {
                Spacer()
                VStack(spacing: 8) {
                    row("Subtotal", order.price.usd)
                    row("Platform Fee", 0.0.usd)
                    Divider()
                    row("Total", order.price.usd, bold: true)
                }
                .frame(width: 260)
            }

            VStack(spacing: 4) {
                Text("Thank you for your business!").font(.callout.weight(.semibold)).foregroundStyle(ink)
                Text("reskindev.com • Official Transaction Record").font(.caption).foregroundStyle(muted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(40)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func party(_ title: String, _ name: String, _ uid: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(muted)
            Text(name).font(.headline).foregroundStyle(ink)
            if !uid.isEmpty { Text("UID: \(uid)").font(.caption2).foregroundStyle(muted) }
        }
    }

    private func row(_ title: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(bold ? ink : muted)
            Spacer()
            Text(value).foregroundStyle(ink)
        }
        .font(bold ? .headline : .callout)
    }
}
