//
//  RewardLoopBackend.swift
//  RewardLoop
//

import Foundation

private let backendRequestTimeout: TimeInterval = 20
private let maximumUserFacingBackendMessageLength = 240

protocol RewardLoopBackend {
    func fetchBootstrap() async throws -> RewardLoopBootstrapResponse
    func fetchPartnerSurveyOffers() async throws -> [PartnerSurveyOfferResponse]
    func fetchPartnerSurveySessions() async throws -> [PartnerSurveySessionResponse]
    func startPartnerSurvey(offerID: String) async throws -> PartnerSurveySessionResponse
    func savePerk(id: String, isSaved: Bool) async throws -> MemberActivityResponse
    func redeemPerk(id: String) async throws -> MemberActivityResponse
    func trackOfferClick(perkID: String, offerURL: URL) async throws
    func completeSurvey(id: String, responses: [SurveyAnswerRequest]) async throws -> MemberActivityResponse
    func syncActivity(_ activity: MemberActivityResponse) async throws -> MemberActivityResponse
    func updatePreferences(_ request: PreferencesUpdateRequest) async throws -> MemberActivityResponse
    func updateProfile(_ request: ProfileUpdateRequest) async throws -> MemberProfileResponse
}

struct SupabaseRewardLoopClient: RewardLoopBackend {
    var configuration: SupabaseConfiguration
    var session: URLSession = .shared

