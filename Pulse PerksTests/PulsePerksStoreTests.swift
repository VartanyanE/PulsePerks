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

    @Test func normalizesUnsafeRewardsConfiguration() {
        let unsafeStore = PulsePerksStore(
            memberProfile: .demo,
            categories: ["Food"],
            perks: [],
            collections: [],
            surveys: [],
            interests: [],
            basePoints: -100,
            pointsPerRedemption: -25,
            nextRewardPoints: 0,
            dailySurveyGoal: 0
        )

        #expect(unsafeStore.categories == ["All", "Food"])
        #expect(unsafeStore.basePoints == 0)
        #expect(unsafeStore.pointsPerRedemption == 0)
        #expect(unsafeStore.nextRewardPoints == 1)
        #expect(unsafeStore.dailySurveyGoal == 1)
    }

    @Test func progressValuesStayInSafeRange() {
        let progressStore = PulsePerksStore(
            memberProfile: .demo,
            categories: ["All"],
            perks: [],
            collections: [],
            surveys: Survey.sampleData,
            interests: [],
            basePoints: 5000,
            pointsPerRedemption: 0,
            nextRewardPoints: 3000,
            dailySurveyGoal: 100
        )

        #expect(progressStore.rewardProgress(redeemedPerkIDs: [], completedSurveyIDs: []) == 1)
        #expect(progressStore.dailySurveyGoalProgress(completedIDs: ["fitness-goals"]) == 1)
    }

    @Test func recommendsUnredeemedPerksByValue() {
        let results = store.recommendedPerks(excluding: ["hoteltonight-escape"])

        #expect(results.map(\.id) == [
            "classpass-trial-boost",
            "everlane-essentials",
            "sweetgreen-lunch-credit"
        ])
    }

    @Test func expiredPerksAreExcludedFromDiscoveryResults() {
        let activePerk = testPerk(id: "active-offer", title: "Active offer", daysUntilExpiration: 3)
        let expiredPerk = testPerk(id: "expired-offer", title: "Expired offer", daysUntilExpiration: 0)
        let testStore = PulsePerksStore(
            memberProfile: .demo,
            categories: ["All", "Retail"],
            perks: [expiredPerk, activePerk],
            collections: [],
            surveys: [],
            interests: [],
            basePoints: 0,
            pointsPerRedemption: 0,
            nextRewardPoints: 1,
            dailySurveyGoal: 1
        )

        let results = testStore.filteredPerks(category: "All", searchText: "", sort: .endingSoon)

        #expect(results.map(\.id) == ["active-offer"])
        #expect(expiredPerk.isExpired)
        #expect(!activePerk.isExpired)
    }

    @Test func expiredPerksAreExcludedFromRecommendations() {
        let highValueExpiredPerk = testPerk(
            id: "expired-high-value",
            title: "Expired high value",
            daysUntilExpiration: -1,
            estimatedSavings: 100
        )
        let activePerk = testPerk(
            id: "active-lower-value",
            title: "Active lower value",
            daysUntilExpiration: 2,
            estimatedSavings: 25
        )
        let testStore = PulsePerksStore(
            memberProfile: .demo,
            categories: ["All", "Retail"],
            perks: [highValueExpiredPerk, activePerk],
            collections: [],
            surveys: [],
            interests: [],
            basePoints: 0,
            pointsPerRedemption: 0,
            nextRewardPoints: 1,
            dailySurveyGoal: 1
        )

        let results = testStore.recommendedPerks(excluding: [])

        #expect(results.map(\.id) == ["active-lower-value"])
    }

    @Test func offerURLValidatorAllowsWebURLsWithHosts() {
        let secureURL = URL.supportedOfferURL(from: "https://partners.example.com/offers/pulse")
        let standardWebURL = URL.supportedOfferURL(from: "http://partners.example.com/offers/pulse")

        #expect(secureURL?.scheme == "https")
        #expect(secureURL?.host() == "partners.example.com")
        #expect(standardWebURL?.scheme == "http")
    }

    @Test func offerURLValidatorRejectsUnsupportedURLs() {
        #expect(URL.supportedOfferURL(from: nil) == nil)
        #expect(URL.supportedOfferURL(from: "not a url") == nil)
        #expect(URL.supportedOfferURL(from: "pulseperks://offer/sweetgreen") == nil)
        #expect(URL.supportedOfferURL(from: "mailto:partner@example.com") == nil)
        #expect(URL.supportedOfferURL(from: "https:///missing-host") == nil)
    }

    @Test func offerKindsDescribeMonetizationClearly() {
        #expect(OfferKind.affiliate.title == "Affiliate offer")
        #expect(OfferKind.affiliate.disclosure.contains("earn a commission"))
        #expect(OfferKind.sponsored.title == "Sponsored offer")
        #expect(OfferKind.promoCode.title == "Promo code")
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
            nearbyPerksEnabled: false
        )
        let localActivity = MemberActivityResponse(
            savedPerkIDs: ["classpass-trial-boost"],
            redeemedPerkIDs: ["hoteltonight-escape", "everlane-essentials"],
            completedSurveyIDs: ["fitness-goals"],
            selectedInterestIDs: ["shopping", "wellness"],
            weeklyDigestEnabled: true,
            nearbyPerksEnabled: true
        )

        let mergedActivity = remoteActivity.mergedWithLocalSnapshot(localActivity)

        #expect(mergedActivity.savedPerkIDs == ["classpass-trial-boost", "sweetgreen-lunch-credit"])
        #expect(mergedActivity.redeemedPerkIDs == ["everlane-essentials", "hoteltonight-escape"])
        #expect(mergedActivity.completedSurveyIDs == ["fitness-goals", "streaming-habits"])
        #expect(mergedActivity.selectedInterestIDs == ["shopping", "wellness"])
        #expect(mergedActivity.weeklyDigestEnabled)
        #expect(mergedActivity.nearbyPerksEnabled)
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
            serverUpdatedAt: serverUpdatedAt
        )
        let localActivity = MemberActivityResponse(
            savedPerkIDs: ["classpass-trial-boost"],
            redeemedPerkIDs: ["everlane-essentials"],
            completedSurveyIDs: ["fitness-goals"],
            selectedInterestIDs: ["shopping", "wellness"],
            weeklyDigestEnabled: true,
            nearbyPerksEnabled: true
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
    }

    @Test func apiErrorIdentifiesTransientFailures() {
        let timeoutError = PulsePerksAPIError.requestFailed(statusCode: 408, data: Data())
        let serverError = PulsePerksAPIError.requestFailed(statusCode: 503, data: Data())
        let authError = PulsePerksAPIError.requestFailed(statusCode: 401, data: Data())
        let decodingError = PulsePerksAPIError.emptyResponse

        #expect(timeoutError.isTransientFailure)
        #expect(serverError.isTransientFailure)
        #expect(!authError.isTransientFailure)
        #expect(!decodingError.isTransientFailure)
    }

    @Test func apiErrorDescribesUnexpectedEmptyResponses() {
        #expect(PulsePerksAPIError.emptyResponse.localizedDescription == "Backend returned an empty response")
    }

    @Test func apiErrorSanitizesLongBackendMessages() {
        let noisyMessage = String(repeating: "Backend failed with details\n", count: 20)
        let error = PulsePerksAPIError.requestFailed(statusCode: 500, data: Data(noisyMessage.utf8))
        let description = error.localizedDescription

        #expect(!description.contains("\n"))
        #expect(description.hasSuffix("..."))
        #expect(description.count < noisyMessage.count)
    }

    @Test func userLocalDataStoreClearsUserScopedCaches() {
        let userID = "test-member-cache"
        let defaults = UserDefaults.standard

        defaults.set(Data("activity".utf8), forKey: "userActivity.\(userID)")
        defaults.set(Data("bootstrap".utf8), forKey: "userBootstrap.\(userID)")

        UserLocalDataStore.clearAll(userID: userID)

        #expect(defaults.data(forKey: "userActivity.\(userID)") == nil)
        #expect(defaults.data(forKey: "userBootstrap.\(userID)") == nil)
    }

    private func testPerk(
        id: String,
        title: String,
        daysUntilExpiration: Int,
        estimatedSavings: Int = 10
    ) -> Perk {
        Perk(
            id: id,
            title: title,
            description: "Test perk",
            partner: "Test Partner",
            category: "Retail",
            expiration: daysUntilExpiration <= 0 ? "Expired" : "\(daysUntilExpiration) days left",
            distance: "Online",
            distanceInMiles: 99,
            daysUntilExpiration: daysUntilExpiration,
            shortDetail: "Test offer",
            redemptionInstructions: "Use this code at checkout.",
            terms: "Test terms.",
            estimatedSavings: estimatedSavings,
            memberCode: "TEST-CODE",
            offerURL: URL(string: "https://example.com"),
            offerKind: .affiliate,
            iconName: "tag",
            tint: .green
        )
    }
}
