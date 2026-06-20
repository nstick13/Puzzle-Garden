import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared
    @State private var isRestoring = false

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.95, blue: 0.90).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Text("🌿")
                        .font(.system(size: 56))
                        .padding(.top, 40)

                    Text("Unlock Full Access")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(Color(red: 0.20, green: 0.38, blue: 0.22))

                    Text("One-time purchase. No subscriptions, ever.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                // Feature list
                VStack(alignment: .leading, spacing: 14) {
                    featureRow("leaf.fill",       "Unlimited Free Play",     "All grid sizes, anytime")
                    featureRow("sun.max.fill",    "Daily Puzzle",            "Always free — forever")
                    featureRow("chart.bar.fill",  "Stats & Streaks",         "Track your progress")
                    featureRow("square.grid.2x2", "Growing Garden",          "Earn plants with every solve")
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.92, green: 0.88, blue: 0.82))
                )
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer()

                // Error
                if let error = store.purchaseError {
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // CTA
                VStack(spacing: 12) {
                    Button(action: { Task { await store.purchase() } }) {
                        Group {
                            if store.isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text(priceLabel)
                                    .font(.system(.headline, design: .rounded).bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.25, green: 0.50, blue: 0.28))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(store.product == nil || store.isPurchasing)

                    Button(action: {
                        isRestoring = true
                        Task {
                            await store.restore()
                            isRestoring = false
                            if store.hasFullAccess { dismiss() }
                        }
                    }) {
                        Group {
                            if isRestoring {
                                ProgressView()
                            } else {
                                Text("Restore Purchase")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                            }
                        }
                    }
                    .disabled(isRestoring)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
            }
        }
        .onChange(of: store.hasFullAccess) { _, hasAccess in
            if hasAccess { dismiss() }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.35).opacity(0.6))
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func featureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(red: 0.25, green: 0.50, blue: 0.28))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.18))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
            }
        }
    }

    private var priceLabel: String {
        if let product = store.product {
            return "Get Full Access — \(product.displayPrice)"
        }
        return "Get Full Access — $2.99"
    }
}

#Preview {
    PaywallView()
}