    func fetchBootstrap() async throws -> RewardLoopBootstrapResponse {
        try await ensureMemberProfile()

        let memberProfile: MemberProfileResponse = try await fetchSingle(
            table: "member_profiles",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(configuration.memberID)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        let rewards: RewardsConfigurationResponse = try await fetchSingle(
            table: "app_config",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.default"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        let perks: [PerkResponse] = try await fetchTable(
            "perks",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        let collections: [PerkCollectionResponse] = try await fetchTable(
            "perk_collections",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        let surveys: [SurveyResponse] = try await fetchTable(
            "surveys",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        let interests: [InterestResponse] = try await fetchTable(
            "interests",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        let activity = try await fetchActivity()

        return RewardLoopBootstrapResponse(
            member: memberProfile,
            rewards: rewards,
            categories: rewards.categories,
            perks: perks,
            collections: collections,
            surveys: surveys,
            interests: interests,
            activity: activity
        )
    }

    private func ensureMemberProfile() async throws {
        let profile = MemberProfileRow(
            id: configuration.memberID,
            name: configuration.memberName,
            tier: "Pulse Plus",
            memberCode: "PULSE-\(configuration.memberID.prefix(6).uppercased())",
            memberSinceYear: 2026
        )

        let _: EmptyResponse = try await send(
            table: "member_profiles",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            body: profile,
            prefer: "resolution=ignore-duplicates,return=minimal"
        )
    }

    func fetchPartnerSurveyOffers() async throws -> [PartnerSurveyOfferResponse] {
        try await fetchTable(
            "partner_survey_offers",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
    }

    func fetchPartnerSurveySessions() async throws -> [PartnerSurveySessionResponse] {
        let rows: [PartnerSurveySessionRow] = try await fetchTable(
            "partner_survey_sessions",
            queryItems: [
                URLQueryItem(name: "member_id", value: "eq.\(configuration.memberID)"),
                URLQueryItem(name: "order", value: "started_at.desc")
            ]
        )

        return rows.map(\.response)
    }

    func startPartnerSurvey(offerID: String) async throws -> PartnerSurveySessionResponse {
        let offer: PartnerSurveyOfferResponse = try await fetchSingle(
            table: "partner_survey_offers",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(offerID)"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )

        guard URL.supportedOfferURL(from: offer.entryURL) != nil else {
            throw RewardLoopAPIError.invalidURL
        }

        let row = PartnerSurveySessionRow(
            memberID: configuration.memberID,
            offerID: offer.id,
            provider: offer.provider,
            providerSurveyID: offer.providerSurveyID,
            status: .started,
            rewardPoints: offer.rewardPoints,
            entryURL: offer.entryURL,
            startedAt: ISO8601DateFormatter().string(from: Date())
        )

        let rows: [PartnerSurveySessionRow] = try await send(
            table: "partner_survey_sessions",
            method: "POST",
            queryItems: [],
            body: row,
            prefer: "return=representation"
        )

        guard let savedRow = rows.first else {
            throw SupabaseError.emptyResponse
        }

        return savedRow.response
    }

    func savePerk(id: String, isSaved: Bool) async throws -> MemberActivityResponse {
        try await updateSavedPerkRow(perkID: id, isSaved: isSaved)

        var activity = try await fetchActivity()

        if isSaved {
            activity.savedPerkIDs = Array(Set(activity.savedPerkIDs).union([id])).sorted()
        } else {
            activity.savedPerkIDs = activity.savedPerkIDs.filter { $0 != id }
        }

        return try await updateActivity(activity)
    }

    private func updateSavedPerkRow(perkID: String, isSaved: Bool) async throws {
        if isSaved {
            let row = SavedPerkRow(
                memberID: configuration.memberID,
                perkID: perkID,
                savedAt: ISO8601DateFormatter().string(from: Date())
            )

            let _: [SavedPerkRow] = try await send(
                table: "saved_perks",
                method: "POST",
                queryItems: [URLQueryItem(name: "on_conflict", value: "member_id,perk_id")],
                body: row,
                prefer: "resolution=merge-duplicates,return=representation"
            )
        } else {
            let _: EmptyResponse = try await send(
                table: "saved_perks",
                method: "DELETE",
                queryItems: [
                    URLQueryItem(name: "member_id", value: "eq.\(configuration.memberID)"),
                    URLQueryItem(name: "perk_id", value: "eq.\(perkID)")
                ],
                body: Optional<EmptyRequest>.none,
                prefer: nil
            )
        }
    }

    func redeemPerk(id: String) async throws -> MemberActivityResponse {
        try await saveRedemption(perkID: id)

        var activity = try await fetchActivity()
        activity.redeemedPerkIDs = Array(Set(activity.redeemedPerkIDs).union([id])).sorted()
        return try await updateActivity(activity)
    }

    func trackOfferClick(perkID: String, offerURL: URL) async throws {
        let row = OfferClickRow(
            memberID: configuration.memberID,
            perkID: perkID,
            offerURL: offerURL.absoluteString,
            clickedAt: ISO8601DateFormatter().string(from: Date())
        )

        let _: EmptyResponse = try await send(
            table: "offer_clicks",
            method: "POST",
            queryItems: [],
            body: row,
            prefer: "return=minimal"
        )
    }

    private func saveRedemption(perkID: String) async throws {
        let row = PerkRedemptionRow(
            memberID: configuration.memberID,
            perkID: perkID,
            redeemedAt: ISO8601DateFormatter().string(from: Date())
        )

        let _: [PerkRedemptionRow] = try await send(
            table: "perk_redemptions",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "member_id,perk_id")],
            body: row,
            prefer: "resolution=ignore-duplicates,return=representation"
        )
    }

    func completeSurvey(id: String, responses: [SurveyAnswerRequest]) async throws -> MemberActivityResponse {
        try await saveSurveyResponses(surveyID: id, responses: responses)

        var activity = try await fetchActivity()
        activity.completedSurveyIDs = Array(Set(activity.completedSurveyIDs).union([id])).sorted()
        return try await updateActivity(activity)
    }

    private func saveSurveyResponses(surveyID: String, responses: [SurveyAnswerRequest]) async throws {
        let submittedAt = ISO8601DateFormatter().string(from: Date())
        let rows = responses.map { response in
            SurveyResponseRow(
                memberID: configuration.memberID,
                surveyID: surveyID,
                questionIndex: response.questionIndex,
                question: response.question,
                answer: response.answer,
                submittedAt: submittedAt
            )
        }

        let _: [SurveyResponseRow] = try await send(
            table: "survey_responses",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "member_id,survey_id,question_index")],
            body: rows,
            prefer: "resolution=merge-duplicates,return=representation"
        )
    }

    func updatePreferences(_ request: PreferencesUpdateRequest) async throws -> MemberActivityResponse {
        var activity = try await fetchActivity()
        activity.selectedInterestIDs = request.selectedInterestIDs
        activity.weeklyDigestEnabled = request.weeklyDigestEnabled
        activity.nearbyPerksEnabled = request.nearbyPerksEnabled
        return try await updateActivity(activity)
    }

    func syncActivity(_ activity: MemberActivityResponse) async throws -> MemberActivityResponse {
        try await updateActivity(activity.normalized)
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws -> MemberProfileResponse {
        let profile = MemberProfileRow(
            id: configuration.memberID,
            name: request.name,
            tier: request.tier,
            memberCode: request.memberCode,
            memberSinceYear: request.memberSinceYear
        )

        let rows: [MemberProfileResponse] = try await send(
            table: "member_profiles",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "id")],
            body: profile,
            prefer: "resolution=merge-duplicates,return=representation"
        )

        guard let updatedProfile = rows.first else {
            throw SupabaseError.emptyResponse
        }

        return updatedProfile
    }

    private func fetchActivity() async throws -> MemberActivityResponse {
        do {
            let row: MemberActivityRow = try await fetchSingle(
                table: "member_activity",
                queryItems: [
                    URLQueryItem(name: "member_id", value: "eq.\(configuration.memberID)"),
                    URLQueryItem(name: "limit", value: "1")
                ]
            )
            return row.response
        } catch SupabaseError.emptyResponse {
            return try await updateActivity(.defaultActivity)
        }
    }

    private func updateActivity(_ activity: MemberActivityResponse) async throws -> MemberActivityResponse {
        let row = MemberActivityRow(memberID: configuration.memberID, activity: activity)
        let rows: [MemberActivityRow] = try await send(
            table: "member_activity",
            method: "POST",
            queryItems: [URLQueryItem(name: "on_conflict", value: "member_id")],
            body: row,
            prefer: "resolution=merge-duplicates,return=representation"
        )

        guard let updatedRow = rows.first else {
            throw SupabaseError.emptyResponse
        }

        return updatedRow.response
    }

    private func fetchSingle<Response: Decodable>(
        table: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        let rows: [Response] = try await fetchTable(table, queryItems: queryItems)

        guard let row = rows.first else {
            throw SupabaseError.emptyResponse
        }

        return row
    }

    private func fetchTable<Response: Decodable>(
        _ table: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> [Response] {
        try await send(
            table: table,
            method: "GET",
            queryItems: [URLQueryItem(name: "select", value: "*")] + queryItems,
            body: Optional<EmptyRequest>.none,
            prefer: nil
        )
    }

    private func send<RequestBody: Encodable, Response: Decodable>(
        table: String,
        method: String,
        queryItems: [URLQueryItem],
        body: RequestBody?,
        prefer: String?
    ) async throws -> Response {
        var components = URLComponents(
            url: configuration.projectURL.appending(path: "rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw RewardLoopAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = backendRequestTimeout
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        if let body {
            request.httpBody = try JSONEncoder.supabase.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RewardLoopAPIError.networkFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RewardLoopAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw RewardLoopAPIError.requestFailed(statusCode: httpResponse.statusCode, data: data)
        }

        return try decodeBackendResponse(Response.self, from: data, using: .supabase)
    }
}

struct RewardLoopAPIClient: RewardLoopBackend {
    var configuration: BackendConfiguration
    var session: URLSession = .shared

    func fetchBootstrap() async throws -> RewardLoopBootstrapResponse {
        try await send(path: "/v1/bootstrap", method: "GET")
    }

    func fetchPartnerSurveyOffers() async throws -> [PartnerSurveyOfferResponse] {
        try await send(path: "/v1/me/partner-surveys", method: "GET")
    }

    func fetchPartnerSurveySessions() async throws -> [PartnerSurveySessionResponse] {
        try await send(path: "/v1/me/partner-survey-sessions", method: "GET")
    }

    func startPartnerSurvey(offerID: String) async throws -> PartnerSurveySessionResponse {
        try await send(path: "/v1/me/partner-surveys/\(offerID)/sessions", method: "POST")
    }

    func savePerk(id: String, isSaved: Bool) async throws -> MemberActivityResponse {
        try await send(
            path: "/v1/me/perks/\(id)/saved",
            method: "PUT",
            body: SavePerkRequest(isSaved: isSaved)
        )
    }

    func redeemPerk(id: String) async throws -> MemberActivityResponse {
        try await send(path: "/v1/me/perks/\(id)/redemptions", method: "POST")
    }

    func trackOfferClick(perkID: String, offerURL: URL) async throws {
        let _: EmptyResponse = try await send(
            path: "/v1/me/perks/\(perkID)/offer-clicks",
            method: "POST",
            body: OfferClickRequest(offerURL: offerURL.absoluteString)
        )
    }

    func completeSurvey(id: String, responses: [SurveyAnswerRequest]) async throws -> MemberActivityResponse {
        try await send(
            path: "/v1/me/surveys/\(id)/completion",
            method: "POST",
            body: SurveyCompletionRequest(responses: responses)
        )
    }

    func syncActivity(_ activity: MemberActivityResponse) async throws -> MemberActivityResponse {
        try await send(path: "/v1/me/activity", method: "PUT", body: activity.normalized)
    }

    func updatePreferences(_ request: PreferencesUpdateRequest) async throws -> MemberActivityResponse {
        try await send(path: "/v1/me/preferences", method: "PUT", body: request)
    }

    func updateProfile(_ request: ProfileUpdateRequest) async throws -> MemberProfileResponse {
        try await send(path: "/v1/me/profile", method: "PUT", body: request)
    }

    private func send<Response: Decodable>(
        path: String,
        method: String
    ) async throws -> Response {
        let emptyBody: EmptyRequest? = nil
        return try await send(path: path, method: method, body: emptyBody)
    }

    private func send<RequestBody: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: RequestBody?
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: configuration.baseURL) else {
            throw RewardLoopAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = backendRequestTimeout
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let bearerToken = configuration.bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder.pulsePerks.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RewardLoopAPIError.networkFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RewardLoopAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw RewardLoopAPIError.requestFailed(statusCode: httpResponse.statusCode, data: data)
        }

        return try decodeBackendResponse(Response.self, from: data, using: .pulsePerks)
    }
}

struct BackendConfiguration: Equatable, Sendable {
    var baseURL: URL
    var bearerToken: String?

    static let development = BackendConfiguration(
        baseURL: URL(string: "https://api.example.com")!,
        bearerToken: nil
    )
}

struct SupabaseAuthClient {
    var configuration: SupabaseConfiguration
    var session: URLSession = .shared

    func signUp(email: String, password: String, displayName: String) async throws -> AuthSession {
        let response: SupabaseAuthResponse = try await send(
            path: "auth/v1/signup",
            method: "POST",
            queryItems: [],
            body: AuthSignUpRequest(
                email: email,
                password: password,
                data: AuthUserMetadata(name: displayName)
            ),
            authorizationToken: configuration.anonKey
        )

        guard let session = response.authSession(displayNameFallback: displayName, needsOnboarding: true) else {
            throw SupabaseAuthError.emailConfirmationRequired
        }

        return session
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let response: SupabaseAuthResponse = try await send(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: AuthPasswordRequest(email: email, password: password),
            authorizationToken: configuration.anonKey
        )

        guard let session = response.authSession(displayNameFallback: email, needsOnboarding: false) else {
            throw SupabaseAuthError.missingSession
        }

        return session
    }

    func refreshSession(_ authSession: AuthSession) async throws -> AuthSession {
        let response: SupabaseAuthResponse = try await send(
            path: "auth/v1/token",
            method: "POST",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: AuthRefreshRequest(refreshToken: authSession.refreshToken),
            authorizationToken: configuration.anonKey
        )

        guard let session = response.authSession(
            displayNameFallback: authSession.displayName,
            needsOnboarding: authSession.needsOnboarding
        ) else {
            throw SupabaseAuthError.missingSession
        }

        return session
    }

    func sendPasswordReset(email: String) async throws {
        let _: EmptyResponse = try await send(
            path: "auth/v1/recover",
            method: "POST",
            queryItems: [],
            body: AuthPasswordResetRequest(email: email),
            authorizationToken: configuration.anonKey
        )
    }

    func signOut(_ authSession: AuthSession) async throws {
        let _: EmptyResponse = try await send(
            path: "auth/v1/logout",
            method: "POST",
            queryItems: [],
            body: Optional<EmptyRequest>.none,
            authorizationToken: authSession.accessToken
        )
    }

    private func send<RequestBody: Encodable, Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: RequestBody?,
        authorizationToken: String
    ) async throws -> Response {
        var components = URLComponents(
            url: configuration.projectURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw RewardLoopAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = backendRequestTimeout
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authorizationToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try JSONEncoder.supabase.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RewardLoopAPIError.networkFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RewardLoopAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw RewardLoopAPIError.requestFailed(statusCode: httpResponse.statusCode, data: data)
        }

        return try decodeBackendResponse(Response.self, from: data, using: .supabase)
    }
}

private func decodeBackendResponse<Response: Decodable>(
    _ responseType: Response.Type,
    from data: Data,
    using decoder: JSONDecoder
) throws -> Response {
    if data.isEmpty {
        guard let emptyResponseType = responseType as? EmptyBackendResponse.Type,
              let response = emptyResponseType.init() as? Response else {
            throw RewardLoopAPIError.emptyResponse
        }

        return response
    }

    do {
        return try decoder.decode(Response.self, from: data)
    } catch {
        throw RewardLoopAPIError.decodingFailed(error)
    }
}

struct SupabaseConfiguration: Equatable, Sendable {
    var projectURL: URL
    var anonKey: String
    var memberID: String
    var accessToken: String?
    var memberName: String

    static var current: SupabaseConfiguration? {
        guard let urlValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              isConfiguredSecret(urlValue, placeholder: "YOUR_SUPABASE_URL"),
              isConfiguredSecret(anonKey, placeholder: "YOUR_SUPABASE_ANON_KEY"),
              let url = URL(string: urlValue) else {
            return nil
        }

        let memberID = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_MEMBER_ID") as? String)
            .flatMap { isConfiguredSecret($0, placeholder: "YOUR_SUPABASE_MEMBER_ID") ? $0 : nil } ?? MemberProfile.demo.id

        return SupabaseConfiguration(
            projectURL: url,
            anonKey: anonKey,
            memberID: memberID,
            accessToken: nil,
            memberName: "Emanuil"
        )
    }

    static var bundled: SupabaseConfiguration? {
        current
    }

    func authenticated(with session: AuthSession) -> SupabaseConfiguration {
        SupabaseConfiguration(
            projectURL: projectURL,
            anonKey: anonKey,
            memberID: session.userID,
            accessToken: session.accessToken,
            memberName: session.displayName
        )
    }

    var authorizationToken: String {
        accessToken ?? anonKey
    }

    static func isConfiguredSecret(_ value: String, placeholder: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty,
              trimmedValue != placeholder,
              !trimmedValue.contains("YOUR_SUPABASE_"),
              !trimmedValue.contains("$(") else {
            return false
        }

        return true
    }
}

struct AuthSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userID: String
    let email: String
    let displayName: String
    let expiresAt: Date
    let needsOnboarding: Bool

    var shouldRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 300
    }

