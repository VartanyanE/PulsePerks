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

        let (data, response) = try await session.data(for: request)

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

enum PulsePerksAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, data: Data)
    case decodingFailed(Error)

    static func == (lhs: PulsePerksAPIError, rhs: PulsePerksAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL), (.invalidResponse, .invalidResponse):
            true
        case let (.requestFailed(lhsStatus, lhsData), .requestFailed(rhsStatus, rhsData)):
            lhsStatus == rhsStatus && lhsData == rhsData
        case (.decodingFailed, .decodingFailed):
            true
        default:
            false
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
    let basePoints: Int
    let pointsPerRedemption: Int
    let nextRewardPoints: Int
    let dailySurveyGoal: Int
}

struct MemberProfileResponse: Decodable, Equatable {
    let id: String
    let name: String
    let tier: String
    let memberCode: String
    let memberSinceYear: Int
}

struct MemberActivityResponse: Codable, Equatable {
    let savedPerkIDs: [String]
    let redeemedPerkIDs: [String]
    let completedSurveyIDs: [String]
    let selectedInterestIDs: [String]
    let weeklyDigestEnabled: Bool
    let nearbyPerksEnabled: Bool
    let biometricUnlockEnabled: Bool
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
}

struct InterestResponse: Decodable, Equatable {
    let id: String
    let title: String
    let iconName: String
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
}

private extension JSONEncoder {
    static var pulsePerks: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        return encoder
    }
}
