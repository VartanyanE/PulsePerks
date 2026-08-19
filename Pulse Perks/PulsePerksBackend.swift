//
//  PulsePerksBackend.swift
//  Pulse Perks
//

import Foundation

protocol PulsePerksBackend {
    func fetchBootstrap() async throws -> PulsePerksBootstrapResponse
    func savePerk(id: String, isSaved: Bool) async throws -> MemberActivityResponse
    func redeemPerk(id: String) async throws -> MemberActivityResponse
    func completeSurvey(id: String) async throws -> MemberActivityResponse
    func updatePreferences(_ request: PreferencesUpdateRequest) async throws -> MemberActivityResponse
}

struct SupabasePulsePerksClient: PulsePerksBackend {
    var configuration: SupabaseConfiguration
    var session: URLSession = .shared

    func fetchBootstrap() async throws -> PulsePerksBootstrapResponse {
        async let memberProfile: MemberProfileResponse = fetchSingle(
            table: "member_profiles",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(configuration.memberID)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        async let rewards: RewardsConfigurationResponse = fetchSingle(
            table: "app_config",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.default"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        async let perks: [PerkResponse] = fetchTable(
            "perks",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        async let collections: [PerkCollectionResponse] = fetchTable(
            "perk_collections",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        async let surveys: [SurveyResponse] = fetchTable(
            "surveys",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        async let interests: [InterestResponse] = fetchTable(
            "interests",
            queryItems: [
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "display_order.asc")
            ]
        )
        async let activity = fetchActivity()

        let rewardsResponse = try await rewards

        return try await PulsePerksBootstrapResponse(
            member: memberProfile,
            rewards: rewardsResponse,
            categories: rewardsResponse.categories,
            perks: perks,
            collections: collections,
            surveys: surveys,
            interests: interests,
            activity: activity
        )
    }

    func savePerk(id: String, isSaved: Bool) async throws -> MemberActivityResponse {
        var activity = try await fetchActivity()

        if isSaved {
            activity.savedPerkIDs = Array(Set(activity.savedPerkIDs).union([id])).sorted()
        } else {
            activity.savedPerkIDs = activity.savedPerkIDs.filter { $0 != id }
        }

        return try await updateActivity(activity)
    }

    func redeemPerk(id: String) async throws -> MemberActivityResponse {
        var activity = try await fetchActivity()
        activity.redeemedPerkIDs = Array(Set(activity.redeemedPerkIDs).union([id])).sorted()
        return try await updateActivity(activity)
    }

    func completeSurvey(id: String) async throws -> MemberActivityResponse {
        var activity = try await fetchActivity()
        activity.completedSurveyIDs = Array(Set(activity.completedSurveyIDs).union([id])).sorted()
        return try await updateActivity(activity)
    }

    func updatePreferences(_ request: PreferencesUpdateRequest) async throws -> MemberActivityResponse {
        var activity = try await fetchActivity()
        activity.selectedInterestIDs = request.selectedInterestIDs
        activity.weeklyDigestEnabled = request.weeklyDigestEnabled
        activity.nearbyPerksEnabled = request.nearbyPerksEnabled
        activity.biometricUnlockEnabled = request.biometricUnlockEnabled
        return try await updateActivity(activity)
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
            throw PulsePerksAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.anonKey)", forHTTPHeaderField: "Authorization")
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
            throw PulsePerksAPIError.networkFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PulsePerksAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw PulsePerksAPIError.requestFailed(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try JSONDecoder.supabase.decode(Response.self, from: data)
        } catch {
            throw PulsePerksAPIError.decodingFailed(error)
        }
    }
}

struct PulsePerksAPIClient: PulsePerksBackend {
    var configuration: BackendConfiguration
    var session: URLSession = .shared

    func fetchBootstrap() async throws -> PulsePerksBootstrapResponse {
        try await send(path: "/v1/bootstrap", method: "GET")
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

    func completeSurvey(id: String) async throws -> MemberActivityResponse {
        try await send(path: "/v1/me/surveys/\(id)/completion", method: "POST")
    }

    func updatePreferences(_ request: PreferencesUpdateRequest) async throws -> MemberActivityResponse {
        try await send(path: "/v1/me/preferences", method: "PUT", body: request)
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
            throw PulsePerksAPIError.invalidURL
        }

        var request = URLRequest(url: url)
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
            throw PulsePerksAPIError.networkFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PulsePerksAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw PulsePerksAPIError.requestFailed(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            return try JSONDecoder.pulsePerks.decode(Response.self, from: data)
        } catch {
            throw PulsePerksAPIError.decodingFailed(error)
        }
    }
}

struct BackendConfiguration: Equatable {
    var baseURL: URL
    var bearerToken: String?

    static let development = BackendConfiguration(
        baseURL: URL(string: "https://api.example.com")!,
        bearerToken: nil
    )
}

struct SupabaseConfiguration: Equatable {
    var projectURL: URL
    var anonKey: String
    var memberID: String

    static var current: SupabaseConfiguration? {
        guard let urlValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !urlValue.isEmpty,
              !anonKey.isEmpty,
              !urlValue.contains("YOUR_SUPABASE_URL"),
              !anonKey.contains("YOUR_SUPABASE_ANON_KEY"),
              let url = URL(string: urlValue) else {
            return nil
        }

        let memberID = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_MEMBER_ID") as? String)
            .flatMap { $0.isEmpty ? nil : $0 } ?? MemberProfile.demo.id

        return SupabaseConfiguration(projectURL: url, anonKey: anonKey, memberID: memberID)
    }

    static var bundled: SupabaseConfiguration? {
        if let infoPlistConfiguration = current {
            return infoPlistConfiguration
        }

        guard !SupabaseSecrets.projectURL.isEmpty,
              !SupabaseSecrets.anonKey.isEmpty,
              !SupabaseSecrets.projectURL.contains("YOUR_SUPABASE_URL"),
              !SupabaseSecrets.anonKey.contains("YOUR_SUPABASE_ANON_KEY"),
              let url = URL(string: SupabaseSecrets.projectURL) else {
            return nil
        }

        return SupabaseConfiguration(
            projectURL: url,
            anonKey: SupabaseSecrets.anonKey,
            memberID: SupabaseSecrets.memberID.isEmpty ? MemberProfile.demo.id : SupabaseSecrets.memberID
        )
    }
}

enum PulsePerksAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case networkFailed(Error)

    static func == (lhs: PulsePerksAPIError, rhs: PulsePerksAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL), (.invalidResponse, .invalidResponse):
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

extension PulsePerksAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid backend URL"
        case .invalidResponse:
            "Backend returned an invalid response"
        case let .requestFailed(statusCode, data):
            if let message = String(data: data, encoding: .utf8), !message.isEmpty {
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

struct PulsePerksBootstrapResponse: Decodable, Equatable {
    let member: MemberProfileResponse
    let rewards: RewardsConfigurationResponse
    let categories: [String]
    let perks: [PerkResponse]
    let collections: [PerkCollectionResponse]
    let surveys: [SurveyResponse]
    let interests: [InterestResponse]
    let activity: MemberActivityResponse
}

struct RewardsConfigurationResponse: Decodable, Equatable {
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

struct MemberProfileResponse: Decodable, Equatable {
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

struct MemberActivityResponse: Codable, Equatable {
    var savedPerkIDs: [String]
    var redeemedPerkIDs: [String]
    var completedSurveyIDs: [String]
    var selectedInterestIDs: [String]
    var weeklyDigestEnabled: Bool
    var nearbyPerksEnabled: Bool
    var biometricUnlockEnabled: Bool

    static let defaultActivity = MemberActivityResponse(
        savedPerkIDs: [],
        redeemedPerkIDs: [],
        completedSurveyIDs: [],
        selectedInterestIDs: ["shopping", "wellness"],
        weeklyDigestEnabled: true,
        nearbyPerksEnabled: true,
        biometricUnlockEnabled: false
    )

    enum CodingKeys: String, CodingKey {
        case savedPerkIDs = "savedPerkIDs"
        case redeemedPerkIDs = "redeemedPerkIDs"
        case completedSurveyIDs = "completedSurveyIDs"
        case selectedInterestIDs = "selectedInterestIDs"
        case weeklyDigestEnabled
        case nearbyPerksEnabled
        case biometricUnlockEnabled
    }
}

struct PerkResponse: Decodable, Equatable {
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
        case iconName = "icon_name"
        case tintHex = "tint_hex"
    }
}

struct PerkCollectionResponse: Decodable, Equatable {
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

struct SurveyResponse: Decodable, Equatable {
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

struct InterestResponse: Decodable, Equatable {
    let id: String
    let title: String
    let iconName: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case iconName = "icon_name"
    }
}

private struct MemberActivityRow: Codable, Equatable {
    let memberID: String
    let savedPerkIDs: [String]
    let redeemedPerkIDs: [String]
    let completedSurveyIDs: [String]
    let selectedInterestIDs: [String]
    let weeklyDigestEnabled: Bool
    let nearbyPerksEnabled: Bool
    let biometricUnlockEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case memberID = "member_id"
        case savedPerkIDs = "saved_perk_ids"
        case redeemedPerkIDs = "redeemed_perk_ids"
        case completedSurveyIDs = "completed_survey_ids"
        case selectedInterestIDs = "selected_interest_ids"
        case weeklyDigestEnabled = "weekly_digest_enabled"
        case nearbyPerksEnabled = "nearby_perks_enabled"
        case biometricUnlockEnabled = "biometric_unlock_enabled"
    }

    init(memberID: String, activity: MemberActivityResponse) {
        self.memberID = memberID
        savedPerkIDs = activity.savedPerkIDs
        redeemedPerkIDs = activity.redeemedPerkIDs
        completedSurveyIDs = activity.completedSurveyIDs
        selectedInterestIDs = activity.selectedInterestIDs
        weeklyDigestEnabled = activity.weeklyDigestEnabled
        nearbyPerksEnabled = activity.nearbyPerksEnabled
        biometricUnlockEnabled = activity.biometricUnlockEnabled
    }

    var response: MemberActivityResponse {
        MemberActivityResponse(
            savedPerkIDs: savedPerkIDs,
            redeemedPerkIDs: redeemedPerkIDs,
            completedSurveyIDs: completedSurveyIDs,
            selectedInterestIDs: selectedInterestIDs,
            weeklyDigestEnabled: weeklyDigestEnabled,
            nearbyPerksEnabled: nearbyPerksEnabled,
            biometricUnlockEnabled: biometricUnlockEnabled
        )
    }
}

struct SavePerkRequest: Encodable, Equatable {
    let isSaved: Bool
}

struct PreferencesUpdateRequest: Encodable, Equatable {
    let selectedInterestIDs: [String]
    let weeklyDigestEnabled: Bool
    let nearbyPerksEnabled: Bool
    let biometricUnlockEnabled: Bool
}

private struct EmptyRequest: Encodable {}

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