    init(
        accessToken: String,
        refreshToken: String,
        userID: String,
        email: String,
        displayName: String,
        expiresAt: Date,
        needsOnboarding: Bool
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        self.email = email
        self.displayName = displayName
        self.expiresAt = expiresAt
        self.needsOnboarding = needsOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        userID = try container.decode(String.self, forKey: .userID)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        needsOnboarding = try container.decodeIfPresent(Bool.self, forKey: .needsOnboarding) ?? false
    }
}

enum RewardLoopAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case requestFailed(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case networkFailed(Error)

    static func == (lhs: RewardLoopAPIError, rhs: RewardLoopAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL), (.invalidResponse, .invalidResponse), (.emptyResponse, .emptyResponse):
            true
        case let (.requestFailed(lhsStatus, lhsData), .requestFailed(rhsStatus, rhsData)):
            lhsStatus == rhsStatus && lhsData == rhsData
        case (.decodingFailed, .decodingFailed), (.networkFailed, .networkFailed):
            true
        default:
            false
        }
    }
}

extension RewardLoopAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid backend URL"
        case .invalidResponse:
            "Backend returned an invalid response"
        case .emptyResponse:
            "Backend returned an empty response"
        case let .requestFailed(statusCode, data):
            if let message = SupabaseErrorMessage(data: data)?.userFacingMessage(statusCode: statusCode) {
                message
            } else if statusCode == 429 {
                "Supabase rate limit reached. Wait a few minutes, then try again."
            } else if let message = sanitizedBackendMessage(from: data), !message.isEmpty {
                "Backend request failed (\(statusCode)): \(message)"
            } else {
                "Backend request failed (\(statusCode))"
            }
        case let .decodingFailed(error):
            "Could not read backend response: \(error.localizedDescription)"
        case let .networkFailed(error):
            if let urlError = error as? URLError {
                "Could not reach backend (\(urlError.code.rawValue)): \(urlError.localizedDescription)"
            } else {
                "Could not reach backend: \(error.localizedDescription)"
            }
        }
    }
}

