//
//  PulsePerksStoreTests.swift
//  Pulse PerksTests
//

import Foundation
import Testing
@testable import Pulse_Perks

struct PulsePerksStoreTests {
    private let store = PulsePerksStore.demo

    @Test func filtersPerksByCategoryAndSearchText() {
        let results = store.filteredPerks(category: "Travel", searchText: "hotel", sort: .bestValue)

        #expect(results.map(\.id) == ["hoteltonight-escape"])
    }

    @Test func sortsPerksByNearestDistance() {
        let results = store.filteredPerks(category: "All", searchText: "", sort: .nearest)

        #expect(results.first?.id == "sweetgreen-lunch-credit")
        #expect(results.last?.id == "everlane-essentials")
    }

    @Test func calculatesSurveyPointsFromCompletedIDs() {
        let points = store.surveyPoints(completedIDs: ["grocery-routine", "fitness-goals"])

        #expect(points == 230)
    }

    @Test func calculatesMemberPointsFromRedemptionsAndSurveys() {
        let points = store.memberPoints(
            redeemedPerkIDs: ["sweetgreen-lunch-credit", "hoteltonight-escape"],
            completedSurveyIDs: ["streaming-habits"]
        )

        #expect(points == 2720)
    }

    @Test func capsPointsUntilNextRewardAtZero() {
        let pointsUntilNextReward = store.pointsUntilNextReward(
            redeemedPerkIDs: [
                "sweetgreen-lunch-credit",
                "classpass-trial-boost",
                "hoteltonight-escape",
                "everlane-essentials"
            ],
            completedSurveyIDs: ["streaming-habits", "grocery-routine", "fitness-goals"]
        )

        #expect(pointsUntilNextReward == 0)
    }

    @Test func recommendsUnredeemedPerksByValue() {
        let results = store.recommendedPerks(excluding: ["hoteltonight-escape"])

        #expect(results.map(\.id) == [
            "classpass-trial-boost",
            "everlane-essentials",
            "sweetgreen-lunch-credit"
        ])
    }

    @Test func authSessionRefreshesWhenTokenIsNearExpiration() {
        let session = AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            userID: "member-1",
            email: "member@example.com",
            displayName: "Member",
            expiresAt: Date().addingTimeInterval(240),
            needsOnboarding: false
        )

        #expect(session.shouldRefresh)
    }

    @Test func authSessionDoesNotRefreshWhenTokenHasEnoughTimeRemaining() {
        let session = AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            userID: "member-1",
            email: "member@example.com",
            displayName: "Member",
            expiresAt: Date().addingTimeInterval(900),
            needsOnboarding: false
        )

        #expect(!session.shouldRefresh)
    }

    @Test func supabaseConfigurationUsesAuthenticatedSessionForMemberRequests() {
        let configuration = SupabaseConfiguration(
            projectURL: URL(string: "https://example.supabase.co")!,
            anonKey: "anon-key",
            memberID: "demo-member",
            accessToken: nil,
            memberName: "Demo"
        )
        let session = AuthSession(
            accessToken: "session-token",
            refreshToken: "refresh-token",
            userID: "member-1",
            email: "member@example.com",
            displayName: "Member",
            expiresAt: Date().addingTimeInterval(900),
            needsOnboarding: false
        )

        let authenticatedConfiguration = configuration.authenticated(with: session)

        #expect(authenticatedConfiguration.memberID == "member-1")
        #expect(authenticatedConfiguration.memberName == "Member")
        #expect(authenticatedConfiguration.authorizationToken == "session-token")
    }

    @Test func apiErrorIdentifiesAuthenticationFailures() {
        let unauthorizedError = PulsePerksAPIError.requestFailed(statusCode: 401, data: Data())
        let forbiddenError = PulsePerksAPIError.requestFailed(statusCode: 403, data: Data())
        let rateLimitError = PulsePerksAPIError.requestFailed(statusCode: 429, data: Data())

        #expect(unauthorizedError.isAuthenticationFailure)
        #expect(forbiddenError.isAuthenticationFailure)
        #expect(!rateLimitError.isAuthenticationFailure)
    }
}
