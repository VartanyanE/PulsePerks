//
//  ContentView.swift
//  RewardLoop
//
//  Created by Emanuil Vartanyan on 8/16/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum RewardLoopTab {
    case discover
    case surveys
    case wallet
    case account
}

struct ContentView: View {
    let configuration: SupabaseConfiguration
    let authSession: AuthSession
    let refreshSession: (Bool) async throws -> AuthSession
    let signOut: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var selectedTab = RewardLoopTab.discover
    @State private var selectedCategory = "All"
    @State private var selectedSort = PerkSort.bestValue
    @State private var searchText = ""
    @State private var selectedPerk: Perk?
    @State private var selectedSurvey: Survey?
    @State private var pendingPartnerSurvey: PartnerSurveyOffer?
    @State private var isShowingNotifications = false
    @State private var isShowingProfileEditor = false
    @State private var isShowingAffiliateDisclosure = false
    @State private var isShowingPrivacyDisclosure = false
    @State private var isConfirmingClearOfferHistory = false
    @State private var isConfirmingOpenOffer = false
    @State private var isConfirmingPartnerSurvey = false
    @State private var diagnosticsStatusMessage: String?
    @State private var pendingOfferToOpen: Perk?
    @State private var redeemedPerkIDsValue: String
    @State private var savedPerkIDsValue: String
    @State private var completedSurveyIDsValue: String
    @State private var selectedInterestIDsValue: String
    @State private var weeklyDigestEnabled: Bool
    @State private var nearbyPerksEnabled: Bool
    @State private var offerClickCount: Int
    @State private var offerClickHistory: [OfferClickHistoryEntry]
    @State private var activeAuthSession: AuthSession
    @State private var preferenceSyncTask: Task<Void, Never>?
    @State private var activitySyncTask: Task<Void, Never>?
    @State private var redeemingPerkIDs = Set<String>()
    @State private var savingPerkIDs = Set<String>()
    @State private var completingSurveyIDs = Set<String>()
    @State private var startingPartnerSurveyIDs = Set<String>()
    @State private var localActivityModifiedAt: Date?
    @State private var hasPendingPreferenceSync = false

    @State private var store = RewardLoopStore.demo
    @State private var partnerSurveyOffers = [PartnerSurveyOffer]()
    @State private var partnerSurveySessions = [PartnerSurveySession]()
    @State private var partnerSurveyStatusMessage = "Partner surveys are loading."
    @State private var partnerSurveyState = PartnerSurveyConnectionState.loading
    @State private var isLoadingPartnerSurveys = false
    @State private var isAwaitingPartnerSurveyReturn = false
    @State private var backendState = BackendState.notConfigured
    @State private var backendStatusDetail = "Using local demo data"
    @State private var isLoadingBootstrap = false
    @State private var lastBootstrapSync: Date?

    init(
        configuration: SupabaseConfiguration,
        authSession: AuthSession,
        refreshSession: @escaping (Bool) async throws -> AuthSession,
        signOut: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.authSession = authSession
        self.refreshSession = refreshSession
        self.signOut = signOut

        let cachedActivity = UserActivityCache.load(userID: authSession.userID)
        _redeemedPerkIDsValue = State(initialValue: cachedActivity.redeemedPerkIDsValue)
        _savedPerkIDsValue = State(initialValue: cachedActivity.savedPerkIDsValue)
        _completedSurveyIDsValue = State(initialValue: cachedActivity.completedSurveyIDsValue)
        _selectedInterestIDsValue = State(initialValue: cachedActivity.selectedInterestIDsValue)
        _weeklyDigestEnabled = State(initialValue: cachedActivity.weeklyDigestEnabled)
        _nearbyPerksEnabled = State(initialValue: cachedActivity.nearbyPerksEnabled)
        _localActivityModifiedAt = State(initialValue: cachedActivity.modifiedAt)
        _offerClickCount = State(initialValue: cachedActivity.offerClickCount)
        _offerClickHistory = State(initialValue: cachedActivity.offerClickHistory)
        _activeAuthSession = State(initialValue: authSession)

        if let cachedBootstrap = UserBootstrapCache.load(userID: authSession.userID) {
            _store = State(initialValue: RewardLoopStore(response: cachedBootstrap.response))
            _backendState = State(initialValue: .failed)
            _backendStatusDetail = State(initialValue: "Using saved data until Supabase syncs.")
            _lastBootstrapSync = State(initialValue: cachedBootstrap.cachedAt)
        }
    }

    private var backend: RewardLoopBackend {
        SupabaseRewardLoopClient(configuration: configuration.authenticated(with: activeAuthSession))
    }

    private var backendHost: String {
        configuration.projectURL.host() ?? "Not configured"
    }

