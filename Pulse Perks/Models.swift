//
//  Models.swift
//  Pulse Perks
//

import SwiftUI

struct PulseNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let iconName: String
    let actionTitle: String
    let destination: NotificationDestination
}

struct OfferClickHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let perkID: String
    let perkTitle: String
    let partner: String
    let offerKind: OfferKind
    let clickedAt: Date

    init(
        id: UUID = UUID(),
        perkID: String,
        perkTitle: String,
        partner: String,
        offerKind: OfferKind,
        clickedAt: Date = Date()
    ) {
        self.id = id
        self.perkID = perkID
        self.perkTitle = perkTitle
        self.partner = partner
        self.offerKind = offerKind
        self.clickedAt = clickedAt
    }
}

enum NotificationDestination {
    case surveys
    case wallet
    case account
}

enum UserLocalDataStore {
    static func clearAll(userID: String) {
        UserDefaults.standard.removeObject(forKey: "userActivity.\(userID)")
        UserDefaults.standard.removeObject(forKey: "userBootstrap.\(userID)")
    }
}

struct MemberProfile: Identifiable {
    let id: String
    let name: String
    let tier: String
    let memberCode: String
    let memberSinceYear: Int

    static let demo = MemberProfile(
        id: "demo-member",
        name: "Emanuil",
        tier: "Pulse Plus",
        memberCode: "PULSE-2450",
        memberSinceYear: 2026
    )
}

struct Interest: Identifiable {
    let id: String
    let title: String
    let iconName: String

    static let sampleData: [Interest] = [
        Interest(id: "entertainment", title: "Entertainment", iconName: "play.tv"),
        Interest(id: "shopping", title: "Shopping", iconName: "cart"),
        Interest(id: "wellness", title: "Wellness", iconName: "heart"),
        Interest(id: "travel", title: "Travel", iconName: "airplane.departure")
    ]
}

enum PerkSort: String, CaseIterable, Codable, Identifiable {
    case bestValue
    case nearest
    case endingSoon

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .bestValue:
            "Value"
        case .nearest:
            "Nearby"
        case .endingSoon:
            "Expiring"
        }
    }

    var sectionTitle: String {
        switch self {
        case .bestValue:
            "Best value"
        case .nearest:
            "Nearest perks"
        case .endingSoon:
            "Ending soon"
        }
    }

    var iconName: String {
        switch self {
        case .bestValue:
            "dollarsign.circle"
        case .nearest:
            "location"
        case .endingSoon:
            "clock"
        }
    }

    func compare(_ lhs: Perk, _ rhs: Perk) -> Bool {
        switch self {
        case .bestValue:
            lhs.estimatedSavings > rhs.estimatedSavings
        case .nearest:
            lhs.distanceInMiles < rhs.distanceInMiles
        case .endingSoon:
            lhs.daysUntilExpiration < rhs.daysUntilExpiration
        }
    }
}

enum OfferKind: String, Codable, Equatable {
    case affiliate
    case sponsored
    case promoCode
    case direct

    var title: String {
        switch self {
        case .affiliate:
            "Affiliate offer"
        case .sponsored:
            "Sponsored offer"
        case .promoCode:
            "Promo code"
        case .direct:
            "Partner link"
        }
    }

    var disclosure: String {
        switch self {
        case .affiliate:
            "Opens a partner site. Pulse Perks may earn a commission and track this click to measure offer performance."
        case .sponsored:
            "Opens a partner site. This placement may be sponsored and Pulse Perks may track this click."
        case .promoCode:
            "Use this code with the partner. Pulse Perks may track redemptions to measure offer performance."
        case .direct:
            "Opens a partner site. Pulse Perks may track this click to measure offer performance."
        }
    }
}

extension URL {
    static func supportedOfferURL(from value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              url.isSupportedOfferURL else {
            return nil
        }

        return url
    }

    var isSupportedOfferURL: Bool {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return false
        }

        return true
    }
}

extension Array where Element == Perk {
    func sorted(using sort: PerkSort) -> [Perk] {
        sorted { lhs, rhs in
            sort.compare(lhs, rhs)
        }
    }
}

struct PerkCollection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let searchText: String
    let sort: PerkSort
    let iconName: String
    let tint: Color

    static let sampleData: [PerkCollection] = [
        PerkCollection(
            id: "lunch-break",
            title: "Lunch break",
            subtitle: "Nearby food perks for the workday.",
            category: "Food",
            searchText: "",
            sort: .nearest,
            iconName: "fork.knife",
            tint: Color(red: 0.1, green: 0.55, blue: 0.42)
        ),
        PerkCollection(
            id: "wellness",
            title: "Wellness",
            subtitle: "Fitness and recovery offers with strong value.",
            category: "Fitness",
            searchText: "",
            sort: .bestValue,
            iconName: "heart",
            tint: Color(red: 0.73, green: 0.26, blue: 0.18)
        ),
        PerkCollection(
            id: "online-deals",
            title: "Online deals",
            subtitle: "Remote-friendly offers you can use anywhere.",
            category: "All",
            searchText: "Online",
            sort: .bestValue,
            iconName: "desktopcomputer",
            tint: Color(red: 0.15, green: 0.42, blue: 0.78)
        ),
        PerkCollection(
            id: "ending-soon",
            title: "Ending soon",
            subtitle: "Perks to use before they expire.",
            category: "All",
            searchText: "",
            sort: .endingSoon,
            iconName: "clock",
            tint: Color(red: 0.48, green: 0.34, blue: 0.75)
        )
    ]
}

struct Survey: Identifiable {
    let id: String
    let title: String
    let description: String
    let estimatedTime: String
    let audience: String
    let points: Int
    let matchScore: Int
    let matchReason: String
    let interestIDs: Set<String>
    let questions: [String]
    let iconName: String
    let tint: Color