extension RewardLoopAPIError {
    var isAuthenticationFailure: Bool {
        guard case let .requestFailed(statusCode, _) = self else {
            return false
        }

        return statusCode == 401 || statusCode == 403
    }

    var isRefreshSessionFailure: Bool {
        guard case let .requestFailed(statusCode, _) = self else {
            return false
        }

        return statusCode == 400 || statusCode == 401 || statusCode == 403
    }

    var isTransientFailure: Bool {
        switch self {
        case let .requestFailed(statusCode, _):
            return statusCode == 408 || statusCode == 429 || 500..<600 ~= statusCode
        case let .networkFailed(error):
            guard let urlError = error as? URLError else {
                return true
            }

            return [
                .cannotFindHost,
                .cannotConnectToHost,
                .dnsLookupFailed,
                .internationalRoamingOff,
                .networkConnectionLost,
                .notConnectedToInternet,
                .timedOut
            ].contains(urlError.code)
        case .invalidURL, .invalidResponse, .emptyResponse, .decodingFailed:
            return false
        }
    }
}

private struct SupabaseErrorMessage: Decodable, Sendable {
    let code: Int?
    let errorCode: String?
    let message: String?
    let msg: String?

    enum CodingKeys: String, CodingKey {
        case code
        case errorCode = "error_code"
        case message
        case msg
    }

