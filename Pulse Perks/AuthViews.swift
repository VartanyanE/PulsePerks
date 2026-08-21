//
//  AuthViews.swift
//  Pulse Perks
//

import Security
import SwiftUI

struct RootView: View {
    @State private var authSession = AuthSessionStore.load()
    @State private var authStatusMessage: String?

    private let configuration = SupabaseConfiguration.bundled

    var body: some View {
        Group {
            if let configuration, let authSession {
                if authSession.needsOnboarding {
                    OnboardingView(
                        configuration: configuration.authenticated(with: authSession),
                        authSession: authSession
                    ) { completedSession in
                        AuthSessionStore.save(completedSession)
                        self.authSession = completedSession
                    } signOut: {
                        signOut(configuration: configuration, authSession: authSession)
                    }
                } else {
                    ContentView(
                        configuration: configuration.authenticated(with: authSession),
                        authSession: authSession,
                        refreshSession: { force in
                            try await refreshSessionIfNeeded(force: force)
                        }
                    ) {
                        signOut(configuration: configuration, authSession: authSession)
                    }
                }
            } else {
                AuthView(configuration: configuration, initialStatusMessage: authStatusMessage) { session in
                    AuthSessionStore.save(session)
                    authStatusMessage = nil
                    authSession = session
                }
            }
        }
        .task {
            guard authSession != nil else {
                return
            }

            do {
                _ = try await refreshSessionIfNeeded()
            } catch {
                authStatusMessage = error.localizedDescription
            }
        }
    }

    private func refreshSessionIfNeeded(force: Bool = false) async throws -> AuthSession {
        guard let configuration, let authSession else {
            throw SupabaseAuthError.missingSession
        }

        guard force || authSession.shouldRefresh else {
            return authSession
        }

        let refreshedSession: AuthSession

        do {
            refreshedSession = try await SupabaseAuthClient(configuration: configuration)
                .refreshSession(authSession)
        } catch let error as PulsePerksAPIError where error.isRefreshSessionFailure {
            AuthSessionStore.clear()
            UserDataCache.clear(userID: authSession.userID)
            self.authSession = nil
            authStatusMessage = SupabaseAuthError.sessionExpired.localizedDescription
            throw SupabaseAuthError.sessionExpired
        }

        AuthSessionStore.save(refreshedSession)
        self.authSession = refreshedSession
        return refreshedSession
    }

    private func signOut(configuration: SupabaseConfiguration, authSession: AuthSession) {
        Task {
            try? await SupabaseAuthClient(configuration: configuration).signOut(authSession)
            AuthSessionStore.clear()
            UserDataCache.clear(userID: authSession.userID)
            self.authSession = nil
        }
    }
}

private struct OnboardingView: View {
    let configuration: SupabaseConfiguration
    let authSession: AuthSession
    let didComplete: (AuthSession) -> Void
    let signOut: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedInterestIDs = Set(["shopping", "wellness"])
    @State private var statusMessage: String?
    @State private var isSaving = false