    static let sampleData: [Survey] = [
        Survey(
            id: "streaming-habits",
            title: "Streaming habits",
            description: "Tell us how you choose shows, subscriptions, and weekend watchlists.",
            estimatedTime: "6 min",
            audience: "Entertainment",
            points: 120,
            matchScore: 92,
            matchReason: "Matched because you saved travel and lifestyle offers and have weekly digest enabled.",
            interestIDs: ["entertainment", "travel"],
            questions: [
                "Which streaming services do you currently use?",
                "How do you decide what to watch next?",
                "What would make you switch or cancel a subscription?"
            ],
            iconName: "play.tv",
            tint: Color(red: 0.15, green: 0.42, blue: 0.78)
        ),
        Survey(
            id: "grocery-routine",
            title: "Grocery routine",
            description: "Share where you shop, what you value, and how deals affect your cart.",
            estimatedTime: "4 min",
            audience: "Shopping",
            points: 80,
            matchScore: 86,
            matchReason: "Matched because retail and food rewards are active in your marketplace.",
            interestIDs: ["shopping"],
            questions: [
                "Where do you buy groceries most often?",
                "Which deal types change what you buy?",
                "How often do you use loyalty rewards at checkout?"
            ],
            iconName: "cart",
            tint: Color(red: 0.1, green: 0.55, blue: 0.42)
        ),
        Survey(
            id: "fitness-goals",
            title: "Fitness goals",
            description: "Help wellness partners understand classes, gear, and recovery habits.",
            estimatedTime: "8 min",
            audience: "Wellness",
            points: 150,
            matchScore: 94,
            matchReason: "Matched because wellness rewards and nearby offers are enabled for your profile.",
            interestIDs: ["wellness"],
            questions: [
                "What fitness goals are you focused on this month?",
                "Which wellness perks would you redeem fastest?",
                "How do you choose between classes, gyms, and at-home workouts?"
            ],
            iconName: "figure.run",
            tint: Color(red: 0.73, green: 0.26, blue: 0.18)
        )
    ]
}

struct Perk: Identifiable {
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
    let offerURL: URL?
    let offerKind: OfferKind
    let iconName: String
    let tint: Color

    var isExpired: Bool {
        daysUntilExpiration <= 0
    }

    static let sampleData: [Perk] = [
        Perk(
            id: "sweetgreen-lunch-credit",
            title: "Sweetgreen lunch credit",
            description: "$12 off your next weekday order at participating locations.",
            partner: "Sweetgreen",
            category: "Food",
            expiration: "Expires Friday",
            distance: "0.4 mi",
            distanceInMiles: 0.4,
            daysUntilExpiration: 5,
            shortDetail: "Lunch near the office",
            redemptionInstructions: "Show your member code at checkout or apply the offer in the partner app.",
            terms: "Valid once per member. Weekday orders only. Cannot be combined with other offers.",
            estimatedSavings: 12,
            memberCode: "PULSE-SG12",
            offerURL: URL(string: "https://www.sweetgreen.com/"),
            offerKind: .affiliate,
            iconName: "fork.knife",
            tint: Color(red: 0.1, green: 0.55, blue: 0.42)
        ),
        Perk(
            id: "classpass-trial-boost",
            title: "ClassPass trial boost",
            description: "Get 20 bonus credits when you start a monthly plan.",
            partner: "ClassPass",
            category: "Fitness",
            expiration: "6 days left",
            distance: "1.2 mi",
            distanceInMiles: 1.2,
            daysUntilExpiration: 6,
            shortDetail: "Bonus credits for classes",
            redemptionInstructions: "Tap redeem, then create or connect your ClassPass account before booking.",
            terms: "New monthly plans only. Bonus credits expire 30 days after activation.",
            estimatedSavings: 39,
            memberCode: "PULSE-FIT20",
            offerURL: URL(string: "https://classpass.com/"),
            offerKind: .affiliate,
            iconName: "figure.run",
            tint: Color(red: 0.15, green: 0.42, blue: 0.78)
        ),
        Perk(
            id: "hoteltonight-escape",
            title: "HotelTonight escape",
            description: "Save 18% on last-minute stays booked this month.",
            partner: "HotelTonight",
            category: "Travel",
            expiration: "Ends Aug 31",
            distance: "Online",
            distanceInMiles: 99,
            daysUntilExpiration: 14,
            shortDetail: "Last-minute trip savings",
            redemptionInstructions: "Use the generated promo code before confirming an eligible hotel stay.",
            terms: "Eligible stays only. Taxes, fees, and blackout dates may apply.",
            estimatedSavings: 48,
            memberCode: "PULSE-STAY18",
            offerURL: URL(string: "https://www.hoteltonight.com/"),
            offerKind: .sponsored,
            iconName: "airplane.departure",
            tint: Color(red: 0.73, green: 0.26, blue: 0.18)
        ),
        Perk(
            id: "everlane-essentials",
            title: "Everlane essentials",
            description: "Take 15% off workwear staples and everyday basics.",
            partner: "Everlane",
            category: "Retail",
            expiration: "New today",
            distance: "Online",
            distanceInMiles: 99,
            daysUntilExpiration: 21,
            shortDetail: "Workwear and basics",
            redemptionInstructions: "Open the partner offer and apply the member discount at checkout.",
            terms: "Applies to full-price items. Excludes gift cards, final sale, and prior purchases.",
            estimatedSavings: 25,
            memberCode: "PULSE-EV15",
            offerURL: URL(string: "https://www.everlane.com/"),
            offerKind: .affiliate,
            iconName: "bag",
            tint: Color(red: 0.48, green: 0.34, blue: 0.75)
        )
    ]
}
