//
//  RewardLoopStoreTests.swift
//  RewardLoopTests
//

import Foundation
import Testing
@testable import RewardLoop

struct RewardLoopStoreTests {
    private let store = RewardLoopStore.demo

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
        let unsafeStore = RewardLoopStore(
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
        let progressStore = RewardLoopStore(
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
        let testStore = RewardLoopStore(
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
        let testStore = RewardLoopStore(
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

    @Test func supabaseConfigurationRejectsPlaceholderSecrets() {
        #expect(!SupabaseConfiguration.isConfiguredSecret("", placeholder: "YOUR_SUPABASE_URL"))
        #expect(!SupabaseConfiguration.isConfiguredSecret("YOUR_SUPABASE_URL", placeholder: "YOUR_SUPABASE_URL"))
        #expect(!SupabaseConfiguration.isConfiguredSecret("$(SUPABASE_URL)", placeholder: "YOUR_SUPABASE_URL"))
        #expect(!SupabaseConfiguration.isConfiguredSecret("YOUR_SUPABASE_ANON_KEY", placeholder: "YOUR_SUPABASE_ANON_KEY"))
        #expect(SupabaseConfiguration.isConfiguredSecret("https://example.supabase.co", placeholder: "YOUR_SUPABASE_URL"))
    }

    @Test func apiErrorIdentifiesAuthenticationFailures() {
        let unauthorizedError = RewardLoopAPIError.requestFailed(statusCode: 401, data: Data())
        let forbiddenError = RewardLoopAPIError.requestFailed(statusCode: 403, data: Data())
        let rateLimitError = RewardLoopAPIError.requestFailed(statusCode: 429, data: Data())

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
        let timeoutError = RewardLoopAPIError.requestFailed(statusCode: 408, data: Data())
        let serverError = RewardLoopAPIError.requestFailed(statusCode: 503, data: Data())
        let authError = RewardLoopAPIError.requestFailed(statusCode: 401, data: Data())
        let decodingError = RewardLoopAPIError.emptyResponse

        #expect(timeoutError.isTransientFailure)
        #expect(serverError.isTransientFailure)
        #expect(!authError.isTransientFailure)
        #expect(!decodingError.isTransientFailure)
    }

    @Test func apiErrorDescribesUnexpectedEmptyResponses() {
        #expect(RewardLoopAPIError.emptyResponse.localizedDescription == "Backend returned an empty response")
    }

    @Test func apiErrorSanitizesLongBackendMessages() {
        let noisyMessage = String(repeating: "Backend failed with details\n", count: 20)
        let error = RewardLoopAPIError.requestFailed(statusCode: 500, data: Data(noisyMessage.utf8))
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

    @Test func partnerSurveyOfferMapsSupportedProviderSurvey() throws {
        let response = testPartnerSurveyResponse(
            rewardPoints: 120,
            matchScore: 140,
            entryURL: "https://spectrumsurveys.com/startSurvey?survey_id=123"
        )

        let offer = try #require(PartnerSurveyOffer(response: response))

        #expect(offer.provider == .pureSpectrum)
        #expect(offer.rewardPoints == 120)
        #expect(offer.matchScore == 99)
        #expect(offer.entryURL.host() == "spectrumsurveys.com")
    }

    @Test func partnerSurveyOfferRejectsUnsupportedEntryURLAndClampsPoints() {
        let invalidURLResponse = testPartnerSurveyResponse(
            rewardPoints: -50,
            matchScore: -10,
            entryURL: "pulseperks://survey/123"
        )
        let validURLResponse = testPartnerSurveyResponse(
            rewardPoints: -50,
            matchScore: -10,
            entryURL: "https://spectrumsurveys.com/startSurvey?survey_id=123"
        )
        let offer = PartnerSurveyOffer(response: validURLResponse)

        #expect(PartnerSurveyOffer(response: invalidURLResponse) == nil)
        #expect(offer?.rewardPoints == 0)
        #expect(offer?.matchScore == 0)
    }

    @Test func partnerSurveySessionMapsCompletedSessionAndRejectsUnsupportedEntryURL() throws {
        let completedResponse = testPartnerSurveySessionResponse(
            status: .completed,
            rewardPoints: 180,
            entryURL: "https://spectrumsurveys.com/startSurvey?survey_id=123",
            completedAt: "2026-08-24T19:10:00Z"
        )
        let invalidURLResponse = testPartnerSurveySessionResponse(
            status: .completed,
            rewardPoints: 180,
            entryURL: "rewardloop://partner-surveys/complete",
            completedAt: "2026-08-24T19:10:00Z"
        )

        let session = try #require(PartnerSurveySession(response: completedResponse))

        #expect(session.status == .completed)
        #expect(session.awardsPoints)
        #expect(session.rewardPoints == 180)
        #expect(session.completedAt != nil)
        #expect(PartnerSurveySession(response: invalidURLResponse) == nil)
    }

    @Test func partnerSurveySessionDoesNotAwardPointsUntilComplete() throws {
        let response = testPartnerSurveySessionResponse(
            status: .started,
            rewardPoints: 180,
            entryURL: "https://spectrumsurveys.com/startSurvey?survey_id=123",
            completedAt: nil
        )

        let session = try #require(PartnerSurveySession(response: response))

        #expect(!session.awardsPoints)
    }

    @Test func surveyCompletionRequestIncludesSubmittedAnswers() throws {
        let request = SurveyCompletionRequest(
            responses: [
                SurveyAnswerRequest(
                    questionIndex: 1,
                    question: "Which rewards matter most?",
                    answer: "Food and travel"
                )
            ]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let responses = try #require(object["responses"] as? [[String: Any]])
        let firstResponse = try #require(responses.first)

        #expect(responses.count == 1)
        #expect(firstResponse["questionIndex"] as? Int == 1)
        #expect(firstResponse["question"] as? String == "Which rewards matter most?")
        #expect(firstResponse["answer"] as? String == "Food and travel")
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

    private func testPartnerSurveyResponse(
        rewardPoints: Int,
        matchScore: Int,
        entryURL: String
    ) -> PartnerSurveyOfferResponse {
        PartnerSurveyOfferResponse(
            id: "pure-spectrum-123",
            provider: .pureSpectrum,
            providerSurveyID: "123",
            title: "Partner survey",
            description: "Answer a partner survey.",
            estimatedTime: "8 min",
            rewardPoints: rewardPoints,
            category: "Shopping",
            matchScore: matchScore,
            entryURL: entryURL,
            disclosure: "Points are awarded after completion."
        )
    }

    private func testPartnerSurveySessionResponse(
        status: PartnerSurveySessionStatus,
        rewardPoints: Int,
        entryURL: String,
        completedAt: String?
    ) -> PartnerSurveySessionResponse {
        PartnerSurveySessionResponse(
            id: "session-123",
            offerID: "pure-spectrum-123",
            provider: .pureSpectrum,
            status: status,
            rewardPoints: rewardPoints,
            entryURL: entryURL,
            startedAt: "2026-08-24T19:00:00Z",
            completedAt: completedAt
        )
    }
}
