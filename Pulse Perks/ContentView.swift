//
//  ContentView.swift
//  Pulse Perks
//
//  Created by Emanuil Vartanyan on 8/16/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedCategory = "All"
    @State private var selectedSort = PerkSort.bestValue
    @State private var searchText = ""
    @State private var selectedPerk: Perk?
    @State private var selectedSurvey: Survey?
    @State private var isShowingNotifications = false
    @AppStorage("redeemedPerkIDs") private var redeemedPerkIDsValue = ""
    @AppStorage("savedPerkIDs") private var savedPerkIDsValue = ""
    @AppStorage("completedSurveyIDs") private var completedSurveyIDsValue = ""
    @AppStorage("selectedInterestIDs") private var selectedInterestIDsValue = "shopping,wellness"
    @AppStorage("weeklyDigestEnabled") private var weeklyDigestEnabled = true
    @AppStorage("nearbyPerksEnabled") private var nearbyPerksEnabled = true
    @AppStorage("biometricUnlockEnabled") private var biometricUnlockEnabled = false

    private let categories = ["All", "Food", "Fitness", "Travel", "Retail"]
    private let perks = Perk.sampleData
    private let basePoints = 2450
    private let pointsPerRedemption = 75
    private let nextRewardPoints = 3000
    private let dailySurveyGoal = 300
    private let collections = PerkCollection.sampleData
    private let surveys = Survey.sampleData
    private let interests = Interest.sampleData

    var body: some View {
        TabView {
            discoverTab
                .tabItem {
                    Label("Discover", systemImage: "tag")
                }

            surveysTab
                .tabItem {
                    Label("Surveys", systemImage: "list.clipboard")
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
        .sheet(item: $selectedSurvey) { survey in
            SurveyDetailView(
                survey: survey,
                isCompleted: completedSurveyIDs.contains(survey.id),
                matchScore: matchScore(for: survey),
                matchReason: matchReason(for: survey)
            ) {
                completeSurvey(survey)
            }
        }
    }

    private var discoverTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    rewardsProgress
                    forYouPerks
                    collectionsSection
                    searchField
                    categoryPicker
                    sortPicker
                    featuredPerks
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Pulse Perks")
        }
    }

    private var surveysTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    surveysHero
                    surveySection(title: "Available surveys", surveys: availableSurveys, isCompleted: false)
                    surveySection(title: "Completed", surveys: completedSurveys, isCompleted: true)
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Surveys")
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

    private var completedSurveyIDs: Set<String> {
        storedIDs(from: completedSurveyIDsValue)
    }

    private var selectedInterestIDs: Set<String> {
        storedIDs(from: selectedInterestIDsValue)
    }

    private var selectedInterests: [Interest] {
        interests.filter { selectedInterestIDs.contains($0.id) }
    }

    private var availableSurveys: [Survey] {
        surveys.filter { !completedSurveyIDs.contains($0.id) }
    }

    private var completedSurveys: [Survey] {
        surveys.filter { completedSurveyIDs.contains($0.id) }
    }

    private var surveyPoints: Int {
        completedSurveys.reduce(0) { total, survey in
            total + survey.points
        }
    }

    private var dailySurveyGoalProgress: Double {
        min(Double(surveyPoints) / Double(dailySurveyGoal), 1)
    }

    private var memberPoints: Int {
        basePoints + (redeemedPerks.count * pointsPerRedemption) + surveyPoints
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
                title: "Survey points",
                message: availableSurveys.isEmpty
                    ? "You completed every available survey."
                    : "\(availableSurveys.count) surveys can add \(availableSurveys.reduce(0) { $0 + $1.points }) points.",
                iconName: "list.clipboard"
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

    private func completeSurvey(_ survey: Survey) {
        var ids = completedSurveyIDs
        ids.insert(survey.id)
        completedSurveyIDsValue = encodedIDs(ids)
    }

    private func toggleInterest(_ interest: Interest) {
        var ids = selectedInterestIDs

        if ids.contains(interest.id) {
            ids.remove(interest.id)
        } else {
            ids.insert(interest.id)
        }

        selectedInterestIDsValue = encodedIDs(ids)
    }

    private func matchScore(for survey: Survey) -> Int {
        let overlap = survey.interestIDs.intersection(selectedInterestIDs).count
        let preferenceBoost = overlap * 5
        let digestBoost = weeklyDigestEnabled ? 2 : 0
        return min(survey.matchScore + preferenceBoost + digestBoost, 99)
    }

    private func matchReason(for survey: Survey) -> String {
        let matches = selectedInterests
            .filter { survey.interestIDs.contains($0.id) }
            .map(\.title)

        if matches.isEmpty {
            return survey.matchReason
        }

        return "Matched because your profile includes \(matches.joined(separator: ", "))."
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
        completedSurveyIDsValue = ""
    }

    private func applyCollection(_ collection: PerkCollection) {
        selectedCategory = collection.category
        selectedSort = collection.sort
        searchText = collection.searchText
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
                    AppTheme.heroStart(for: colorScheme),
                    AppTheme.heroEnd(for: colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
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
                .stroke(AppTheme.stroke(for: colorScheme))
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
                .stroke(AppTheme.stroke(for: colorScheme))
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
                                    : AppTheme.controlBackground(for: colorScheme),
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

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Collections")
                .font(.title2.weight(.bold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(collections) { collection in
                    Button {
                        applyCollection(collection)
                    } label: {
                        PerkCollectionCard(collection: collection)
                    }
                    .buttonStyle(.plain)
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

    private var surveysHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Earn with surveys", systemImage: "list.clipboard")
                    .font(.headline)

                Spacer()

                Text("+\(surveyPoints) pts earned")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Share product feedback, earn points, and use them toward member rewards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: dailySurveyGoalProgress)
                .tint(Color(red: 0.1, green: 0.55, blue: 0.42))

            Text("\(min(surveyPoints, dailySurveyGoal)) of \(dailySurveyGoal) daily survey points")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatBadge(value: "\(availableSurveys.count)", label: "Available")
                StatBadge(value: "\(completedSurveys.count)", label: "Done")
                StatBadge(value: "\(availableSurveys.reduce(0) { $0 + $1.points })", label: "Open pts")
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private func surveySection(title: String, surveys: [Survey], isCompleted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))

            if surveys.isEmpty {
                ContentUnavailableView(
                    isCompleted ? "No completed surveys" : "No surveys available",
                    systemImage: isCompleted ? "checkmark.seal" : "list.clipboard",
                    description: Text(isCompleted ? "Completed surveys will show here." : "New surveys will appear when they match your profile.")
                )
                .padding(.vertical, 28)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(surveys) { survey in
                        Button {
                            selectedSurvey = survey
                        } label: {
                            SurveyRow(
                                survey: survey,
                                isCompleted: isCompleted,
                                matchScore: matchScore(for: survey)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var walletTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MembershipCard(
                        memberName: "Emanuil",
                        tier: "Pulse Plus",
                        memberCode: "PULSE-2450",
                        points: memberPoints,
                        savedValue: savedValue
                    )

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
            .background(AppTheme.pageBackground(for: colorScheme))
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
                StatBadge(value: "+\(surveyPoints)", label: "Survey pts")
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
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
                            .stroke(AppTheme.stroke(for: colorScheme))
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
                            .stroke(AppTheme.stroke(for: colorScheme))
                    )

                    surveyPreferences
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Account")
        }
    }

    private var surveyPreferences: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Survey interests")
                .font(.title2.weight(.bold))

            Text("Choose topics to improve survey matching.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(interests) { interest in
                    InterestChip(
                        interest: interest,
                        isSelected: selectedInterestIDs.contains(interest.id)
                    ) {
                        toggleInterest(interest)
                    }
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
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
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct StatBadge: View {
    @Environment(\.colorScheme) private var colorScheme

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
        .background(AppTheme.elevatedBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MembershipCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let memberName: String
    let tier: String
    let memberCode: String
    let points: Int
    let savedValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tier)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))

                    Text(memberName)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
            }

            BarcodeView(code: memberCode)

            HStack(spacing: 12) {
                StatBadge(value: points.formatted(), label: "Points")
                StatBadge(value: "$\(savedValue)", label: "Saved")
            }

            Text(memberCode)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.heroStart(for: colorScheme),
                    AppTheme.heroEnd(for: colorScheme)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct BarcodeView: View {
    @Environment(\.colorScheme) private var colorScheme

    let code: String

    private var bars: [CGFloat] {
        code.unicodeScalars.enumerated().map { index, scalar in
            CGFloat((Int(scalar.value) + index) % 4 + 1)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, width in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary)
                    .frame(width: width, height: 58)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.elevatedBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Member barcode")
    }
}

private struct RecommendedPerkCard: View {
    @Environment(\.colorScheme) private var colorScheme

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
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct PerkCollectionCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let collection: PerkCollection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: collection.iconName)
                .font(.headline)
                .foregroundStyle(collection.tint)
                .frame(width: 38, height: 38)
                .background(collection.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(collection.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(collection.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct SurveyRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let survey: Survey
    let isCompleted: Bool
    let matchScore: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: survey.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(survey.tint)
                .frame(width: 44, height: 44)
                .background(survey.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(survey.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("+\(survey.points) pts")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))
                }

                Text(survey.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(survey.estimatedTime, systemImage: "clock")
                    Label(survey.audience, systemImage: "person.2")
                    Label("\(matchScore)% match", systemImage: "scope")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Label(isCompleted ? "Completed" : "Tap to preview", systemImage: isCompleted ? "checkmark.circle.fill" : "chevron.right.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isCompleted ? .secondary : Color(red: 0.1, green: 0.55, blue: 0.42))
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct SurveyDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let survey: Survey
    let isCompleted: Bool
    let matchScore: Int
    let matchReason: String
    let complete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: survey.iconName)
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(survey.tint)
                            .frame(width: 68, height: 68)
                            .background(survey.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 7) {
                            Text(survey.audience)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(survey.tint)

                            Text(survey.title)
                                .font(.largeTitle.weight(.bold))

                            Text(survey.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        StatBadge(value: "+\(survey.points)", label: "Points")
                        StatBadge(value: survey.estimatedTime, label: "Time")
                        StatBadge(value: "\(matchScore)%", label: "Match")
                    }

                    DetailRow(iconName: "questionmark.circle", title: "Question count", value: "\(survey.questions.count) questions")
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.stroke(for: colorScheme))
                        )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Profile fit", systemImage: "scope")
                                .font(.headline)

                            Spacer()

                            Text("\(matchScore)%")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: Double(matchScore), total: 100)
                            .tint(survey.tint)

                        Text(matchReason)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.stroke(for: colorScheme))
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview")
                            .font(.headline)

                        ForEach(Array(survey.questions.enumerated()), id: \.offset) { index, question in
                            SurveyQuestionPreview(index: index + 1, question: question)
                        }
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.stroke(for: colorScheme))
                    )

                    if isCompleted {
                        SurveyCompletionView(points: survey.points)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Survey")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    complete()
                } label: {
                    Label(isCompleted ? "Points awarded" : "Complete survey", systemImage: isCompleted ? "checkmark.circle.fill" : "checkmark.seal")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            isCompleted
                                ? Color.gray
                                : Color(red: 0.1, green: 0.55, blue: 0.42),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .disabled(isCompleted)
                .padding(20)
                .background(.regularMaterial)
            }
        }
    }
}

