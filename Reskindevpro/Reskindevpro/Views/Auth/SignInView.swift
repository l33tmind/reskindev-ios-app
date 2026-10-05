import SwiftUI
import AuthenticationServices

// MARK: - Sign In / Sign Up (same Firebase Auth users as the Flutter app & website)
struct SignInView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var isSignUp = false
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role = "buyer"
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var appleNonce = ""
    /// When set (order flow), success hands over instead of dismissing the sheet
    var onSuccess: (() -> Void)? = nil

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6 && (!isSignUp || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isSignUp ? "Join Reskindev" : "Sign in to Reskindev")
                .font(.title.weight(.bold))

            // New accounts (Apple, Google or email) start as what you pick here, like the website's signup
            VStack(alignment: .leading, spacing: 8) {
                Text("New to Reskindev? I want to").font(.callout.weight(.medium)).foregroundStyle(.secondary)
                Picker("I want to", selection: $role) {
                    Text("Hire (Buyer)").tag("buyer")
                    Text("Sell (Freelancer)").tag("freelancer")
                }
                .pickerStyle(.segmented)
            }

            // Same Apple / Google accounts as the iOS app
            SignInWithAppleButton(.continue) { request in
                appleNonce = SocialSignIn.makeNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = SocialSignIn.sha256(appleNonce)
            } onCompletion: { result in
                Task { await finishApple(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: Hit.min)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small))
            .disabled(isWorking)

            Button {
                Task { await signInWithGoogle() }
            } label: {
                Label("Continue with Google", systemImage: "g.circle.fill")
            }
            .buttonStyle(GlassOutlineButtonStyle())
            .disabled(isWorking)

            HStack {
                VStack { Divider() }
                Text("or use email").font(.callout).foregroundStyle(.secondary)
                VStack { Divider() }
            }

            Picker("Mode", selection: $isSignUp.animation()) {
                Text("Sign In").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(.segmented)

            if isSignUp {
                TextField("Full name", text: $name)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)

            }

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            SecureField("Password (min 6 characters)", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.red.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityAddTraits(.isStaticText)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(GlassOutlineButtonStyle())
                Button {
                    Task { await submit() }
                } label: {
                    if isWorking { ProgressView() } else { Text(isSignUp ? "Create Account" : "Sign In") }
                }
                .buttonStyle(GlassOutlineButtonStyle(prominent: true))
                .disabled(!canSubmit || isWorking)
            }

            Button("By continuing you agree to our Terms & Privacy Policy") {
                openWindow(id: WindowID.page, value: WindowID.single)
            }
            .font(.footnote)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .padding(36)
        .frame(width: 540)
        .sheetPresence()
    }

    private func finishApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { errorMessage = error.friendlyMessage }
        case .success(let authorization):
            await run {
                let (credential, name) = try SocialSignIn.appleCredential(from: authorization, rawNonce: appleNonce)
                try await session.signIn(with: credential, fallbackName: name, role: role)
            }
        }
    }

    private func signInWithGoogle() async {
        await run {
            let credential = try await SocialSignIn.googleCredential()
            try await session.signIn(with: credential, role: role)
        }
    }

    private func run(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        do {
            try await action()
            finish()
        } catch SocialSignInError.cancelled {
            // User closed the sheet: nothing to show
        } catch {
            errorMessage = error.friendlyMessage
        }
        isWorking = false
    }

    private func finish() {
        if let onSuccess { onSuccess() } else { dismiss() }
    }

    private func submit() async {
        isWorking = true
        errorMessage = nil
        do {
            if isSignUp {
                try await session.signUp(name: name, email: email, password: password, role: role)
            } else {
                try await session.signIn(email: email, password: password)
            }
            finish()
        } catch {
            errorMessage = error.friendlyMessage
        }
        isWorking = false
    }
}
