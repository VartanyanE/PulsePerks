//
//  PulsePerksStore.swift
//  Pulse Perks
//

import Foundation

struct PulsePerksStore {
    let memberProfile: MemberProfile
    let categories: [String]
    let perks: [Perk]
    let collections: [PerkCollection]
    let surveys: [Survey]
    let interests: [Interest]
    let basePoints: Int
    let pointsPerRedemption: Int
    let nextRewardPoints: Int
    let dailySurveyGoal: Int

    static let demo = PulsePerksStore(
        memberProfile: .demo,
        categories: ["All", "Food", "Fitness", "Travel", "Retail"],
        perks: Perk.sampleData,
        collections: PerkCollection.sampleData,
        surveys: Survey.sampleData,
        interests: Interest.sampleData,
        basePoints: 2450,
        pointsPerRedemption: 75,
        nextRewardPoints: 3000,
        dailySurveyGoal: 300
    )

    func filteredPerks(category: String, searchText: String, sort: PerkSort) -> [Perk] {
        let categoryMatches = category == "All"
            ? perks
            : perks.filter { $0.category == category }

        let searchMatches: [Perk]

        if searchText.isEmpty {
            searchMatches = categoryMatches
        } else {
            searchMatches = categoryMatches.filter { perk in
                perk.title.localizedStandardContains(searchText)
                    || perk.description.localizedStandardContains(searchText)
                    || perk.partner.localizedStandardContains(searchText)
            }
        }

        return searchMatches.sorted(using: sort)
    }

    func redeemedPerks(for ids: Set<String>) -> [Perk] {
        perks.filter { ids.contains($0.id) }
    }

    func savedPerks(for ids: Set<String>) -> [Perk] {
        perks.filter { ids.contains($0.id) }
    }

    func availableSurveys(completedIDs: Set<String>) -> [Survey] {
        surveys.filter { !completedIDs.contains($0.id) }
    }

    func completedSurveys(completedIDs: Set<String>) -> [Survey] {
        surveys.filter { completedIDs.contains($0.id) }
    }

    func surveyPoints(completedIDs: Set<String>) -> Int {
        completedSurveys(completedIDs: completedIDs).reduce(0) { total, survey in
            total + survey.points
        }
    }

    func memberPoints(redeemedPerkIDs: Set<String>, completedSurveyIDs: Set<String>) -> Int {
        basePoints
            + (redeemedPerks(for: redeemedPerkIDs).count * pointsPerRedemption)
            + surveyPoints(completedIDs: completedSurveyIDs)
    }

    func pointsUntilNextReward(redeemedPerkIDs: Set<String>, completedSurveyIDs: Set<String>) -> Int {
        max(nextRewardPoints - memberPoints(redeemedPerkIDs: redeemedPerkIDs, completedSurveyIDs: completedSurveyIDs), 0)
    }

    func savedValue(redeemedPerkIDs: Set<String>) -> Int {
        redeemedPerks(for: redeemedPerkIDs).reduce(0) { total, perk in
            total + perk.estimatedSavings
        }
    }

    func recommendedPerks(excluding redeemedIDs: Set<String>) -> [Perk] {
        perks
            .filter { !redeemedIDs.contains($0.id) }
            .sorted(using: .bestValue)
    }
}
