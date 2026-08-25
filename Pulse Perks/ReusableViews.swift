//
//  ReusableViews.swift
//  RewardLoop
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private let maximumSurveyAnswerLength = 500

struct StatBadge: View {
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

struct MembershipCard: View {
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
                        .foregroundStyle(AppTheme.accent)

                    Text(memberName)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
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

struct BarcodeView: View {
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

struct RecommendedPerkCard: View {
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
                        .foregroundStyle(AppTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                OfferKindBadge(offerKind: perk.offerKind)

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

struct OfferKindBadge: View {
    let offerKind: OfferKind

    var body: some View {
        Label(offerKind.title, systemImage: iconName)
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppTheme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(AppTheme.accent.opacity(0.10), in: Capsule())
            .accessibilityLabel(offerKind.title)
    }

    private var iconName: String {
        switch offerKind {
        case .affiliate:
            "link"
        case .sponsored:
            "megaphone"
        case .promoCode:
            "qrcode"
        case .direct:
            "arrow.up.forward.app"
        }
    }
}

struct PerkCollectionCard: View {
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

struct SurveyRow: View {
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
                        .foregroundStyle(AppTheme.accent)
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
                    .foregroundStyle(isCompleted ? .secondary : AppTheme.accent)
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

struct SurveyDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let survey: Survey
    let isCompleted: Bool
    let isCompleting: Bool
    let matchScore: Int
    let matchReason: String
    let complete: ([SurveyAnswerRequest]) -> Void

    @State private var responses: [String: String] = [:]

    private var answeredCount: Int {
        survey.questions.filter { question in
            !(responses[question] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .count
    }

    private var canComplete: Bool {
        isCompleted || (!isCompleting && answeredCount == survey.questions.count && !hasOversizedResponses)
    }

    private var hasOversizedResponses: Bool {
        responses.values.contains { $0.count > maximumSurveyAnswerLength }
    }

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
                        HStack {
                            Text(isCompleted ? "Responses" : "Answer survey")
                                .font(.headline)

                            Spacer()

                            Text("\(answeredCount)/\(survey.questions.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(Array(survey.questions.enumerated()), id: \.offset) { index, question in
                            SurveyQuestionField(
                                index: index + 1,
                                question: question,
                                response: Binding(
                                    get: { responses[question, default: ""] },
                                    set: { responses[question] = $0 }
                                ),
                                isCompleted: isCompleted,
                                maximumLength: maximumSurveyAnswerLength
                            )
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
                    complete(answerRequests)
                } label: {
                    HStack {
                        if isCompleting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "paperplane.fill")
                        }

                        Text(isCompleted ? "Points awarded" : isCompleting ? "Submitting" : "Submit answers")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        isCompleted
                            ? Color.gray
                            : AppTheme.accent,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .disabled(!canComplete || isCompleted || isCompleting)
                .padding(20)
                .background(.regularMaterial)
            }
        }
    }

    private var answerRequests: [SurveyAnswerRequest] {
        survey.questions.enumerated().map { index, question in
            SurveyAnswerRequest(
                questionIndex: index + 1,
                question: question,
                answer: (responses[question] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

struct SurveyQuestionField: View {
    let index: Int
    let question: String
    @Binding var response: String
    let isCompleted: Bool
    let maximumLength: Int

    private var isOverLimit: Bool {
        response.count > maximumLength
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SurveyQuestionPreview(index: index, question: question)

            TextField("Your answer", text: $response, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .disabled(isCompleted)
                .padding(12)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Text(isOverLimit ? "Answer is too long" : "\(maximumLength - response.count) characters remaining")
                    .foregroundStyle(isOverLimit ? Color(red: 0.73, green: 0.26, blue: 0.18) : .secondary)

                Spacer()

                Text("\(response.count)/\(maximumLength)")
                    .foregroundStyle(isOverLimit ? Color(red: 0.73, green: 0.26, blue: 0.18) : .secondary)
            }
            .font(.caption.weight(.semibold))
        }
    }
}

struct SurveyQuestionPreview: View {
    let index: Int
    let question: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.accent, in: Circle())

            Text(question)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

struct SurveyCompletionView: View {
    @Environment(\.colorScheme) private var colorScheme

    let points: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)

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
                .stroke(AppTheme.accent.opacity(0.18))
        )
    }
}

struct PartnerSurveyOfferRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let offer: PartnerSurveyOffer
    let isStarting: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "globe.badge.chevron.backward")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 44, height: 44)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(offer.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text("+\(offer.rewardPoints) pts")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                }

                Text(offer.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        partnerSurveyMetaLabel(offer.provider.title, systemImage: "building.2")
                        partnerSurveyMetaLabel(offer.estimatedTime, systemImage: "clock")
                        partnerSurveyMetaLabel("\(offer.matchScore)% match", systemImage: "scope")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        partnerSurveyMetaLabel(offer.provider.title, systemImage: "building.2")
                        partnerSurveyMetaLabel(offer.estimatedTime, systemImage: "clock")
                        partnerSurveyMetaLabel("\(offer.matchScore)% match", systemImage: "scope")
                    }
                }