    private let interests = Interest.sampleData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    interestsPicker
                    continueButton

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.stroke(for: colorScheme))
                            )
                    }
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign out", action: signOut)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("Personalize surveys")
                .font(.largeTitle.weight(.bold))

            Text("Choose the topics you care about so Pulse Perks can prioritize better survey matches.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.heroStart(for: colorScheme),
                    AppTheme.heroEnd(for: colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private var interestsPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Survey interests")
                .font(.title2.weight(.bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(interests) { interest in
                    InterestChip(
                        interest: interest,
                        isSelected: selectedInterestIDs.contains(interest.id)
                    ) {
                        toggleInterest(interest)
                    }
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private var continueButton: some View {
        Button {
            completeOnboarding()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }

                Text("Continue")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isSaving || selectedInterestIDs.isEmpty)
        .opacity(selectedInterestIDs.isEmpty ? 0.55 : 1)
    }

    private func toggleInterest(_ interest: Interest) {
        if selectedInterestIDs.contains(interest.id) {
            selectedInterestIDs.remove(interest.id)
        } else {
            selectedInterestIDs.insert(interest.id)
        }
    }

    private func completeOnboarding() {
        isSaving = true
        statusMessage = nil

        Task {
            do {
                let backend = SupabasePulsePerksClient(configuration: configuration)
                _ = try await backend.fetchBootstrap()
                _ = try await backend.updatePreferences(
                    PreferencesUpdateRequest(
                        selectedInterestIDs: Array(selectedInterestIDs).sorted(),
                        weeklyDigestEnabled: true,
                        nearbyPerksEnabled: true,
                        biometricUnlockEnabled: false
                    )
                )
                didComplete(authSession.completedOnboarding())
            } catch {
                statusMessage = error.localizedDescription
            }

            isSaving = false
        }
    }
}

private struct AuthView: View {
    let configuration: SupabaseConfiguration?
    let initialStatusMessage: String?
    let didAuthenticate: (AuthSession) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var mode = AuthMode.signIn
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var statusMessage: String?
    @State private var isLoading = false

    init(
        configuration: SupabaseConfiguration?,
        initialStatusMessage: String? = nil,
        didAuthenticate: @escaping (AuthSession) -> Void
    ) {
        self.configuration = configuration
        self.initialStatusMessage = initialStatusMessage
        self.didAuthenticate = didAuthenticate
        _statusMessage = State(initialValue: initialStatusMessage)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    form
                    submitButton
                    resetPasswordButton

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AppTheme.stroke(for: colorScheme))
                            )
                    }
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Pulse Perks")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "giftcard.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))

            Text(mode.title)
                .font(.largeTitle.weight(.bold))

            Text("Save perks, complete surveys, and keep your rewards synced across devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.heroStart(for: colorScheme),
                    AppTheme.heroEnd(for: colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private var form: some View {
        VStack(spacing: 12) {
            Picker("Auth mode", selection: $mode) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.pickerTitle).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if mode == .signUp {
                TextField("Name", text: $displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .authFieldStyle(colorScheme: colorScheme)
            }

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .authFieldStyle(colorScheme: colorScheme)

            SecureField("Password", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .authFieldStyle(colorScheme: colorScheme)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private var submitButton: some View {
        Button {
            authenticate()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: mode.iconName)
                }

                Text(mode.buttonTitle)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(red: 0.1, green: 0.55, blue: 0.42), in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(isLoading || !canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
    }

    @ViewBuilder
    private var resetPasswordButton: some View {
        if mode == .signIn {
            Button {
                sendPasswordReset()
            } label: {
                Label("Forgot password?", systemImage: "key")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(isLoading || !email.contains("@"))
            .opacity(email.contains("@") ? 1 : 0.55)
        }
    }

    private var canSubmit: Bool {
        guard configuration != nil, normalizedEmail.contains("@"), password.count >= 6 else {
            return false
        }

        return mode == .signIn || !normalizedDisplayName.isEmpty
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var normalizedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func authenticate() {
        guard let configuration else {
            statusMessage = "Supabase is not configured."
            return
        }

        isLoading = true
        statusMessage = nil

        Task {
            do {
                let client = SupabaseAuthClient(configuration: configuration)
                let session: AuthSession

                switch mode {
                case .signIn:
                    session = try await client.signIn(email: normalizedEmail, password: password)
                case .signUp:
                    session = try await client.signUp(
                        email: normalizedEmail,
                        password: password,
                        displayName: normalizedDisplayName
                    )
                }

                didAuthenticate(session)
            } catch {
                statusMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func sendPasswordReset() {
        guard let configuration else {
            statusMessage = "Supabase is not configured."
            return
        }

        guard normalizedEmail.contains("@") else {
            statusMessage = "Enter your email first."
            return
        }

        isLoading = true
        statusMessage = nil

        Task {
            do {
                try await SupabaseAuthClient(configuration: configuration)
                    .sendPasswordReset(email: normalizedEmail)
                statusMessage = "Password reset email sent. Check your inbox."
            } catch {
                statusMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .signIn:
            "Welcome back"
        case .signUp:
            "Create account"
        }
    }

    var pickerTitle: String {
        switch self {
        case .signIn:
            "Sign in"
        case .signUp:
            "Sign up"
        }
    }

    var buttonTitle: String {
        switch self {
        case .signIn:
            "Sign in"
        case .signUp:
            "Create account"
        }
    }

    var iconName: String {
        switch self {
        case .signIn:
            "arrow.right.circle.fill"
        case .signUp:
            "person.badge.plus"
        }
    }
}

private extension AuthSession {
    func completedOnboarding() -> AuthSession {
        AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            email: email,
            displayName: displayName,
            expiresAt: expiresAt,
            needsOnboarding: false
        )
    }
}

private enum AuthSessionStore {
    private static let account = "supabaseAuthSession"
    private static let legacyKey = "supabaseAuthSession"
    private static let service = Bundle.main.bundleIdentifier ?? "zanerapi.Pulse-Perks"

    static func load() -> AuthSession? {
        if let session = loadFromKeychain() {
            return session
        }

        guard let legacyData = UserDefaults.standard.data(forKey: legacyKey),
              let legacySession = try? JSONDecoder().decode(AuthSession.self, from: legacyData) else {
            return nil
        }

        save(legacySession)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return legacySession
    }

    static func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else {
            return
        }

        clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: legacyKey)
    }

    private static func loadFromKeychain() -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }
}

private extension View {
    func authFieldStyle(colorScheme: ColorScheme) -> some View {
        padding(.horizontal, 14)
            .frame(height: 48)
            .background(AppTheme.controlBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.stroke(for: colorScheme))
            )
    }
}