    private var lastSyncStatus: String {
        guard let lastBootstrapSync else {
            return "Not synced yet"
        }

        return lastBootstrapSync.formatted(date: .abbreviated, time: .shortened)
    }

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
        TabView(selection: $selectedTab) {
            discoverTab
                .tabItem {
                    Label("Discover", systemImage: "tag")
                }
                .tag(RewardLoopTab.discover)

            surveysTab
                .tabItem {
                    Label("Surveys", systemImage: "list.clipboard")
                }
                .tag(RewardLoopTab.surveys)

            walletTab
                .tabItem {
                    Label("Wallet", systemImage: "wallet.pass")
                }
                .tag(RewardLoopTab.wallet)

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
                .tag(RewardLoopTab.account)
        }
        .tint(Color(red: 0.1, green: 0.55, blue: 0.42))
        .sheet(item: $selectedPerk) { perk in
            PerkDetailView(
                perk: perk,
                isRedeemed: redeemedPerkIDs.contains(perk.id),
                isSaved: savedPerkIDs.contains(perk.id),
                isRedeeming: redeemingPerkIDs.contains(perk.id),
                isSaving: savingPerkIDs.contains(perk.id)
            ) {
                redeem(perk)
            } toggleSave: {
                toggleSaved(perk)
            } openOffer: {
                requestOpenOffer(perk)
            }
        }
        .sheet(isPresented: $isShowingNotifications) {
            NotificationsView(notifications: notifications) { notification in
                openNotification(notification)
            }
        }
        .sheet(item: $selectedSurvey) { survey in
            SurveyDetailView(
                survey: survey,
                isCompleted: completedSurveyIDs.contains(survey.id),
                isCompleting: completingSurveyIDs.contains(survey.id),
                matchScore: matchScore(for: survey),
                matchReason: matchReason(for: survey)
            ) { responses in
                completeSurvey(survey, responses: responses)
            }
        }
        .sheet(isPresented: $isShowingProfileEditor) {
            EditProfileView(profile: memberProfile) { request in
                await updateProfile(request)
            }
        }
        .sheet(isPresented: $isShowingAffiliateDisclosure) {
            AffiliateDisclosureView()
        }
        .sheet(isPresented: $isShowingPrivacyDisclosure) {
            PrivacyDisclosureView()
        }
        .confirmationDialog(
            "Clear local offer history?",
            isPresented: $isConfirmingClearOfferHistory,
            titleVisibility: .visible
        ) {
            Button("Clear history", role: .destructive) {
                clearOfferHistory()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the offer clicks shown on this device. Backend click logs used for partner reporting are not deleted.")
        }
        .confirmationDialog(
            "Open partner offer?",
            isPresented: $isConfirmingOpenOffer,
            titleVisibility: .visible
        ) {
            if let pendingOfferToOpen {
                Button("Open \(pendingOfferToOpen.partner)") {
                    openOffer(pendingOfferToOpen)
                }
            }

            Button("Cancel", role: .cancel) {
                pendingOfferToOpen = nil
            }
        } message: {
            Text(openOfferConfirmationMessage)
        }
        .confirmationDialog(
            "Start partner survey?",
            isPresented: $isConfirmingPartnerSurvey,
            titleVisibility: .visible
        ) {
            if let pendingPartnerSurvey {
                Button("Start \(pendingPartnerSurvey.provider.title) survey") {
                    startPartnerSurvey(pendingPartnerSurvey)
                }
            }

            Button("Cancel", role: .cancel) {
                pendingPartnerSurvey = nil
            }
        } message: {
            Text(partnerSurveyConfirmationMessage)
        }
        .task {
            await refreshAppData()
        }
        .onChange(of: authSession) { _, newSession in
            activeAuthSession = newSession
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if hasPendingPreferenceSync {
                    retryPendingSync()
                }

                Task {
                    await refreshBootstrapIfStale()
                    await refreshPartnerSurveySessionsAfterReturnIfNeeded()
                }
            case .inactive, .background:
                flushPendingChangesForSuspension()
            @unknown default:
                break
            }
        }
    }

    private var discoverTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    syncStatusBanner
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
            .refreshable {
                await refreshAppData()
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("RewardLoop")
        }
    }

    private var surveysTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    syncStatusBanner
                    surveysHero
                    partnerSurveysSection
                    surveySection(title: "Available surveys", surveys: availableSurveys, isCompleted: false)
                    surveySection(title: "Completed", surveys: completedSurveys, isCompleted: true)
                }
                .padding(20)
            }
            .refreshable {
                await refreshAppData()
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

    private var weeklyDigestBinding: Binding<Bool> {
        Binding {
            weeklyDigestEnabled
        } set: { newValue in
            weeklyDigestEnabled = newValue
            syncPreferences()
        }
    }

    private var nearbyPerksBinding: Binding<Bool> {
        Binding {
            nearbyPerksEnabled
        } set: { newValue in
            nearbyPerksEnabled = newValue
            syncPreferences()
        }
    }

    private var availableSurveys: [Survey] {
        store.availableSurveys(completedIDs: completedSurveyIDs)
    }

    private var completedSurveys: [Survey] {
        store.completedSurveys(completedIDs: completedSurveyIDs)
    }

    private var partnerSurveyPotentialPoints: Int {
        partnerSurveyOffers.reduce(0) { total, offer in
            total + offer.rewardPoints
        }
    }

    private var completedPartnerSurveySessions: [PartnerSurveySession] {
        partnerSurveySessions.filter(\.awardsPoints)
    }

    private var completedPartnerSurveyPoints: Int {
        completedPartnerSurveySessions.reduce(0) { total, session in
            total + session.rewardPoints
        }
    }

    private var surveyPoints: Int {
        store.surveyPoints(completedIDs: completedSurveyIDs)
    }

    private var totalSurveyPoints: Int {
        surveyPoints + completedPartnerSurveyPoints
    }

    private var dailySurveyGoalProgress: Double {
        min(Double(totalSurveyPoints) / Double(dailySurveyGoal), 1)
    }

    private var rewardProgress: Double {
        min(Double(memberPoints) / Double(nextRewardPoints), 1)
    }

    private var memberPoints: Int {
        store.memberPoints(redeemedPerkIDs: redeemedPerkIDs, completedSurveyIDs: completedSurveyIDs)
            + completedPartnerSurveyPoints
    }

    private var pointsUntilNextReward: Int {
        max(nextRewardPoints - memberPoints, 0)
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
                iconName: "sparkles",
                actionTitle: "View wallet",
                destination: .wallet
            ),
            PulseNotification(
                title: "Saved perks",
                message: savedPerks.isEmpty
                    ? "Save perks from Discover to compare offers later."
                    : "You have \(savedPerks.count) saved \(savedPerks.count == 1 ? "perk" : "perks") in Wallet.",
                iconName: "bookmark",
                actionTitle: "Open wallet",
                destination: .wallet
            ),
            PulseNotification(
                title: "Survey points",
                message: availableSurveys.isEmpty
                    ? "You completed every available survey."
                    : "\(availableSurveys.count) surveys can add \(availableSurveys.reduce(0) { $0 + $1.points }) points.",
                iconName: "list.clipboard",
                actionTitle: "See surveys",
                destination: .surveys
            ),
            PulseNotification(
                title: "Nearby offers",
                message: nearbyPerksEnabled
                    ? "Nearby perk alerts are enabled for local offers."
                    : "Turn on nearby perks in Account to get local offer alerts.",
                iconName: "location",
                actionTitle: "Manage alerts",
                destination: .account
            )
        ]
    }

    private var hasPendingSyncChanges: Bool {
        !redeemingPerkIDs.isEmpty
            || !savingPerkIDs.isEmpty
            || !completingSurveyIDs.isEmpty
            || !startingPartnerSurveyIDs.isEmpty
            || hasPendingPreferenceSync
    }

    private var pendingSyncMessage: String {
        var parts = [String]()

        if !savingPerkIDs.isEmpty {
            parts.append("\(savingPerkIDs.count) saved perk \(savingPerkIDs.count == 1 ? "change" : "changes")")
        }

        if !redeemingPerkIDs.isEmpty {
            parts.append("\(redeemingPerkIDs.count) redemption \(redeemingPerkIDs.count == 1 ? "change" : "changes")")
        }

        if !completingSurveyIDs.isEmpty {
            parts.append("\(completingSurveyIDs.count) survey \(completingSurveyIDs.count == 1 ? "submission" : "submissions")")
        }

        if !startingPartnerSurveyIDs.isEmpty {
            parts.append("\(startingPartnerSurveyIDs.count) partner survey \(startingPartnerSurveyIDs.count == 1 ? "start" : "starts")")
        }

        if hasPendingPreferenceSync {
            parts.append("preference changes")
        }

        guard !parts.isEmpty else {
            return "All local changes are synced."
        }

        let summary = parts.joined(separator: ", ")

        if backendState == .failed {
            return "\(summary) waiting for connection."
        }

        return "\(summary) syncing in the background."
    }

    private var syncQueueStatus: String {
        hasPendingSyncChanges ? "Pending" : "Clear"
    }

    private var isDataStale: Bool {
        guard backendState == .connected,
              let lastBootstrapSync else {
            return false
        }

        return Date().timeIntervalSince(lastBootstrapSync) > 3_600
    }

    private var dataFreshnessStatus: String {
        isDataStale ? "Stale" : "Current"
    }

    @ViewBuilder
    private var syncStatusBanner: some View {
        if hasPendingSyncChanges {
            if backendState == .failed {
                SyncStatusBanner(
                    iconName: "arrow.triangle.2.circlepath",
                    title: "Sync waiting",
                    message: pendingSyncMessage,
                    isLoading: false,
                    actionTitle: "Retry sync",
                    action: retryPendingSync
                )
            } else {
                SyncStatusBanner(
                    iconName: "arrow.triangle.2.circlepath",
                    title: "Sync pending",
                    message: pendingSyncMessage,
                    isLoading: true,
                    actionTitle: nil,
                    action: nil
                )
            }
        } else {
            switch backendState {
            case .loading:
                SyncStatusBanner(
                    iconName: backendState.iconName,
                    title: "Syncing",
                    message: "Refreshing your perks and survey activity.",
                    isLoading: isLoadingBootstrap,
                    actionTitle: nil,
                    action: nil
                )
            case .failed:
                SyncStatusBanner(
                    iconName: backendState.iconName,
                    title: "Offline mode",
                    message: backendStatusDetail,
                    isLoading: isLoadingBootstrap,
                    actionTitle: "Retry",
                    action: retryBootstrap
                )
            case .connected where isDataStale:
                SyncStatusBanner(
                    iconName: "clock.badge.exclamationmark",
                    title: "Refresh recommended",
                    message: "Perks last refreshed \(lastSyncStatus). Pull to refresh or retry sync to get the latest offers.",
                    isLoading: isLoadingBootstrap,
                    actionTitle: "Refresh",
                    action: retryBootstrap
                )
            case .notConfigured, .connected:
                EmptyView()
            }
        }
    }

    private func redeem(_ perk: Perk) {
        guard !perk.isExpired,
              !redeemedPerkIDs.contains(perk.id),
              !redeemingPerkIDs.contains(perk.id) else {
            return
        }

        redeemingPerkIDs.insert(perk.id)
        let previousValue = redeemedPerkIDsValue

        var ids = redeemedPerkIDs
        ids.insert(perk.id)
        redeemedPerkIDsValue = encodedIDs(ids)
        cacheActivity()

        enqueueActivitySync {
            let didSync = await syncActivity {
                try await $0.redeemPerk(id: perk.id)
            }

            if !didSync {
                redeemedPerkIDsValue = previousValue
                cacheActivity()
            }

            redeemingPerkIDs.remove(perk.id)
        }
    }

    private func toggleSaved(_ perk: Perk) {
        guard !savingPerkIDs.contains(perk.id) else {
            return
        }

        savingPerkIDs.insert(perk.id)
        let previousValue = savedPerkIDsValue

        var ids = savedPerkIDs
        let isSaved: Bool

        if ids.contains(perk.id) {
            ids.remove(perk.id)
            isSaved = false
        } else {
            ids.insert(perk.id)
            isSaved = true
        }

        savedPerkIDsValue = encodedIDs(ids)
        cacheActivity()

        enqueueActivitySync {
            let didSync = await syncActivity {
                try await $0.savePerk(id: perk.id, isSaved: isSaved)
            }

            if !didSync {
                savedPerkIDsValue = previousValue
                cacheActivity()
            }

            savingPerkIDs.remove(perk.id)
        }
    }

    private func requestOpenOffer(_ perk: Perk) {
        guard !perk.isExpired,
              perk.offerURL != nil else {
            return
        }

        pendingOfferToOpen = perk
        isConfirmingOpenOffer = true
    }

    private func openOffer(_ perk: Perk) {
        guard !perk.isExpired,
              let offerURL = perk.offerURL else {
            pendingOfferToOpen = nil
            return
        }

        pendingOfferToOpen = nil
        openURL(offerURL)
        offerClickCount += 1
        recordOfferClick(perk)
        cacheActivity()

        Task {
            do {
                try await performAuthenticatedRequest { backend in
                    try await backend.trackOfferClick(perkID: perk.id, offerURL: offerURL)
                }
                backendState = .connected
                backendStatusDetail = "Offer click tracked"
            } catch {
                backendState = .failed
                backendStatusDetail = error.localizedDescription
            }
        }
    }

    private var openOfferConfirmationMessage: String {
        guard let pendingOfferToOpen,
              let offerURL = pendingOfferToOpen.offerURL else {
            return "You are about to leave RewardLoop."
        }

        let host = offerURL.host() ?? "the partner site"
        return "You are leaving RewardLoop for \(host). \(pendingOfferToOpen.offerKind.disclosure)"
    }

    private func completeSurvey(_ survey: Survey, responses: [SurveyAnswerRequest]) {
        guard !completedSurveyIDs.contains(survey.id),
              !completingSurveyIDs.contains(survey.id) else {
            return
        }

        completingSurveyIDs.insert(survey.id)
        let previousValue = completedSurveyIDsValue

        var ids = completedSurveyIDs
        ids.insert(survey.id)
        completedSurveyIDsValue = encodedIDs(ids)
        cacheActivity()

        enqueueActivitySync {
            let didSync = await syncActivity {
                try await $0.completeSurvey(id: survey.id, responses: responses)
            }

            if !didSync {
                completedSurveyIDsValue = previousValue
                cacheActivity()
            }

            completingSurveyIDs.remove(survey.id)
        }
    }

    private func recordOfferClick(_ perk: Perk) {
        offerClickHistory.insert(
            OfferClickHistoryEntry(
                perkID: perk.id,
                perkTitle: perk.title,
                partner: perk.partner,
                offerKind: perk.offerKind
            ),
            at: 0
        )

        if offerClickHistory.count > 12 {
            offerClickHistory = Array(offerClickHistory.prefix(12))
        }
    }

    private func clearOfferHistory() {
        offerClickCount = 0
        offerClickHistory = []
        diagnosticsStatusMessage = nil
        cacheActivity()
    }

    private func copyDiagnostics() {
        let diagnostics = [
            "RewardLoop diagnostics",
            "Data source: \(backendState.title)",
            "Backend status: \(backendStatusDetail)",
            "Data freshness: \(dataFreshnessStatus)",
            "Last refresh: \(lastSyncStatus)",
            "Backend host: \(backendHost)",
            "Sync queue: \(syncQueueStatus)",
            "Partner survey source: \(partnerSurveyState.title)",
            "Saved perks: \(savedPerks.count)",
            "Redeemed perks: \(redeemedPerks.count)",
            "Completed surveys: \(completedSurveyIDs.count)",
            "Completed partner surveys: \(completedPartnerSurveySessions.count)",
            "Completed partner survey points: \(completedPartnerSurveyPoints)",
            "Offer clicks: \(offerClickCount)",
            "Active perks: \(perks.count)",
            "Available surveys: \(availableSurveys.count)",
            "Partner surveys: \(partnerSurveyOffers.count)",
            "Partner survey status: \(partnerSurveyStatusMessage)"
        ]
        .joined(separator: "\n")

        #if canImport(UIKit)
        UIPasteboard.general.string = diagnostics
        diagnosticsStatusMessage = "Diagnostics copied. No access tokens or API keys were included."
        #else
        diagnosticsStatusMessage = "Copy diagnostics is unavailable on this device."
        #endif
    }

    private func toggleInterest(_ interest: Interest) {
        var ids = selectedInterestIDs

        if ids.contains(interest.id) {
            ids.remove(interest.id)
        } else {
            ids.insert(interest.id)
        }

        selectedInterestIDsValue = encodedIDs(ids)
        syncPreferences()
    }

    private func loadBootstrap() async {
        guard !isLoadingBootstrap else {
            return
        }

        isLoadingBootstrap = true
        defer {
            isLoadingBootstrap = false
        }

        backendState = .loading
        backendStatusDetail = "Loading Supabase data"

        do {
            let localActivitySnapshot = currentActivityResponse
            let response = try await performAuthenticatedRequest { backend in
                try await backend.fetchBootstrap()
            }
            let mergedActivity = response.activity.mergedWithLocalSnapshot(
                localActivitySnapshot,
                localModifiedAt: localActivityModifiedAt
            )
            store = RewardLoopStore(response: response)
            UserBootstrapCache.save(response, userID: authSession.userID)
            applyActivity(mergedActivity)

            if mergedActivity != response.activity {
                let syncedActivity = try await performAuthenticatedRequest { backend in
                    try await backend.syncActivity(mergedActivity)
                }
                applyActivity(syncedActivity)
            }

            backendState = .connected
            backendStatusDetail = "Connected as \(activeAuthSession.userID)"
            lastBootstrapSync = Date()
        } catch {
            backendState = .failed
            backendStatusDetail = error.localizedDescription
        }
    }

    private func refreshAppData() async {
        await loadBootstrap()
        await loadPartnerSurveyOffers()
    }

    private func loadPartnerSurveyOffers() async {
        guard !isLoadingPartnerSurveys else {
            return
        }

        isLoadingPartnerSurveys = true
        defer {
            isLoadingPartnerSurveys = false
        }

        do {
            async let offerResponses = performAuthenticatedRequest { backend in
                try await backend.fetchPartnerSurveyOffers()
            }
            async let sessionResponses = performAuthenticatedRequest { backend in
                try await backend.fetchPartnerSurveySessions()
            }

            partnerSurveyOffers = try await offerResponses.compactMap(PartnerSurveyOffer.init(response:))
            partnerSurveySessions = try await sessionResponses.compactMap(PartnerSurveySession.init(response:))
            if partnerSurveyOffers.isEmpty {
                partnerSurveyState = .empty
                partnerSurveyStatusMessage = "No partner surveys are available right now."
            } else {
                partnerSurveyState = .connected
                partnerSurveyStatusMessage = "\(partnerSurveyOffers.count) partner \(partnerSurveyOffers.count == 1 ? "survey" : "surveys") available."
            }
        } catch {
            partnerSurveyOffers = []
            partnerSurveySessions = []
            partnerSurveyState = .unavailable
            partnerSurveyStatusMessage = "Partner surveys are waiting on provider setup."
        }
    }

    private func requestStartPartnerSurvey(_ offer: PartnerSurveyOffer) {
        guard !startingPartnerSurveyIDs.contains(offer.id) else {
            return
        }

        pendingPartnerSurvey = offer
        isConfirmingPartnerSurvey = true
    }

    private func startPartnerSurvey(_ offer: PartnerSurveyOffer) {
        guard !startingPartnerSurveyIDs.contains(offer.id) else {
            return
        }

        pendingPartnerSurvey = nil
        startingPartnerSurveyIDs.insert(offer.id)

        Task {
            do {
                let session = try await performAuthenticatedRequest { backend in
                    try await backend.startPartnerSurvey(offerID: offer.id)
                }
                guard let entryURL = URL.supportedOfferURL(from: session.entryURL) else {
                    throw RewardLoopAPIError.invalidURL
                }

                if let mappedSession = PartnerSurveySession(response: session) {
                    partnerSurveySessions.removeAll { $0.id == mappedSession.id }
                    partnerSurveySessions.insert(mappedSession, at: 0)
                }

                openURL(entryURL)
                isAwaitingPartnerSurveyReturn = true
                partnerSurveyState = .connected
                partnerSurveyStatusMessage = "Partner survey started."
            } catch {
                partnerSurveyState = .failed
                partnerSurveyStatusMessage = error.localizedDescription
            }

            startingPartnerSurveyIDs.remove(offer.id)
        }
    }

    private var partnerSurveyConfirmationMessage: String {
        guard let pendingPartnerSurvey else {
            return "You are about to open a partner survey."
        }

        let host = pendingPartnerSurvey.entryURL.host() ?? pendingPartnerSurvey.provider.title
        return "You are leaving RewardLoop for \(host). Points are awarded only after the partner confirms completion."
    }

    private func refreshPartnerSurveySessionsAfterReturnIfNeeded() async {
        guard isAwaitingPartnerSurveyReturn || partnerSurveySessions.contains(where: { $0.status == .started }) else {
            return
        }

        await refreshPartnerSurveySessions(statusMessage: "Checking partner survey status.")
    }

    private func refreshPartnerSurveySessions(statusMessage: String? = nil) async {
        guard !isLoadingPartnerSurveys else {
            return
        }

        isLoadingPartnerSurveys = true
        defer {
            isLoadingPartnerSurveys = false
        }

        if let statusMessage {
            partnerSurveyStatusMessage = statusMessage
        }

        do {
            let sessionResponses = try await performAuthenticatedRequest { backend in
                try await backend.fetchPartnerSurveySessions()
            }
            let refreshedSessions = sessionResponses.compactMap(PartnerSurveySession.init(response:))
            let completedCount = refreshedSessions.filter(\.awardsPoints).count

            partnerSurveySessions = refreshedSessions
            isAwaitingPartnerSurveyReturn = refreshedSessions.contains { $0.status == .started }
            partnerSurveyState = partnerSurveyOffers.isEmpty && refreshedSessions.isEmpty ? .empty : .connected
            partnerSurveyStatusMessage = completedCount > 0
                ? "\(completedCount) partner \(completedCount == 1 ? "survey" : "surveys") confirmed."
                : "Partner survey status refreshed."
        } catch {
            partnerSurveyState = .failed
            partnerSurveyStatusMessage = error.localizedDescription
        }
    }

    private func refreshBootstrapIfStale() async {
        guard shouldRefreshBootstrapOnForeground else {
            return
        }

        await refreshAppData()
    }

    private var shouldRefreshBootstrapOnForeground: Bool {
        if backendState == .failed {
            return true
        }

        guard let lastBootstrapSync else {
            return true
        }

        return Date().timeIntervalSince(lastBootstrapSync) > 300
    }

    private func syncPreferences(debounce: Bool = true) {
        cacheActivity()
        hasPendingPreferenceSync = true
        preferenceSyncTask?.cancel()

        preferenceSyncTask = Task {
            if debounce {
                do {
                    try await Task.sleep(nanoseconds: 350_000_000)
                } catch {
                    return
                }
            }

            enqueueActivitySync {
                let didSync = await syncActivity { backend in
                    try await backend.updatePreferences(
                        PreferencesUpdateRequest(
                            selectedInterestIDs: Array(selectedInterestIDs).sorted(),
                            weeklyDigestEnabled: weeklyDigestEnabled,
                            nearbyPerksEnabled: nearbyPerksEnabled
                        )
                    )
                }

                if didSync {
                    hasPendingPreferenceSync = false
                }
            }
        }
    }

    private func signOutUser() {
        preferenceSyncTask?.cancel()
        preferenceSyncTask = nil
        hasPendingPreferenceSync = false
        activitySyncTask?.cancel()
        activitySyncTask = nil
        UserLocalDataStore.clearAll(userID: authSession.userID)
        signOut()
    }

    private func enqueueActivitySync(_ operation: @escaping () async -> Void) {
        let previousTask = activitySyncTask

        activitySyncTask = Task {
            await previousTask?.value

            guard !Task.isCancelled else {
                return
            }

            await operation()
        }
    }

    private func retryBootstrap() {
        Task {
            await refreshAppData()
        }
    }

    private func retryPendingSync() {
        if hasPendingPreferenceSync {
            syncPreferences(debounce: false)
        } else {
            retryBootstrap()
        }
    }

    private func flushPendingChangesForSuspension() {
        cacheActivity()

        guard hasPendingPreferenceSync else {
            return
        }

        syncPreferences(debounce: false)
    }

    private func openNotification(_ notification: PulseNotification) {
        switch notification.destination {
        case .surveys:
            selectedTab = .surveys
        case .wallet:
            selectedTab = .wallet
        case .account:
            selectedTab = .account
        }

        isShowingNotifications = false
    }

    private func performAuthenticatedRequest<Response>(
        _ operation: (RewardLoopBackend) async throws -> Response
    ) async throws -> Response {
        try await refreshActiveSessionIfNeeded()

        do {
            return try await performRetriableBackendOperation(operation)
        } catch let error as RewardLoopAPIError where error.isAuthenticationFailure {
            try await refreshActiveSessionIfNeeded(force: true)
            return try await performRetriableBackendOperation(operation)
        }
    }

    private func performRetriableBackendOperation<Response>(
        _ operation: (RewardLoopBackend) async throws -> Response
    ) async throws -> Response {
        do {
            return try await operation(backend)
        } catch let error as RewardLoopAPIError where error.isTransientFailure {
            try await Task.sleep(nanoseconds: 300_000_000)
            return try await operation(backend)
        }
    }

    @discardableResult
    private func refreshActiveSessionIfNeeded(force: Bool = false) async throws -> AuthSession {
        guard force || activeAuthSession.shouldRefresh else {
            return activeAuthSession
        }

        let refreshedSession = try await refreshSession(force)
        activeAuthSession = refreshedSession
        return refreshedSession
    }

    @discardableResult
    private func syncActivity(
        _ operation: (RewardLoopBackend) async throws -> MemberActivityResponse
    ) async -> Bool {
        do {
            let activity = try await performAuthenticatedRequest(operation)
            applyActivity(activity)
            backendState = .connected
            backendStatusDetail = "Synced \(Date.now.formatted(date: .omitted, time: .shortened))"
            return true
        } catch {
            backendState = .failed
            backendStatusDetail = error.localizedDescription
            return false
        }
    }

    @discardableResult
    private func updateProfile(_ request: ProfileUpdateRequest) async -> Bool {
        do {
            let response = try await performAuthenticatedRequest { backend in
                try await backend.updateProfile(request)
            }
            store = RewardLoopStore(
                memberProfile: MemberProfile(response: response),
                categories: categories,
                perks: perks,
                collections: collections,
                surveys: surveys,
                interests: interests,
                basePoints: basePoints,
                pointsPerRedemption: pointsPerRedemption,
                nextRewardPoints: nextRewardPoints,
                dailySurveyGoal: dailySurveyGoal
            )
            UserBootstrapCache.updateProfile(response, userID: authSession.userID)
            backendState = .connected
            backendStatusDetail = "Profile updated"
            return true
        } catch {
            backendState = .failed
            backendStatusDetail = error.localizedDescription
            return false
        }
    }

    private func applyActivity(_ activity: MemberActivityResponse) {
        let mergedActivity = activity.normalized.mergedWithLocalSnapshot(
            currentActivityResponse,
            localModifiedAt: localActivityModifiedAt
        )

        savedPerkIDsValue = encodedIDs(mergedSavedPerkIDs(from: mergedActivity))
        redeemedPerkIDsValue = encodedIDs(Set(mergedActivity.redeemedPerkIDs).union(redeemingPerkIDs))
        completedSurveyIDsValue = encodedIDs(Set(mergedActivity.completedSurveyIDs).union(completingSurveyIDs))

        if !hasPendingPreferenceSync {
            selectedInterestIDsValue = encodedIDs(Set(mergedActivity.selectedInterestIDs))
            weeklyDigestEnabled = mergedActivity.weeklyDigestEnabled
            nearbyPerksEnabled = mergedActivity.nearbyPerksEnabled
        }

        cacheActivity(modifiedAt: mergedActivity.serverUpdatedAt ?? localActivityModifiedAt ?? Date())
        UserBootstrapCache.updateActivity(currentActivityResponse, userID: authSession.userID)
    }

    private func mergedSavedPerkIDs(from activity: MemberActivityResponse) -> Set<String> {
        var ids = Set(activity.savedPerkIDs)
        let localIDs = savedPerkIDs

        for perkID in savingPerkIDs {
            if localIDs.contains(perkID) {
                ids.insert(perkID)
            } else {
                ids.remove(perkID)
            }
        }

        return ids
    }

    private var currentActivityResponse: MemberActivityResponse {
        MemberActivityResponse(
            savedPerkIDs: Array(savedPerkIDs).sorted(),
            redeemedPerkIDs: Array(redeemedPerkIDs).sorted(),
            completedSurveyIDs: Array(completedSurveyIDs).sorted(),
            selectedInterestIDs: Array(selectedInterestIDs).sorted(),
            weeklyDigestEnabled: weeklyDigestEnabled,
            nearbyPerksEnabled: nearbyPerksEnabled
        )
    }

    private func cacheActivity(modifiedAt: Date = Date()) {
        localActivityModifiedAt = modifiedAt
        UserActivityCache(
            redeemedPerkIDsValue: redeemedPerkIDsValue,
            savedPerkIDsValue: savedPerkIDsValue,
            completedSurveyIDsValue: completedSurveyIDsValue,
            selectedInterestIDsValue: selectedInterestIDsValue,
            weeklyDigestEnabled: weeklyDigestEnabled,
            nearbyPerksEnabled: nearbyPerksEnabled,
            offerClickCount: offerClickCount,
            offerClickHistory: offerClickHistory,
            modifiedAt: modifiedAt
        )
        .save(userID: authSession.userID)
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

            ProgressView(value: rewardProgress)
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

                Text("+\(totalSurveyPoints) pts earned")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Share product feedback, earn points, and use them toward member rewards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ProgressView(value: dailySurveyGoalProgress)
                .tint(Color(red: 0.1, green: 0.55, blue: 0.42))

            Text("\(min(totalSurveyPoints, dailySurveyGoal)) of \(dailySurveyGoal) daily survey points")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                StatBadge(value: "\(availableSurveys.count)", label: "Available")
                StatBadge(value: "\(completedSurveys.count)", label: "Done")
                StatBadge(value: "\(completedPartnerSurveyPoints)", label: "Partner pts")
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private var partnerSurveysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Partner surveys", systemImage: partnerSurveyState.iconName)
                    .font(.title2.weight(.bold))

                Spacer()

                if isLoadingPartnerSurveys {
                    ProgressView()
                } else {
                    Text("+\(partnerSurveyPotentialPoints) pts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if partnerSurveyOffers.isEmpty {
                Text(partnerSurveyStatusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.stroke(for: colorScheme))
                    )

                if partnerSurveyState.allowsRetry {
                    Button {
                        Task {
                            await loadPartnerSurveyOffers()
                        }
                    } label: {
                        Label("Check again", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoadingPartnerSurveys)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(partnerSurveyOffers) { offer in
                        Button {
                            requestStartPartnerSurvey(offer)
                        } label: {
                            PartnerSurveyOfferRow(
                                offer: offer,
                                isStarting: startingPartnerSurveyIDs.contains(offer.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(startingPartnerSurveyIDs.contains(offer.id))
                    }
                }
            }
        }
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
                    syncStatusBanner
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

                    recentOfferClicks
                    partnerSurveyActivity
                    recentActivity
                }
                .padding(20)
            }
            .refreshable {
                await refreshAppData()
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
                StatBadge(value: "\(offerClickCount)", label: "Clicks")
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

    private var recentOfferClicks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recently opened offers")
                .font(.title2.weight(.bold))

            if offerClickHistory.isEmpty {
                Text("Opened vendor offers will appear here so you can get back to a partner deal quickly.")
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
                    ForEach(offerClickHistory.prefix(5)) { entry in
                        OfferClickActivityRow(entry: entry)
                    }
                }
            }
        }
    }

    private var partnerSurveyActivity: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Partner survey activity")
                .font(.title2.weight(.bold))

            if partnerSurveySessions.isEmpty {
                Text("Started partner surveys and confirmed completions will appear here.")
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
                    ForEach(partnerSurveySessions.prefix(5)) { session in
                        PartnerSurveySessionActivityRow(session: session)
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
                        AccountRow(iconName: "envelope", title: "Signed in", value: activeAuthSession.email)
                        AccountRow(iconName: backendState.iconName, title: "Data source", value: backendState.title)
                        AccountRow(iconName: "info.circle", title: "Backend status", value: backendStatusDetail)
                        AccountRow(iconName: "gauge.with.dots.needle.bottom.50percent", title: "Data freshness", value: dataFreshnessStatus)
                        AccountRow(iconName: "clock", title: "Last refresh", value: lastSyncStatus)
                        AccountRow(iconName: "network", title: "Backend host", value: backendHost)
                        AccountRow(iconName: "arrow.triangle.2.circlepath", title: "Sync queue", value: syncQueueStatus)
                        AccountRow(iconName: "link", title: "Offer clicks", value: offerClickCount.formatted())

                        if hasPendingSyncChanges {
                            AccountStatusRow(iconName: "clock.arrow.circlepath", message: pendingSyncMessage)
                        }

                        if let diagnosticsStatusMessage {
                            AccountStatusRow(iconName: "doc.on.clipboard", message: diagnosticsStatusMessage)
                        }

                        AccountRetryRow(isLoading: isLoadingBootstrap) {
                            Task {
                                await refreshAppData()
                            }
                        }
                        AccountActionRow(iconName: "pencil", title: "Edit profile") {
                            isShowingProfileEditor = true
                        }
                        AccountToggleRow(iconName: "bell", title: "Weekly digest", isOn: weeklyDigestBinding)
                        AccountToggleRow(iconName: "location", title: "Nearby perks", isOn: nearbyPerksBinding)
                        AccountInfoActionRow(iconName: "megaphone", title: "Affiliate disclosure") {
                            isShowingAffiliateDisclosure = true
                        }
                        AccountInfoActionRow(iconName: "hand.raised", title: "Privacy & data") {
                            isShowingPrivacyDisclosure = true
                        }
                        AccountInfoActionRow(iconName: "doc.on.doc", title: "Copy diagnostics") {
                            copyDiagnostics()
                        }
                        AccountActionRow(iconName: "trash", title: "Clear offer history") {
                            isConfirmingClearOfferHistory = true
                        }
                        .disabled(offerClickCount == 0 && offerClickHistory.isEmpty)

                        AccountActionRow(iconName: "rectangle.portrait.and.arrow.right", title: "Sign out") {
                            signOutUser()
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
            .refreshable {
                await refreshAppData()
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

                Text("Member since \(String(memberProfile.memberSinceYear))")
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

private enum BackendState {
    case notConfigured
    case loading
    case connected
    case failed

    var title: String {
        switch self {
        case .notConfigured:
            "Demo"
        case .loading:
            "Syncing"
        case .connected:
            "Supabase"
        case .failed:
            "Offline"
        }
    }

    var iconName: String {
        switch self {
        case .notConfigured:
            "tray"
        case .loading:
            "arrow.triangle.2.circlepath"
        case .connected:
            "checkmark.icloud"
        case .failed:
            "exclamationmark.icloud"
        }
    }
}

private enum PartnerSurveyConnectionState {
    case loading
    case connected
    case empty
    case unavailable
    case failed

    var title: String {
        switch self {
        case .loading:
            "Loading"
        case .connected:
            "Connected"
        case .empty:
            "No inventory"
        case .unavailable:
            "Awaiting provider setup"
        case .failed:
            "Start failed"
        }
    }

    var iconName: String {
        switch self {
        case .loading:
            "arrow.triangle.2.circlepath"
        case .connected:
            "checkmark.seal"
        case .empty:
            "tray"
        case .unavailable:
            "hourglass"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    var allowsRetry: Bool {
        switch self {
        case .unavailable, .failed:
            true
        case .loading, .connected, .empty:
            false
        }
    }
}

private struct SyncStatusBanner: View {
    let iconName: String
    let title: String
    let message: String
    let isLoading: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(AppTheme.controlBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

private struct UserActivityCache: Codable {
    let redeemedPerkIDsValue: String
    let savedPerkIDsValue: String
    let completedSurveyIDsValue: String
    let selectedInterestIDsValue: String
    let weeklyDigestEnabled: Bool
    let nearbyPerksEnabled: Bool
    let offerClickCount: Int
    let offerClickHistory: [OfferClickHistoryEntry]
    let modifiedAt: Date?

    init(
        redeemedPerkIDsValue: String,
        savedPerkIDsValue: String,
        completedSurveyIDsValue: String,
        selectedInterestIDsValue: String,
        weeklyDigestEnabled: Bool,
        nearbyPerksEnabled: Bool,
        offerClickCount: Int,
        offerClickHistory: [OfferClickHistoryEntry],
        modifiedAt: Date?
    ) {
        self.redeemedPerkIDsValue = redeemedPerkIDsValue
        self.savedPerkIDsValue = savedPerkIDsValue
        self.completedSurveyIDsValue = completedSurveyIDsValue
        self.selectedInterestIDsValue = selectedInterestIDsValue
        self.weeklyDigestEnabled = weeklyDigestEnabled
        self.nearbyPerksEnabled = nearbyPerksEnabled
        self.offerClickCount = offerClickCount
        self.offerClickHistory = offerClickHistory
        self.modifiedAt = modifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        redeemedPerkIDsValue = try container.decode(String.self, forKey: .redeemedPerkIDsValue)
        savedPerkIDsValue = try container.decode(String.self, forKey: .savedPerkIDsValue)
        completedSurveyIDsValue = try container.decode(String.self, forKey: .completedSurveyIDsValue)
        selectedInterestIDsValue = try container.decode(String.self, forKey: .selectedInterestIDsValue)
        weeklyDigestEnabled = try container.decode(Bool.self, forKey: .weeklyDigestEnabled)
        nearbyPerksEnabled = try container.decode(Bool.self, forKey: .nearbyPerksEnabled)
        offerClickCount = try container.decodeIfPresent(Int.self, forKey: .offerClickCount) ?? 0
        offerClickHistory = try container.decodeIfPresent([OfferClickHistoryEntry].self, forKey: .offerClickHistory) ?? []
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
    }

    static func load(userID: String) -> UserActivityCache {
        guard
            let data = UserDefaults.standard.data(forKey: key(for: userID)),
            let cache = try? JSONDecoder().decode(UserActivityCache.self, from: data)
        else {
            return .default
        }

        return cache
    }

    func save(userID: String) {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }

        UserDefaults.standard.set(data, forKey: Self.key(for: userID))
    }

    static func clear(userID: String) {
        UserDefaults.standard.removeObject(forKey: key(for: userID))
    }

    private static func key(for userID: String) -> String {
        "userActivity.\(userID)"
    }

    static var `default`: UserActivityCache {
        UserActivityCache(
            redeemedPerkIDsValue: "",
            savedPerkIDsValue: "",
            completedSurveyIDsValue: "",
            selectedInterestIDsValue: "shopping,wellness",
            weeklyDigestEnabled: true,
            nearbyPerksEnabled: true,
            offerClickCount: 0,
            offerClickHistory: [],
            modifiedAt: nil
        )
    }
}

private struct UserBootstrapCache: Codable {
    let response: RewardLoopBootstrapResponse
    let cachedAt: Date

    static func load(userID: String) -> UserBootstrapCache? {
        guard
            let data = UserDefaults.standard.data(forKey: key(for: userID)),
            let cache = try? JSONDecoder().decode(UserBootstrapCache.self, from: data)
        else {
            return nil
        }

        return cache
    }

    static func save(_ response: RewardLoopBootstrapResponse, userID: String) {
        let cache = UserBootstrapCache(response: response, cachedAt: Date())
        save(cache, userID: userID)
    }

    static func updateProfile(_ profile: MemberProfileResponse, userID: String) {
        guard let cache = load(userID: userID) else {
            return
        }

        let updatedResponse = RewardLoopBootstrapResponse(
            member: profile,
            rewards: cache.response.rewards,
            categories: cache.response.categories,
            perks: cache.response.perks,
            collections: cache.response.collections,
            surveys: cache.response.surveys,
            interests: cache.response.interests,
            activity: cache.response.activity
        )
        save(UserBootstrapCache(response: updatedResponse, cachedAt: Date()), userID: userID)
    }

    static func updateActivity(_ activity: MemberActivityResponse, userID: String) {
        guard let cache = load(userID: userID) else {
            return
        }

        let updatedResponse = RewardLoopBootstrapResponse(
            member: cache.response.member,
            rewards: cache.response.rewards,
            categories: cache.response.categories,
            perks: cache.response.perks,
            collections: cache.response.collections,
            surveys: cache.response.surveys,
            interests: cache.response.interests,
            activity: activity
        )
        save(UserBootstrapCache(response: updatedResponse, cachedAt: Date()), userID: userID)
    }

    private static func save(_ cache: UserBootstrapCache, userID: String) {
        guard let data = try? JSONEncoder().encode(cache) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(for: userID))
    }

    static func clear(userID: String) {
        UserDefaults.standard.removeObject(forKey: key(for: userID))
    }

    private static func key(for userID: String) -> String {
        "userBootstrap.\(userID)"
    }
}

private struct EditProfileView: View {
    let profile: MemberProfile
    let save: (ProfileUpdateRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name: String
    @State private var isSaving = false
    @State private var statusMessage: String?

    init(profile: MemberProfile, save: @escaping (ProfileUpdateRequest) async -> Bool) {
        self.profile = profile
        self.save = save
        _name = State(initialValue: profile.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .onChange(of: name) {
                            statusMessage = nil
                        }

                    LabeledContent("Membership", value: profile.tier)
                    LabeledContent("Member code", value: profile.memberCode)
                }

                if let statusMessage {
                    Section {
                        Label(statusMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 0.73, green: 0.26, blue: 0.18))
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        isSaving = true
                        statusMessage = nil

                        Task {
                            let didSave = await save(
                                ProfileUpdateRequest(
                                    name: trimmedName,
                                    tier: profile.tier,
                                    memberCode: profile.memberCode,
                                    memberSinceYear: profile.memberSinceYear
                                )
                            )

                            isSaving = false

                            if didSave {
                                dismiss()
                            } else {
                                statusMessage = "Could not save profile. Check your connection and try again."
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground(for: colorScheme))
            .interactiveDismissDisabled(isSaving)
        }
    }
}

#Preview {
    ContentView(
        configuration: SupabaseConfiguration(
            projectURL: URL(string: "https://example.supabase.co")!,
            anonKey: "anon-key",
            memberID: "preview-member",
            accessToken: "access-token",
            memberName: "Emanuil"
        ),
        authSession: AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            userID: "preview-member",
            email: "emanuil@example.com",
            displayName: "Emanuil",
            expiresAt: Date().addingTimeInterval(3600),
            needsOnboarding: false
        ),
        refreshSession: { _ in
            AuthSession(
                accessToken: "access-token",
                refreshToken: "refresh-token",
                userID: "preview-member",
                email: "emanuil@example.com",
                displayName: "Emanuil",
                expiresAt: Date().addingTimeInterval(3600),
                needsOnboarding: false
            )
        },
        signOut: {}
    )
}
