//
//  PulsePerksStore.swift
//  RewardLoop
//

import Foundation
import SwiftUI

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

    private static let minimumRewardGoal = 1
    private static let minimumSurveyGoal = 1

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

    @MainActor
    init(response: PulsePerksBootstrapResponse) {
        memberProfile = MemberProfile(response: response.member)
        categories = response.categories
        perks = response.perks.map(Perk.init(response:))
        collections = response.collections.map(PerkCollection.init(response:))
        surveys = response.surveys.map(Survey.init(response:))
        interests = response.interests.map(Interest.init(response:))
        basePoints = response.rewards.basePoints
        pointsPerRedemption = response.rewards.pointsPerRedemption
        nextRewardPoints = response.rewards.nextRewardPoints
        dailySurveyGoal = response.rewards.dailySurveyGoal
    }

    init(
        memberProfile: MemberProfile,
        categories: [String],
        perks: [Perk],
        collections: [PerkCollection],
        surveys: [Survey],
        interests: [Interest],
        basePoints: Int,
        pointsPerRedemption: Int,
        nextRewardPoints: Int,
        dailySurveyGoal: Int
    ) {
        self.memberProfile = memberProfile
        self.categories = categories.contains("All") ? categories : ["All"] + categories
        self.perks = perks
        self.collections = collections
        self.surveys = surveys
        self.interests = interests
        self.basePoints = max(basePoints, 0)
        self.pointsPerRedemption = max(pointsPerRedemption, 0)
        self.nextRewardPoints = max(nextRewardPoints, Self.minimumRewardGoal)
        self.dailySurveyGoal = max(dailySurveyGoal, Self.minimumSurveyGoal)
    }

    func filteredPerks(category: String, searchText: String, sort: PerkSort) -> [Perk] {
        let activePerks = perks.filter { !$0.isExpired }
        let categoryMatches = category == "All"
            ? activePerks
            : activePerks.filter { $0.category == category }

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

    func rewardProgress(redeemedPerkIDs: Set<String>, completedSurveyIDs: Set<String>) -> Double {
        min(Double(memberPoints(redeemedPerkIDs: redeemedPerkIDs, completedSurveyIDs: completedSurveyIDs)) / Double(nextRewardPoints), 1)
    }

    func dailySurveyGoalProgress(completedIDs: Set<String>) -> Double {
        min(Double(surveyPoints(completedIDs: completedIDs)) / Double(dailySurveyGoal), 1)
    }

    func savedValue(redeemedPerkIDs: Set<String>) -> Int {
        redeemedPerks(for: redeemedPerkIDs).reduce(0) { total, perk in
            total + perk.estimatedSavings
        }
    }

    func recommendedPerks(excluding redeemedIDs: Set<String>) -> [Perk] {
        perks
            .filter { !redeemedIDs.contains($0.id) && !$0.isExpired }
            .sorted(using: .bestValue)
    }
}

extension MemberProfile {
    init(response: MemberProfileResponse) {
        self.init(
            id: response.id,
            name: response.name,
            tier: response.tier,
            memberCode: response.memberCode,
            memberSinceYear: response.memberSinceYear
        )
    }
}

private extension Interest {
    init(response: InterestResponse) {
        self.init(
            id: response.id,
            title: response.title,
            iconName: response.iconName
        )
    }
}

private extension Survey {
    init(response: SurveyResponse) {
        self.init(
            id: response.id,
            title: response.title,
            description: response.description,
            estimatedTime: response.estimatedTime,
            audience: response.audience,
            points: response.points,
            matchScore: response.matchScore,
            matchReason: response.matchReason,
            interestIDs: Set(response.interestIDs),
            questions: response.questions,
            iconName: response.iconName,
            tint: Color(hex: response.tintHex)
        )
    }
}

private extension PerkCollection {
    init(response: PerkCollectionResponse) {
        self.init(
            id: response.id,
            title: response.title,
            subtitle: response.subtitle,
            category: response.category,
            searchText: response.searchText,
            sort: response.sort,
            iconName: response.iconName,
            tint: Color(hex: response.tintHex)
        )
    }
}

private extension Perk {
    init(response: PerkResponse) {
        let offerURL = URL.supportedOfferURL(from: response.offerURL)

        self.init(
            id: response.id,
            title: response.title,
            description: response.description,
            partner: response.partner,
            category: response.category,
            expiration: response.expiration,
            distance: response.distance,
            distanceInMiles: response.distanceInMiles,
            daysUntilExpiration: response.daysUntilExpiration,
            shortDetail: response.shortDetail,
            redemptionInstructions: response.redemptionInstructions,
            terms: response.terms,
            estimatedSavings: response.estimatedSavings,
            memberCode: response.memberCode,
            offerURL: offerURL,
            offerKind: response.offerKind ?? (offerURL == nil ? .promoCode : .affiliate),
            iconName: response.iconName,
            tint: Color(hex: response.tintHex)
        )
    }
}

extension PartnerSurveyOffer {
    init?(response: PartnerSurveyOfferResponse) {
        guard let entryURL = URL.supportedOfferURL(from: response.entryURL) else {
            return nil
        }

        self.init(
            id: response.id,
            provider: response.provider,
            title: response.title,
            description: response.description,
            estimatedTime: response.estimatedTime,
            rewardPoints: max(response.rewardPoints, 0),
            category: response.category,
            matchScore: min(max(response.matchScore, 0), 99),
            entryURL: entryURL,
            disclosure: response.disclosure
        )
    }
}

extension PartnerSurveySession {
    init?(response: PartnerSurveySessionResponse) {
        guard let entryURL = URL.supportedOfferURL(from: response.entryURL) else {
            return nil
        }

        self.init(
            id: response.id,
            offerID: response.offerID,
            provider: response.provider,
            status: response.status,
            rewardPoints: max(response.rewardPoints, 0),
            entryURL: entryURL,
            startedAt: Self.parseDate(response.startedAt),
            completedAt: response.completedAt.flatMap(Self.parseDate)
        )
    }

    nonisolated private static func parseDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return fractionalFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private extension Color {
    init(hex: String) {
        let normalizedHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: normalizedHex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