    init?(data: Data) {
        guard let error = try? JSONDecoder.supabase.decode(SupabaseErrorMessage.self, from: data) else {
            return nil
        }

        self = error
    }

    func userFacingMessage(statusCode: Int) -> String? {
        let rawMessage = message ?? msg

        if errorCode == "over_email_send_rate_limit" {
            return "Supabase email rate limit reached. Wait a few minutes, then try signing in or use a different test email."
        }

        if statusCode == 429 {
            return rawMessage.map { "Supabase rate limit reached: \(sanitizedBackendMessage($0))" }
                ?? "Supabase rate limit reached. Wait a few minutes, then try again."
        }

        return rawMessage.map { "Backend request failed (\(statusCode)): \(sanitizedBackendMessage($0))" }
    }
}

private func sanitizedBackendMessage(from data: Data) -> String? {
    guard let message = String(data: data, encoding: .utf8) else {
        return nil
    }

    return sanitizedBackendMessage(message)
}

private func sanitizedBackendMessage(_ message: String) -> String {
    let collapsedMessage = message
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
        .replacingOccurrences(of: "\t", with: " ")
        .split(separator: " ")
        .joined(separator: " ")

    guard collapsedMessage.count > maximumUserFacingBackendMessageLength else {
        return collapsedMessage
    }

    let endIndex = collapsedMessage.index(
        collapsedMessage.startIndex,
        offsetBy: maximumUserFacingBackendMessageLength
    )

    return "\(collapsedMessage[..<endIndex])..."
}