private struct SurveyQuestionPreview: View {
    let index: Int
    let question: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color(red: 0.1, green: 0.55, blue: 0.42), in: Circle())

            Text(question)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

private struct SurveyCompletionView: View {
    @Environment(\.colorScheme) private var colorScheme

    let points: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))

                Text("Survey complete")
                    .font(.headline)
            }

            Text("+\(points) points were added to your rewards balance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.successBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.1, green: 0.55, blue: 0.42).opacity(0.18))
        )
    }
}

private struct PerkRow: View {
    @Environment(\.colorScheme) private var colorScheme

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
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct PerkDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let perk: Perk
    let isRedeemed: Bool
    let isSaved: Bool
    let redeem: () -> Void
    let toggleSave: () -> Void

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

                    if isRedeemed {
                        RedeemedConfirmationView(perk: perk)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(iconName: "tag", title: "Category", value: perk.category)
                        DetailRow(iconName: "calendar", title: "Availability", value: perk.expiration)
                        DetailRow(iconName: "location", title: "Distance", value: perk.distance)
                        DetailRow(iconName: "dollarsign.circle", title: "Estimated value", value: "$\(perk.estimatedSavings)")
                        DetailRow(iconName: "qrcode", title: "Member code", value: perk.memberCode)
                        DetailRow(iconName: "checkmark.seal", title: "How to use", value: perk.redemptionInstructions)
                        DetailRow(iconName: "doc.text", title: "Terms", value: perk.terms)
                    }
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.stroke(for: colorScheme))
                    )
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
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
    @Environment(\.colorScheme) private var colorScheme

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
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct RedeemedConfirmationView: View {
    @Environment(\.colorScheme) private var colorScheme

    let perk: Perk

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.1, green: 0.55, blue: 0.42))

                Text("Ready to use")
                    .font(.headline)
            }

            Text("Show code \(perk.memberCode) at checkout. This perk is also saved in your Wallet activity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.successBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.1, green: 0.55, blue: 0.42).opacity(0.18))
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

private struct InterestChip: View {
    let interest: Interest
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: interest.iconName)
                    .font(.subheadline.weight(.semibold))

                Text(interest.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                isSelected
                    ? Color(red: 0.1, green: 0.55, blue: 0.42)
                    : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )
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

private struct Interest: Identifiable {
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

private enum AppTheme {
    static let accent = Color(red: 0.1, green: 0.55, blue: 0.42)

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.06, blue: 0.06)
            : Color(red: 0.96, green: 0.97, blue: 0.96)
    }

    static func elevatedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.72)
    }

    static func controlBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color(red: 0.91, green: 0.93, blue: 0.92)
    }

    static func stroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.06)
    }

    static func heroStart(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.16, blue: 0.14)
            : Color(red: 0.95, green: 0.98, blue: 1.0)
    }

    static func heroEnd(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.13, blue: 0.20)
            : Color(red: 0.93, green: 0.96, blue: 0.91)
    }

    static func successBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.18, blue: 0.13)
            : Color(red: 0.9, green: 0.97, blue: 0.94)
    }
}

private struct PerkCollection: Identifiable {
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

private struct Survey: Identifiable {
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
    let terms: String
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
            terms: "Valid once per member. Weekday orders only. Cannot be combined with other offers.",
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
            terms: "New monthly plans only. Bonus credits expire 30 days after activation.",
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
            terms: "Eligible stays only. Taxes, fees, and blackout dates may apply.",
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
            terms: "Applies to full-price items. Excludes gift cards, final sale, and prior purchases.",
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