                HStack {
                    Label(offer.category, systemImage: "tag")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if isStarting {
                        ProgressView()
                    } else {
                        Label("Start", systemImage: "arrow.up.forward.app")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private func partnerSurveyMetaLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.88)
    }
}

struct PartnerSurveySessionActivityRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let session: PartnerSurveySession

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.status.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 44, height: 44)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.provider.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(pointsText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusColor)
                }

                Text(session.status.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let activityDate {
                    Text(activityDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private var pointsText: String {
        session.awardsPoints ? "+\(session.rewardPoints) pts" : "Pending"
    }

    private var activityDate: Date? {
        session.completedAt ?? session.startedAt
    }

    private var statusColor: Color {
        switch session.status {
        case .completed:
            AppTheme.accent
        case .started:
            Color(red: 0.15, green: 0.38, blue: 0.73)
        case .screenedOut, .quotaFull:
            Color(red: 0.58, green: 0.45, blue: 0.18)
        case .failed:
            Color(red: 0.75, green: 0.22, blue: 0.18)
        }
    }
}

struct PerkRow: View {
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

                    Text(statusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Text(perk.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(perk.expiration)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(perk.isExpired ? .secondary : AppTheme.accent)

                HStack(spacing: 10) {
                    Label(perk.distance, systemImage: "location")
                    Label("$\(perk.estimatedSavings) value", systemImage: "dollarsign.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                OfferKindBadge(offerKind: perk.offerKind)
            }

            if isSaved {
                Image(systemName: "bookmark.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
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

    private var statusTitle: String {
        if perk.isExpired {
            return "Expired"
        }

        return isRedeemed ? "Redeemed" : perk.category
    }

    private var statusColor: Color {
        if perk.isExpired {
            return .secondary
        }

        return isRedeemed ? AppTheme.accent : .secondary
    }
}

struct PerkDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let perk: Perk
    let isRedeemed: Bool
    let isSaved: Bool
    let isRedeeming: Bool
    let isSaving: Bool
    let redeem: () -> Void
    let toggleSave: () -> Void
    let openOffer: () -> Void

    @State private var copiedCodeMessage: String?

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

                    if perk.isExpired {
                        ExpiredOfferNotice()
                    } else {
                        RedemptionCodeCard(
                            code: perk.memberCode,
                            instructions: perk.redemptionInstructions,
                            statusMessage: copiedCodeMessage
                        ) {
                            copyMemberCode()
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(iconName: "tag", title: "Category", value: perk.category)
                        DetailRow(iconName: "calendar", title: "Availability", value: perk.expiration)
                        DetailRow(iconName: "location", title: "Distance", value: perk.distance)
                        DetailRow(iconName: "dollarsign.circle", title: "Estimated value", value: "$\(perk.estimatedSavings)")
                        DetailRow(iconName: "megaphone", title: "Offer type", value: perk.offerKind.title)
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
                VStack(spacing: 12) {
                    if perk.offerURL != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                openOffer()
                            } label: {
                                Label("Open offer", systemImage: "arrow.up.forward.app")
                                    .font(.headline)
                                    .foregroundStyle(perk.isExpired ? .secondary : AppTheme.accent)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .disabled(perk.isExpired)

                            Text(perk.isExpired ? "This partner offer has expired and can no longer be opened from RewardLoop." : perk.offerKind.disclosure)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            toggleSave()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(AppTheme.accent)
                                } else {
                                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 52, height: 52)
                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityLabel(isSaved ? "Remove saved perk" : "Save perk")
                        .disabled(isSaving)

                        Button {
                            redeem()
                        } label: {
                            HStack {
                                if isRedeeming {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: isRedeemed ? "checkmark.circle.fill" : "ticket")
                                }

                                Text(redeemButtonTitle)
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                isRedeemed || perk.isExpired
                                    ? Color.gray
                                    : AppTheme.accent,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .disabled(isRedeemed || isRedeeming || perk.isExpired)
                    }
                }
                .padding(20)
                .background(.regularMaterial)
            }
        }
    }

    private func copyMemberCode() {
        #if canImport(UIKit)
        UIPasteboard.general.string = perk.memberCode
        copiedCodeMessage = "Code copied"
        #else
        copiedCodeMessage = "Copy is unavailable on this device"
        #endif
    }

    private var redeemButtonTitle: String {
        if perk.isExpired {
            return "Expired"
        }

        return isRedeemed ? "Redeemed" : isRedeeming ? "Redeeming" : "Redeem perk"
    }
}

struct ExpiredOfferNotice: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text("Offer expired")
                    .font(.headline)

                Text("This perk is no longer available. Check Discover for current partner offers.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

struct RedemptionCodeCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let code: String
    let instructions: String
    let statusMessage: String?
    let copyCode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Redemption code")
                        .font(.headline)

                    Text(instructions)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Text(code)
                    .font(.system(.title3, design: .monospaced).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(AppTheme.elevatedBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    copyCode()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.elevatedBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("Copy redemption code")
            }

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

struct ActivityRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let perk: Perk

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
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

struct OfferClickActivityRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: OfferClickHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.partner)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(entry.perkTitle) opened \(entry.clickedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            OfferKindBadge(offerKind: entry.offerKind)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }

    private var iconName: String {
        switch entry.offerKind {
        case .affiliate:
            "link.circle.fill"
        case .sponsored:
            "megaphone.fill"
        case .promoCode:
            "qrcode"
        case .direct:
            "arrow.up.forward.circle.fill"
        }
    }
}

struct RedeemedConfirmationView: View {
    @Environment(\.colorScheme) private var colorScheme

    let perk: Perk

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)

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
                .stroke(AppTheme.accent.opacity(0.18))
        )
    }
}

struct DetailRow: View {
    let iconName: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
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

struct AccountRow: View {
    let iconName: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
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

struct AccountToggleRow: View {
    let iconName: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .toggleStyle(.switch)
        .frame(minHeight: 36)
    }
}

struct AccountRetryRow: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28)

                Text("Retry sync")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct AccountStatusRow: View {
    let iconName: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

struct AccountInfoActionRow: View {
    let iconName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
    }
}

struct AccountActionRow: View {
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

struct AffiliateDisclosureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    DisclosureInfoCard(
                        iconName: "link",
                        title: "Partner links",
                        message: "Some offers open a partner website or app. RewardLoop may earn money when you click, sign up, buy, or redeem through those partner offers."
                    )

                    DisclosureInfoCard(
                        iconName: "megaphone",
                        title: "Sponsored placements",
                        message: "Some offers may be paid placements. Sponsored status does not change the member price shown in RewardLoop."
                    )

                    DisclosureInfoCard(
                        iconName: "chart.line.uptrend.xyaxis",
                        title: "Click tracking",
                        message: "RewardLoop records offer clicks to measure which partners and categories are useful. Your recent opened offers also appear in Wallet for convenience."
                    )

                    DisclosureInfoCard(
                        iconName: "checkmark.seal",
                        title: "Offer terms",
                        message: "Partner terms, eligibility, prices, and availability can change. Always review the partner checkout page before completing a purchase."
                    )
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Disclosure")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("Affiliate disclosure")
                .font(.largeTitle.weight(.bold))

            Text("RewardLoop connects members with partner offers. This page explains how those links may support the app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct PrivacyDisclosureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    DisclosureInfoCard(
                        iconName: "person.text.rectangle",
                        title: "Account data",
                        message: "RewardLoop uses your email, display name, membership profile, selected interests, saved perks, redeemed perks, and completed surveys to personalize rewards and keep your wallet in sync."
                    )

                    DisclosureInfoCard(
                        iconName: "link",
                        title: "Offer activity",
                        message: "When you open a partner offer, RewardLoop records the perk and destination URL for partner reporting. A shorter recent-offer history is also saved on this device for convenience."
                    )

                    DisclosureInfoCard(
                        iconName: "list.clipboard",
                        title: "Survey responses",
                        message: "Survey answers are submitted to the backend so RewardLoop can award points, avoid duplicate submissions, and understand member preferences."
                    )

                    DisclosureInfoCard(
                        iconName: "externaldrive",
                        title: "Local data",
                        message: "RewardLoop stores recent activity and cached app data on this device so the app can keep working during poor connectivity. Signing out clears user-scoped local cache."
                    )

                    DisclosureInfoCard(
                        iconName: "doc.on.clipboard",
                        title: "Diagnostics",
                        message: "Copied diagnostics include sync status and counts that help troubleshoot issues. They do not include access tokens, API keys, anon keys, or raw user IDs."
                    )
                }
                .padding(20)
            }
            .background(AppTheme.pageBackground(for: colorScheme))
            .navigationTitle("Privacy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("Privacy & data")
                .font(.largeTitle.weight(.bold))

            Text("RewardLoop uses account, reward, survey, and partner-offer activity to run the member experience.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct DisclosureInfoCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let iconName: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.stroke(for: colorScheme))
        )
    }
}

struct InterestChip: View {
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
                    ? AppTheme.accent
                    : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

struct NotificationsView: View {
    let notifications: [PulseNotification]
    let selectNotification: (PulseNotification) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(notifications) { notification in
                Button {
                    selectNotification(notification)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: notification.iconName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(notification.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Text(notification.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Label(notification.actionTitle, systemImage: "arrow.right.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                                .padding(.top, 2)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
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
