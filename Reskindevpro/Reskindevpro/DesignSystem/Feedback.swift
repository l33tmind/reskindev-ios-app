import SwiftUI
import Network
import FirebaseAuth
import FirebaseFirestore

// MARK: - Friendly error text (Firebase's own wording reads like a stack trace)

extension Error {
    /// Plain-language message for the usual Auth, Firestore and network failures
    var friendlyMessage: String {
        let ns = self as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed:
                return "You're offline. Check your connection and try again."
            case NSURLErrorTimedOut:
                return "That took too long. Please try again."
            default: break
            }
        }
        if ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .invalidCredential, .wrongPassword, .invalidEmail, .userNotFound:
                return "Email or password isn't right. Please check and try again."
            case .emailAlreadyInUse:
                return "An account with this email already exists. Try signing in instead."
            case .weakPassword:
                return "Choose a stronger password (at least 6 characters)."
            case .userDisabled:
                return "This account has been disabled. Contact support for help."
            case .tooManyRequests:
                return "Too many attempts. Wait a minute and try again."
            case .networkError:
                return "You're offline. Check your connection and try again."
            case .requiresRecentLogin:
                return "For your security, sign in again and then repeat this."
            default: break
            }
        }
        if ns.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .unavailable, .deadlineExceeded:
                return "Can't reach Reskindev right now. Please try again."
            case .permissionDenied:
                return "You don't have permission to do that."
            default: break
            }
        }
        return localizedDescription
    }
}

// MARK: - Connectivity

@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "reskindev.network"))
    }
}

private struct OfflineBanner: ViewModifier {
    @State private var network = NetworkMonitor.shared

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if !network.isOnline {
                    Label("You're offline. Some things may not load.", systemImage: "wifi.slash")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.orange.opacity(0.25), in: Capsule())
                        .overlay(Capsule().stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .animation(.snappy, value: network.isOnline)
    }
}

extension View {
    /// Soft "You're offline" pill at the top of a window
    func offlineBanner() -> some View { modifier(OfflineBanner()) }
}

// MARK: - Empty state

/// Icon, a line of explanation and (optionally) the next step
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey = ""
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.brandGreen)
                .frame(width: 84, height: 84)
                .background(Color.brandGreen.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color.brandGreen)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Card-shaped loading placeholder (used instead of a spinner)
struct SkeletonRow: View {
    var height: CGFloat = 96
    var body: some View {
        ShimmerBlock(cornerRadius: Radius.small)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

/// Error with a Retry button
struct RetryView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        EmptyStateView(icon: "exclamationmark.arrow.triangle.2.circlepath", title: "Something went wrong",
                       message: LocalizedStringKey(message), actionTitle: "Retry", action: retry)
    }
}
