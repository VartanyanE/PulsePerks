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

    private let store = PulsePerksStore.demo

    private var categories: [String] {
        store.categories
    }

    private var memberProfile: MemberProfile {
        store.memberProfile
    }

    private var perks: [Perk] {
        store.perks
    }

    private var collections: [PerkCollection] {
        store.collections
    }

    private var surveys: [Survey] {
        store.surveys
    }

    private var interests: [Interest] {
        store.interests
    }

    private var basePoints: Int {
        store.basePoints
    }

    private var pointsPerRedemption: Int {
        store.pointsPerRedemption
    }

    private var nextRewardPoints: Int {
        store.nextRewardPoints
    }

    private var dailySurveyGoal: Int {
        store.dailySurveyGoal
    }

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
        store.filteredPerks(category: selectedCategory, searchText: searchText, sort: selectedSort)
    }

    private var redeemedPerks: [Perk] {
        store.redeemedPerks(for: redeemedPerkIDs)
    }

    private var redeemedPerkIDs: Set<String> {
        storedIDs(from: redeemedPerkIDsValue)
    }

    private var savedPerks: [Perk] {
        store.savedPerks(for: savedPerkIDs)
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
        store.availableSurveys(completedIDs: completedSurveyIDs)
    }

    private var completedSurveys: [Survey] {
        store.completedSurveys(completedIDs: completedSurveyIDs)
    }

    private var surveyPoints: Int {
        store.surveyPoints(completedIDs: completedSurveyIDs)
    }

    private var dailySurveyGoalProgress: Double {
        min(Double(surveyPoints) / Double(dailySurveyGoal), 1)
    }

    private var memberPoints: Int {
        store.memberPoints(redeemedPerkIDs: redeemedPerkIDs, completedSurveyIDs: completedSurveyIDs)
    }

    private var pointsUntilNextReward: Int {
        store.pointsUntilNextReward(redeemedPerkIDs: redeemedPerkIDs, completedSurveyIDs: completedSurveyIDs)
    }

    private var savedValue: Int {
        store.savedValue(redeemedPerkIDs: redeemedPerkIDs)
    }

    private var recommendedPerks: [Perk] {
        store.recommendedPerks(excluding: redeemedPerkIDs)
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

                    Text(memberProfile.name)
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
                        memberName: memberProfile.name,
                        tier: memberProfile.tier,
                        memberCode: memberProfile.memberCode,
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
                        AccountRow(iconName: "person.text.rectangle", title: "Membership", value: memberProfile.tier)
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
                Text(memberProfile.name)
                    .font(.title2.weight(.bold))

                Text("Member since \(memberProfile.memberSinceYear)")
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

#Preview {
    ContentView()
}