enum SupabaseError: Error, Equatable {
    case emptyResponse
}

extension SupabaseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            "Supabase returned no matching rows"
        }
    }
}

enum SupabaseAuthError: Error, Equatable {
    case emailConfirmationRequired
    case missingSession
    case sessionExpired
}

extension SupabaseAuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            "Check your email to confirm your account, then sign in."
        case .missingSession:
            "Supabase did not return a valid session."
        case .sessionExpired:
            "Your session expired. Sign in again."
        }
    }
}

struct RewardLoopBootstrapResponse: Codable, Equatable, Sendable {
    let member: MemberProfileResponse
    let rewards: RewardsConfigurationResponse
    let categories: [String]
    let perks: [PerkResponse]
    let collections: [PerkCollectionResponse]
    let surveys: [SurveyResponse]
    let interests: [InterestResponse]
    let activity: MemberActivityResponse
}

struct RewardsConfigurationResponse: Codable, Equatable, Sendable {
    let categories: [String]
    let basePoints: Int
    let pointsPerRedemption: Int
    let nextRewardPoints: Int
    let dailySurveyGoal: Int

    enum CodingKeys: String, CodingKey {
        case categories
        case basePoints = "base_points"
        case pointsPerRedemption = "points_per_redemption"
        case nextRewardPoints = "next_reward_points"
        case dailySurveyGoal = "daily_survey_goal"
    }
}

struct MemberProfileResponse: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let tier: String
    let memberCode: String
    let memberSinceYear: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tier
        case memberCode = "member_code"
        case memberSinceYear = "member_since_year"
    }
}

struct MemberActivityResponse: Codable, Equatable, Sendable {
    var savedPerkIDs: [String]
    var redeemedPerkIDs: [String]
    var completedSurveyIDs: [String]
    var selectedInterestIDs: [String]
    var weeklyDigestEnabled: Bool
    var nearbyPerksEnabled: Bool
    var serverUpdatedAt: Date? = nil

    static let defaultActivity = MemberActivityResponse(
        savedPerkIDs: [],
        redeemedPerkIDs: [],
        completedSurveyIDs: [],
        selectedInterestIDs: ["shopping", "wellness"],
        weeklyDigestEnabled: true,
        nearbyPerksEnabled: true
    )

    enum CodingKeys: String, CodingKey {
        case savedPerkIDs = "savedPerkIDs"
        case redeemedPerkIDs = "redeemedPerkIDs"
        case completedSurveyIDs = "completedSurveyIDs"
        case selectedInterestIDs = "selectedInterestIDs"
        case weeklyDigestEnabled
        case nearbyPerksEnabled
    }

    var normalized: MemberActivityResponse {
        return MemberActivityResponse(
            savedPerkIDs: Array(Set(savedPerkIDs)).sorted(),
            redeemedPerkIDs: Array(Set(redeemedPerkIDs)).sorted(),
            completedSurveyIDs: Array(Set(completedSurveyIDs)).sorted(),
            selectedInterestIDs: Array(Set(selectedInterestIDs)).sorted(),
            weeklyDigestEnabled: weeklyDigestEnabled,
            nearbyPerksEnabled: nearbyPerksEnabled,
            serverUpdatedAt: serverUpdatedAt
        )
    }

    func mergedWithLocalSnapshot(_ localSnapshot: MemberActivityResponse, localModifiedAt: Date? = nil) -> MemberActivityResponse {
        let shouldPreferLocalPreferences: Bool

        if let serverUpdatedAt, let localModifiedAt {
            shouldPreferLocalPreferences = localModifiedAt > serverUpdatedAt
        } else {
            shouldPreferLocalPreferences = true
        }

        return MemberActivityResponse(
            savedPerkIDs: Array(Set(savedPerkIDs).union(localSnapshot.savedPerkIDs)).sorted(),
            redeemedPerkIDs: Array(Set(redeemedPerkIDs).union(localSnapshot.redeemedPerkIDs)).sorted(),
            completedSurveyIDs: Array(Set(completedSurveyIDs).union(localSnapshot.completedSurveyIDs)).sorted(),
            selectedInterestIDs: shouldPreferLocalPreferences && !localSnapshot.selectedInterestIDs.isEmpty
                ? Array(Set(localSnapshot.selectedInterestIDs)).sorted()
                : Array(Set(selectedInterestIDs)).sorted(),
            weeklyDigestEnabled: shouldPreferLocalPreferences ? localSnapshot.weeklyDigestEnabled : weeklyDigestEnabled,
            nearbyPerksEnabled: shouldPreferLocalPreferences ? localSnapshot.nearbyPerksEnabled : nearbyPerksEnabled,
            serverUpdatedAt: serverUpdatedAt
        )
    }
}

