//
//  ContentView.swift
//  Pulse Perks
//
//  Created by Emanuil Vartanyan on 8/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedCategory = "All"
    @State private var selectedSort = PerkSort.bestValue
    @State private var searchText = ""
    @State private var selectedPerk: Perk?
    @State private var isShowingNotifications = false
    @AppStorage("redeemedPerkIDs") private var redeemedPerkIDsValue = ""
    @AppStorage("savedPerkIDs") private var savedPerkIDsValue = ""
    @AppStorage("weeklyDigestEnabled") private var weeklyDigestEnabled = true
    @AppStorage("nearbyPerksEnabled") private var nearbyPerksEnabled = true
    @AppStorage("biometricUnlockEnabled") private var biometricUnlockEnabled = false

    private let categories = ["All", "Food", "Fitness", "Travel", "Retail"]
    private let perks = Perk.sampleData
    private let basePoints = 2450
    private let pointsPerRedemption = 75
    private let nextRewardPoints = 3000

    var body: some View {
        TabView {
            discoverTab
                .tabItem {
                    Label("Discover", systemImage: "tag")
                }

            walletTab
                .tabItem {
                    Label("Wallet", systemImage: "wallet.pass")
                }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .tint(Color(red: 0.1, green: 0.55, blue: 0.42))
        .sheet(item: $selectedPerk) { perk in
            PerkDetailView(
                perk: perk,
                isRedeemed: redeemedPerkIDs.contains(perk.id),
                isSaved: savedPerkIDs.contains(perk.id)
            ) {
                redeem(perk)
            } toggleSave: {
                toggleSaved(perk)
            }
        }
        .sheet(isPresented: $isShowingNotifications) {
            NotificationsView(notifications: notifications)
        }
    }

    private var discoverTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    rewardsProgress
                    forYouPerks
                    searchField
                    categoryPicker
                    sortPicker
                    featuredPerks
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.96))
            .navigationTitle("Pulse Perks")
        }
    }

    private var filteredPerks: [Perk] {
        let categoryMatches = selectedCategory == "All"
            ? perks
            : perks.filter { $0.category == selectedCategory }

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

        return searchMatches.sorted(using: selectedSort)
    }

    private var redeemedPerks: [Perk] {
        perks.filter { redeemedPerkIDs.contains($0.id) }
    }

    private var redeemedPerkIDs: Set<String> {
        storedIDs(from: redeemedPerkIDsValue)
    }

    private var savedPerks: [Perk] {
        perks.filter { savedPerkIDs.contains($0.id) }
    }

    private var savedPerkIDs: Set<String> {
        storedIDs(from: savedPerkIDsValue)
    }

    private var memberPoints: Int {
        basePoints + (redeemedPerks.count * pointsPerRedemption)
    }

    private var pointsUntilNextReward: Int {
        max(nextRewardPoints - memberPoints, 0)
    }

    private var savedValue: Int {
        redeemedPerks.reduce(0) { total, perk in
            total + perk.estimatedSavings
        }
    }

    private var recommendedPerks: [Perk] {
        perks
            .filter { !redeemedPerkIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.estimatedSavings > rhs.estimatedSavings
            }
    }

    private var notifications: [PulseNotification] {
        [
            PulseNotification(
                title: "Reward progress",
                message: pointsUntilNextReward == 0
                    ? "Your $25 wellness credit is ready."
                    : "You are \(pointsUntilNextReward) points away from your next reward.",
                iconName: "sparkles"
            ),
            PulseNotification(
                title: "Saved perks",
                message: savedPerks.isEmpty
                    ? "Save perks from Discover to compare offers later."
                    : "You have \(savedPerks.count) saved \(savedPerks.count == 1 ? "perk" : "perks") in Wallet.",
                iconName: "bookmark"
            ),
            PulseNotification(
                title: "Nearby offers",
                message: nearbyPerksEnabled
                    ? "Nearby perk alerts are enabled for local offers."
                    : "Turn on nearby perks in Account to get local offer alerts.",
                iconName: "location"
            )
        ]
    }

    private func redeem(_ perk: Perk) {
        var ids = redeemedPerkIDs
        ids.insert(perk.id)
        redeemedPerkIDsValue = encodedIDs(ids)
    }

    private func toggleSaved(_ perk: Perk) {
        var ids = savedPerkIDs

        if ids.contains(perk.id) {
            ids.remove(perk.id)
        } else {
            ids.insert(perk.id)
        }

        savedPerkIDsValue = encodedIDs(ids)
    }

    private func storedIDs(from value: String) -> Set<String> {
        Set(value.split(separator: ",").map(String.init))
    }

    private func encodedIDs(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    private func resetDemoActivity() {
        savedPerkIDsValue = ""
        redeemedPerkIDsValue = ""
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Good afternoon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Emanuil")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button {
                    isShowingNotifications = true
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.background, in: Circle())
                }
                .accessibilityLabel("Notifications")
            }

            HStack(spacing: 12) {
                StatBadge(value: "$\(savedValue)", label: "Saved")
                StatBadge(value: "\(perks.count)", label: "Active")
                StatBadge(value: memberPoints.formatted(), label: "Points")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.98, blue: 1.0),
                    Color(red: 0.93, green: 0.96, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }

    private var rewardsProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Next reward", systemImage: "sparkles")
                    .font(.headline)

                Spacer()

                Text(pointsUntilNextReward == 0 ? "Ready" : "\(pointsUntilNextReward) pts away")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(memberPoints), total: Double(nextRewardPoints))
                .tint(Color(red: 0.1, green: 0.55, blue: 0.42))

            Text(pointsUntilNextReward == 0 ? "Your $25 wellness credit is ready to redeem." : "Unlock a $25 wellness credit when you reach \(nextRewardPoints.formatted()) points.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search perks", text: $searchText)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(
                                selectedCategory == category
                                    ? Color(red: 0.1, green: 0.55, blue: 0.42)
                                    : Color(red: 0.91, green: 0.93, blue: 0.92),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort perks", selection: $selectedSort) {
            ForEach(PerkSort.allCases) { sort in
                Label(sort.title, systemImage: sort.iconName)
                    .tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    private var forYouPerks: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("For you")
                    .font(.title2.weight(.bold))

                Spacer()

                Text("Best value")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recommendedPerks.prefix(3)) { perk in
                        Button {
                            selectedPerk = perk
                        } label: {
                            RecommendedPerkCard(
                                perk: perk,
                                isSaved: savedPerkIDs.contains(perk.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var featuredPerks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(selectedSort.sectionTitle)
                .font(.title2.weight(.bold))

            LazyVStack(spacing: 12) {
                ForEach(filteredPerks) { perk in
                    Button {
                        selectedPerk = perk
                    } label: {
                        PerkRow(
                            perk: perk,
                            isRedeemed: redeemedPerkIDs.contains(perk.id),
                            isSaved: savedPerkIDs.contains(perk.id)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if filteredPerks.isEmpty {
                    ContentUnavailableView(
                        "No perks found",
                        systemImage: "tag.slash",
                        description: Text("Try another category or search term.")
                    )
                    .padding(.vertical, 30)
                }
            }
        }
    }

    private var walletTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    walletSummary

                    walletSection(
                        title: "Saved perks",
                        emptyTitle: "No saved perks",
                        emptyIcon: "bookmark",
                        emptyDescription: "Save offers from their detail page to compare them later.",
                        perks: savedPerks,
                        showsRedeemedState: false
                    )

                    walletSection(
                        title: "Redeemed perks",
                        emptyTitle: "No redeemed perks",
                        emptyIcon: "wallet.pass",
                        emptyDescription: "Redeemed offers will appear here for quick access.",
                        perks: redeemedPerks,
                        showsRedeemedState: true
                    )

                    recentActivity
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.96))
            .navigationTitle("Wallet")
        }
    }

    private var walletSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Member wallet", systemImage: "checkmark.seal")
                    .font(.headline)

                Spacer()

                Text("\(redeemedPerks.count) redeemed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                StatBadge(value: memberPoints.formatted(), label: "Points")
                StatBadge(value: "\(savedPerks.count)", label: "Saved")
                StatBadge(value: "$\(savedValue)", label: "Saved value")
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent activity")
                .font(.title2.weight(.bold))

            if redeemedPerks.isEmpty {
                Text("Redeem a perk to start building your activity history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.06))
                    )
            } else {
                VStack(spacing: 12) {
                    ForEach(redeemedPerks) { perk in
                        ActivityRow(perk: perk)
                    }
                }
            }
        }
    }

    private var accountTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    accountHeader

                    VStack(spacing: 12) {
                        AccountRow(iconName: "person.text.rectangle", title: "Membership", value: "Pulse Plus")
                        AccountRow(iconName: "creditcard", title: "Payment method", value: "Not connected")
                        AccountToggleRow(iconName: "bell", title: "Weekly digest", isOn: $weeklyDigestEnabled)
                        AccountToggleRow(iconName: "location", title: "Nearby perks", isOn: $nearbyPerksEnabled)
                        AccountToggleRow(iconName: "lock", title: "Biometric unlock", isOn: $biometricUnlockEnabled)
                        AccountActionRow(iconName: "arrow.counterclockwise", title: "Reset demo activity") {
                            resetDemoActivity()
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.06))
                    )
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.96))
            .navigationTitle("Account")
        }
    }

    private func walletSection(
        title: String,
        emptyTitle: String,
        emptyIcon: String,
        emptyDescription: String,
        perks: [Perk],
        showsRedeemedState: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))

            if perks.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptyIcon,
                    description: Text(emptyDescription)
                )
                .padding(.vertical, 34)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(perks) { perk in
                        Button {
                            selectedPerk = perk
                        } label: {
                            PerkRow(
                                perk: perk,
                                isRedeemed: showsRedeemedState || redeemedPerkIDs.contains(perk.id),
                                isSaved: savedPerkIDs.contains(perk.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var accountHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))

            VStack(alignment: .leading, spacing: 5) {
                Text("Emanuil")
                    .font(.title2.weight(.bold))

                Text("Member since 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }
}

private struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RecommendedPerkCard: View {
    let perk: Perk
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: perk.iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(perk.tint)
                    .frame(width: 42, height: 42)
                    .background(perk.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("$\(perk.estimatedSavings) value")
                    .font(.title3.weight(.bold))

                Text(perk.partner)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(perk.shortDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Label(perk.distance, systemImage: "location")
                Spacer()
                Text(perk.category)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .frame(width: 210, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }
}

private struct PerkRow: View {
    let perk: Perk
    let isRedeemed: Bool
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: perk.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(perk.tint)
                .frame(width: 44, height: 44)
                .background(perk.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(perk.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(isRedeemed ? "Redeemed" : perk.category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isRedeemed ? Color(red: 0.1, green: 0.55, blue: 0.42) : .secondary)
                }

                Text(perk.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(perk.expiration)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))

                HStack(spacing: 10) {
                    Label(perk.distance, systemImage: "location")
                    Label("$\(perk.estimatedSavings) value", systemImage: "dollarsign.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if isSaved {
                Image(systemName: "bookmark.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                    .accessibilityLabel("Saved")
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }
}

private struct PerkDetailView: View {
    let perk: Perk
    let isRedeemed: Bool
    let isSaved: Bool
    let redeem: () -> Void
    let toggleSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: perk.iconName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(perk.tint)
                        .frame(width: 76, height: 76)
                        .background(perk.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(perk.partner)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(perk.tint)

                        Text(perk.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)

                        Text(perk.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(iconName: "tag", title: "Category", value: perk.category)
                        DetailRow(iconName: "calendar", title: "Availability", value: perk.expiration)
                        DetailRow(iconName: "location", title: "Distance", value: perk.distance)
                        DetailRow(iconName: "dollarsign.circle", title: "Estimated value", value: "$\(perk.estimatedSavings)")
                        DetailRow(iconName: "qrcode", title: "Member code", value: perk.memberCode)
                        DetailRow(iconName: "checkmark.seal", title: "How to use", value: perk.redemptionInstructions)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.06))
                    )
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.97, blue: 0.96))
            .navigationTitle("Perk details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        toggleSave()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                            .frame(width: 52, height: 52)
                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel(isSaved ? "Remove saved perk" : "Save perk")

                    Button {
                        redeem()
                    } label: {
                        Label(isRedeemed ? "Redeemed" : "Redeem perk", systemImage: isRedeemed ? "checkmark.circle.fill" : "ticket")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                isRedeemed
                                    ? Color.gray
                                    : Color(red: 0.1, green: 0.55, blue: 0.42),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .disabled(isRedeemed)
                }
                .padding(20)
                .background(.regularMaterial)
            }
        }
    }
}

private struct ActivityRow: View {
    let perk: Perk

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Redeemed \(perk.partner)")
                    .font(.subheadline.weight(.semibold))

                Text("Saved about $\(perk.estimatedSavings) with code \(perk.memberCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06))
        )
    }
}

private struct DetailRow: View {
    let iconName: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct AccountRow: View {
    let iconName: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                .frame(width: 28)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 36)
    }
}

