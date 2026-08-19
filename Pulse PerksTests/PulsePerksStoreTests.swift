//
//  PulsePerksStoreTests.swift
//  Pulse PerksTests
//

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
}
