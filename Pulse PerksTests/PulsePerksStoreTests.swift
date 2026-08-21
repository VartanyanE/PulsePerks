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

    @Test func activityMergePreservesLocalAndRemoteProgress() {
        let remoteActivity = MemberActivityResponse(
            savedPerkIDs: ["sweetgreen-lunch-credit"],
            redeemedPerkIDs: ["hoteltonight-escape"],
            completedSurveyIDs: ["streaming-habits"],
            selectedInterestIDs: ["travel"],
            weeklyDigestEnabled: false,
            nearbyPerksEnabled: false,
            biometricUnlockEnabled: false
        )
        let localActivity = MemberActivityResponse(
            savedPerkIDs: ["classpass-trial-boost"],
            redeemedPerkIDs: ["hoteltonight-escape", "everlane-essentials"],
            completedSurveyIDs: ["fitness-goals"],
            selectedInterestIDs: ["shopping", "wellness"],
            weeklyDigestEnabled: true,
            nearbyPerksEnabled: true,
            biometricUnlockEnabled: true
        )

        let mergedActivity = remoteActivity.mergedWithLocalSnapshot(localActivity)

        #expect(mergedActivity.savedPerkIDs == ["classpass-trial-boost", "sweetgreen-lunch-credit"])
        #expect(mergedActivity.redeemedPerkIDs == ["everlane-essentials", "hoteltonight-escape"])
        #expect(mergedActivity.completedSurveyIDs == ["fitness-goals", "streaming-habits"])
        #expect(mergedActivity.selectedInterestIDs == ["shopping", "wellness"])
        #expect(mergedActivity.weeklyDigestEnabled)
        #expect(mergedActivity.nearbyPerksEnabled)
        #expect(mergedActivity.biometricUnlockEnabled)
    }

    @Test func activityMergeKeepsRemotePreferencesWhenServerIsNewer() {
        let serverUpdatedAt = Date()
        let localModifiedAt = serverUpdatedAt.addingTimeInterval(-60)
        let remoteActivity = MemberActivityResponse(
            savedPerkIDs: ["sweetgreen-lunch-credit"],
            redeemedPerkIDs: [],
            completedSurveyIDs: [],
            selectedInterestIDs: ["travel"],
            weeklyDigestEnabled: false,
            nearbyPerksEnabled: false,
            biometricUnlockEnabled: false,
            serverUpdatedAt: serverUpdatedAt
        )
        let localActivity = MemberActivityResponse(
            savedPerkIDs: ["classpass-trial-boost"],
            redeemedPerkIDs: ["everlane-essentials"],
            completedSurveyIDs: ["fitness-goals"],
            selectedInterestIDs: ["shopping", "wellness"],
            weeklyDigestEnabled: true,
            nearbyPerksEnabled: true,
            biometricUnlockEnabled: true
        )

        let mergedActivity = remoteActivity.mergedWithLocalSnapshot(
            localActivity,
            localModifiedAt: localModifiedAt
        )

        #expect(mergedActivity.savedPerkIDs == ["classpass-trial-boost", "sweetgreen-lunch-credit"])
        #expect(mergedActivity.redeemedPerkIDs == ["everlane-essentials"])
        #expect(mergedActivity.completedSurveyIDs == ["fitness-goals"])
        #expect(mergedActivity.selectedInterestIDs == ["travel"])
        #expect(!mergedActivity.weeklyDigestEnabled)
        #expect(!mergedActivity.nearbyPerksEnabled)
        #expect(!mergedActivity.biometricUnlockEnabled)
    }
}
