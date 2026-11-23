import StoreKit
import SwiftUI

/// Two plans, nothing else (screens.md → Paywall): monthly and annual, prices from the App Store,
/// trial copy only when this Apple ID is still eligible. No `SubscriptionStoreView`, no lifetime row.
struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Product?
    @State private var notice: String?
    @State private var isWorking = false

    private var plans: [Product] {
        [subscriptions.monthly, subscriptions.annual].compactMap { $0 }
    }

    private var activePlan: Product? {
        selected ?? subscriptions.annual ?? subscriptions.monthly
    }

    private var termsURL: URL? { AppConfiguration.string("LEGAL_TERMS_URL").flatMap(URL.init(string:)) }
    private var privacyURL: URL? { AppConfiguration.string("LEGAL_PRIVACY_URL").flatMap(URL.init(string:)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Metric.sectionGap) {
                header
                benefits
                planList
                callToAction
                footer
            }
            .padding(.horizontal, Theme.Metric.screenMargin)
            .padding(.vertical, 24)
        }
        .background(Theme.page)
        .task {
            if subscriptions.products.isEmpty {
                await subscriptions.load()
            }
            if selected == nil { selected = subscriptions.annual ?? subscriptions.monthly }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(String(localized: "common.close", defaultValue: "Close"))
            .padding(.trailing, 4)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "paywall.title", defaultValue: "OffRecord Pro"))
                .font(.largeTitle.bold())
            Text(String(
                localized: "paywall.body",
                defaultValue: "Everything runs on this iPhone. Paying only unlocks your own notes."
            ))
            .font(.body)
            .foregroundStyle(Theme.secondaryLabel)
        }
        .padding(.top, 24)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit("square.stack", String(localized: "paywall.benefit.sessions", defaultValue: "Unlimited sessions and notes"))
            benefit("doc.text", String(localized: "paywall.benefit.templates", defaultValue: "SOAP, DAP, coaching and interview templates"))
            benefit("square.and.arrow.up", String(localized: "paywall.benefit.export", defaultValue: "PDF and Markdown export"))
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var planList: some View {
        if plans.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(subscriptions.errorMessage ?? String(localized: "paywall.error", defaultValue: "Can't reach the App Store."))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                Button(String(localized: "common.retry", defaultValue: "Retry")) {
                    Task { await subscriptions.load() }
                }
                .buttonStyle(.bordered)
            }
        } else {
            VStack(spacing: 12) {
                ForEach(plans, id: \.id) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = activePlan?.id == product.id
        return Button {
            selected = product
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.tertiaryLabel)
                VStack(alignment: .leading, spacing: 2) {
                    Text(planName(product))
                        .font(.headline)
                    Text(planDetail(product))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryLabel)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.grouped, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func planName(_ product: Product) -> String {
        product.id.hasSuffix(".pro.monthly")
            ? String(localized: "paywall.plan.monthly", defaultValue: "Monthly")
            : String(localized: "paywall.plan.annual", defaultValue: "Annual")
    }

    private func planDetail(_ product: Product) -> String {
        let price = product.displayPrice
        if subscriptions.isEligibleForTrial {
            return product.id.hasSuffix(".pro.monthly")
                ? String(format: String(localized: "paywall.plan.monthly.detail", defaultValue: "7 days free, then %@ per month"), price)
                : String(format: String(localized: "paywall.plan.annual.detail", defaultValue: "7 days free, then %@ per year"), price)
        }
        return product.id.hasSuffix(".pro.monthly")
            ? String(format: String(localized: "paywall.plan.monthly.detail.notrial", defaultValue: "Then %@ per month"), price)
            : String(format: String(localized: "paywall.plan.annual.detail.notrial", defaultValue: "Then %@ per year"), price)
    }

    private var callToAction: some View {
        VStack(spacing: 12) {
            Button {
                Task { await buy() }
            } label: {
                Group {
                    if isWorking || subscriptions.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.headline)
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Metric.primaryButtonHeight)
                .background(Theme.accent, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(activePlan == nil || isWorking || subscriptions.isLoading)

            Button(String(localized: "common.restorePurchases", defaultValue: "Restore purchases")) {
                Task { await restore() }
            }
            .font(.subheadline)
            .disabled(isWorking || subscriptions.isLoading)
            .accessibilityAddTraits(.isButton)

            if let notice {
                Text(notice)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var ctaTitle: String {
        subscriptions.isEligibleForTrial
            ? String(localized: "paywall.cta.trial", defaultValue: "Start 7-day free trial")
            : String(localized: "paywall.cta.subscribe", defaultValue: "Subscribe")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(trialNote)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
            Text(String(
                localized: "paywall.footer",
                defaultValue: "Payment is handled by Apple. OffRecord stores no card or identity data."
            ))
            .font(.footnote)
            .foregroundStyle(Theme.secondaryLabel)

            HStack(spacing: 16) {
                if let termsURL {
                    Link(String(localized: "common.terms", defaultValue: "Terms of use"), destination: termsURL)
                }
                if let privacyURL {
                    Link(String(localized: "common.privacyPolicy", defaultValue: "Privacy policy"), destination: privacyURL)
                }
            }
            .font(.footnote.weight(.medium))
        }
    }

    private var trialNote: String {
        guard let product = activePlan else { return "" }
        let price = product.displayPrice
        if subscriptions.isEligibleForTrial {
            return product.id.hasSuffix(".pro.monthly")
                ? String(format: String(localized: "paywall.trialNote.monthly", defaultValue: "Then %@ per month. Cancel anytime in Settings."), price)
                : String(format: String(localized: "paywall.trialNote", defaultValue: "Then %@ per year. Cancel anytime in Settings."), price)
        }
        return String(localized: "paywall.trialNote.notrial", defaultValue: "Cancel anytime in Settings.")
    }

    private func buy() async {
        guard let product = activePlan else { return }
        isWorking = true
        notice = nil
        let purchased = await subscriptions.purchase(product)
        isWorking = false
        if purchased {
            dismiss()
        } else {
            notice = subscriptions.errorMessage
        }
    }

    private func restore() async {
        isWorking = true
        notice = nil
        let restored = await subscriptions.restore()
        isWorking = false
        if restored {
            notice = String(localized: "paywall.restored", defaultValue: "Purchases restored.")
        } else {
            notice = subscriptions.errorMessage
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionManager())
}