struct PerkResponse: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let partner: String
    let category: String
    let expiration: String
    let distance: String
    let distanceInMiles: Double
    let daysUntilExpiration: Int
    let shortDetail: String
    let redemptionInstructions: String
    let terms: String
    let estimatedSavings: Int
    let memberCode: String
    let offerURL: String?
    let offerKind: OfferKind?
    let iconName: String
    let tintHex: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case partner
        case category
        case expiration
        case distance
        case distanceInMiles = "distance_in_miles"
        case daysUntilExpiration = "days_until_expiration"
        case shortDetail = "short_detail"
        case redemptionInstructions = "redemption_instructions"
        case terms
        case estimatedSavings = "estimated_savings"
        case memberCode = "member_code"
        case offerURL = "offer_url"
        case offerKind = "offer_kind"
        case iconName = "icon_name"
        case tintHex = "tint_hex"
    }
}

struct PerkCollectionResponse: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let searchText: String
    let sort: PerkSort
    let iconName: String
    let tintHex: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case category
        case searchText = "search_text"
        case sort
        case iconName = "icon_name"
        case tintHex = "tint_hex"
    }
}

struct SurveyResponse: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let estimatedTime: String
    let audience: String
    let points: Int
    let matchScore: Int
    let matchReason: String
    let interestIDs: [String]
    let questions: [String]
    let iconName: String
    let tintHex: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case estimatedTime = "estimated_time"
        case audience
        case points
        case matchScore = "match_score"
        case matchReason = "match_reason"
        case interestIDs = "interest_ids"
        case questions
        case iconName = "icon_name"
        case tintHex = "tint_hex"
    }
}

struct InterestResponse: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let iconName: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case iconName = "icon_name"
    }
}

struct PartnerSurveyOfferResponse: Codable, Equatable, Sendable {
    let id: String
    let provider: PartnerSurveyProvider
    let providerSurveyID: String
    let title: String
    let description: String
    let estimatedTime: String
    let rewardPoints: Int
    let category: String
    let matchScore: Int
    let entryURL: String
    let disclosure: String

    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case providerSurveyID = "provider_survey_id"
        case title
        case description
        case estimatedTime = "estimated_time"
        case rewardPoints = "reward_points"
        case category
        case matchScore = "match_score"
        case entryURL = "entry_url"
        case disclosure
    }
}

struct PartnerSurveySessionResponse: Codable, Equatable, Sendable {
    let id: String
    let offerID: String
    let provider: PartnerSurveyProvider
    let status: PartnerSurveySessionStatus
    let rewardPoints: Int
    let entryURL: String
    let startedAt: String
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerID = "offer_id"
        case provider
        case status
        case rewardPoints = "reward_points"
        case entryURL = "entry_url"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

private struct MemberProfileRow: Encodable, Equatable, Sendable {
    let id: String
    let name: String
    let tier: String
    let memberCode: String
    let memberSinceYear: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tier
        case memberCode = "member_code"
        case memberSinceYear = "member_since_year"
    }
}

private struct MemberActivityRow: Codable, Equatable, Sendable {
    let memberID: String
    let savedPerkIDs: [String]
    let redeemedPerkIDs: [String]
    let completedSurveyIDs: [String]
    let selectedInterestIDs: [String]
    let weeklyDigestEnabled: Bool
    let nearbyPerksEnabled: Bool
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case savedPerkIDs = "saved_perk_ids"
        case redeemedPerkIDs = "redeemed_perk_ids"
        case completedSurveyIDs = "completed_survey_ids"
        case selectedInterestIDs = "selected_interest_ids"
        case weeklyDigestEnabled = "weekly_digest_enabled"
        case nearbyPerksEnabled = "nearby_perks_enabled"
        case updatedAt = "updated_at"
    }

    init(memberID: String, activity: MemberActivityResponse) {
        self.memberID = memberID
        savedPerkIDs = activity.savedPerkIDs
        redeemedPerkIDs = activity.redeemedPerkIDs
        completedSurveyIDs = activity.completedSurveyIDs
        selectedInterestIDs = activity.selectedInterestIDs
        weeklyDigestEnabled = activity.weeklyDigestEnabled
        nearbyPerksEnabled = activity.nearbyPerksEnabled
        updatedAt = nil
    }

    var response: MemberActivityResponse {
        MemberActivityResponse(
            savedPerkIDs: savedPerkIDs,
            redeemedPerkIDs: redeemedPerkIDs,
            completedSurveyIDs: completedSurveyIDs,
            selectedInterestIDs: selectedInterestIDs,
            weeklyDigestEnabled: weeklyDigestEnabled,
            nearbyPerksEnabled: nearbyPerksEnabled,
            serverUpdatedAt: updatedAt.flatMap(Self.parseDate)
        )
    }

    nonisolated private static func parseDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return fractionalFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

struct SurveyAnswerRequest: Encodable, Equatable, Sendable {
    let questionIndex: Int
    let question: String
    let answer: String
}