private struct AccountToggleRow: View {
    let iconName: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                    .frame(width: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .toggleStyle(.switch)
        .frame(minHeight: 36)
    }
}

private struct AccountActionRow: View {
    let iconName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.73, green: 0.26, blue: 0.18))
                    .frame(width: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.73, green: 0.26, blue: 0.18))

                Spacer()
            }
            .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationsView: View {
    let notifications: [PulseNotification]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(notifications) { notification in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: notification.iconName)
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                        .frame(width: 30, height: 30)
                        .background(Color(red: 0.1, green: 0.55, blue: 0.42).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.headline)

                        Text(notification.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PulseNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let iconName: String
}

private enum PerkSort: String, CaseIterable, Identifiable {
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

private extension Array where Element == Perk {
    func sorted(using sort: PerkSort) -> [Perk] {
        sorted { lhs, rhs in
            sort.compare(lhs, rhs)
        }
    }
}

private struct Perk: Identifiable {
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
    let estimatedSavings: Int
    let memberCode: String
    let iconName: String
    let tint: Color

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
            estimatedSavings: 12,
            memberCode: "PULSE-SG12",
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
            estimatedSavings: 39,
            memberCode: "PULSE-FIT20",
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
            estimatedSavings: 48,
            memberCode: "PULSE-STAY18",
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
            estimatedSavings: 25,
            memberCode: "PULSE-EV15",
            iconName: "bag",
            tint: Color(red: 0.48, green: 0.34, blue: 0.75)
        )
    ]
}

#Preview {
    ContentView()
}