struct SurveyCompletionRequest: Encodable, Equatable, Sendable {
    let responses: [SurveyAnswerRequest]
}

private struct PerkRedemptionRow: Codable, Equatable, Sendable {
    let memberID: String
    let perkID: String
    let redeemedAt: String

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case perkID = "perk_id"
        case redeemedAt = "redeemed_at"
    }
}

private struct OfferClickRow: Codable, Equatable, Sendable {
    let memberID: String
    let perkID: String
    let offerURL: String
    let clickedAt: String

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case perkID = "perk_id"
        case offerURL = "offer_url"
        case clickedAt = "clicked_at"
    }
}

private struct OfferClickRequest: Encodable, Equatable, Sendable {
    let offerURL: String

    enum CodingKeys: String, CodingKey {
        case offerURL = "offer_url"
    }
}

private struct PartnerSurveySessionRow: Codable, Equatable, Sendable {
    let id: String?
    let memberID: String
    let offerID: String
    let provider: PartnerSurveyProvider
    let providerSurveyID: String
    let status: PartnerSurveySessionStatus
    let rewardPoints: Int
    let entryURL: String
    let startedAt: String
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case memberID = "member_id"
        case offerID = "offer_id"
        case provider
        case providerSurveyID = "provider_survey_id"
        case status
        case rewardPoints = "reward_points"
        case entryURL = "entry_url"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    init(
        memberID: String,
        offerID: String,
        provider: PartnerSurveyProvider,
        providerSurveyID: String,
        status: PartnerSurveySessionStatus,
        rewardPoints: Int,
        entryURL: String,
        startedAt: String
    ) {
        id = nil
        self.memberID = memberID
        self.offerID = offerID
        self.provider = provider
        self.providerSurveyID = providerSurveyID
        self.status = status
        self.rewardPoints = rewardPoints
        self.entryURL = entryURL
        self.startedAt = startedAt
        completedAt = nil
    }

    var response: PartnerSurveySessionResponse {
        PartnerSurveySessionResponse(
            id: id ?? "",
            offerID: offerID,
            provider: provider,
            status: status,
            rewardPoints: rewardPoints,
            entryURL: entryURL,
            startedAt: startedAt,
            completedAt: completedAt
        )
    }
}

private struct SavedPerkRow: Codable, Equatable, Sendable {
    let memberID: String
    let perkID: String
    let savedAt: String

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case perkID = "perk_id"
        case savedAt = "saved_at"
    }
}

private struct SurveyResponseRow: Codable, Equatable, Sendable {
    let memberID: String
    let surveyID: String
    let questionIndex: Int
    let question: String
    let answer: String
    let submittedAt: String

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case surveyID = "survey_id"
        case questionIndex = "question_index"
        case question
        case answer
        case submittedAt = "submitted_at"
    }
}

private struct SupabaseAuthResponse: Decodable, Equatable, Sendable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let user: SupabaseAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    func authSession(displayNameFallback: String, needsOnboarding: Bool) -> AuthSession? {
        guard let accessToken, let refreshToken else {
            return nil
        }

        let displayName = user.userMetadata?.name
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? displayNameFallback

        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: user.id,
            email: user.email ?? "",
            displayName: displayName,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn ?? 3600)),
            needsOnboarding: needsOnboarding
        )
    }
}

private struct SupabaseAuthUser: Decodable, Equatable, Sendable {
    let id: String
    let email: String?
    let userMetadata: AuthUserMetadata?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }
}

private struct AuthSignUpRequest: Encodable, Equatable, Sendable {
    let email: String
    let password: String
    let data: AuthUserMetadata
}

private struct AuthPasswordRequest: Encodable, Equatable, Sendable {
    let email: String
    let password: String
}

private struct AuthPasswordResetRequest: Encodable, Equatable, Sendable {
    let email: String
}

private struct AuthRefreshRequest: Encodable, Equatable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct AuthUserMetadata: Codable, Equatable, Sendable {
    let name: String?
}

private protocol EmptyBackendResponse: Decodable {
    init()
}

private struct EmptyResponse: EmptyBackendResponse, Equatable, Sendable {}

struct SavePerkRequest: Encodable, Equatable, Sendable {
    let isSaved: Bool
}

struct PreferencesUpdateRequest: Encodable, Equatable, Sendable {
    let selectedInterestIDs: [String]
    let weeklyDigestEnabled: Bool
    let nearbyPerksEnabled: Bool
}

struct ProfileUpdateRequest: Encodable, Equatable, Sendable {
    let name: String
    let tier: String
    let memberCode: String
    let memberSinceYear: Int
}

private struct EmptyRequest: Encodable, Sendable {}

private extension JSONDecoder {
    static var pulsePerks: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }

    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }
}

private extension JSONEncoder {
    static var pulsePerks: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }

    static var supabase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }
}
