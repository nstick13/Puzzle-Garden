import SwiftUI

struct StoreView: View {
    var storeManager: StoreManager
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.95, blue: 0.90)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 8) {
                    Text("🌻")
                        .font(.system(size: 72))
                    Text("Unlock Free Play")
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(Color(red: 0.20, green: 0.38, blue: 0.22))
                    Text("Grow your garden without limits")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                }

                VStack(alignment: .leading, spacing: 14) {
                    benefitRow(icon: "infinity", text: "Unlimited puzzles in all sizes")
                    benefitRow(icon: "leaf.fill", text: "Grow your garden endlessly")
                    benefitRow(icon: "clock.fill", text: "Challenge your best times")
                    benefitRow(icon: "star.fill", text: "One-time purchase — no subscription")
                }
                .padding(.horizontal, 40)

                Text("Today's Daily Puzzle is always free")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                    .multilineTextAlignment(.center)

                Button {
                    Task { await storeManager.purchase() }
                } label: {
                    Group {
                        if storeManager.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Unlock for \(storeManager.priceString)")
                                .font(.system(.headline, design: .rounded))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.25, green: 0.50, blue: 0.28))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(storeManager.isLoading)
                .padding(.horizontal, 32)

                Button {
                    Task { await storeManager.restore() }
                } label: {
                    Text("Restore Purchase")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.50, blue: 0.28))
                }
                .disabled(storeManager.isLoading)

                if let error = storeManager.errorMessage {
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button("Maybe Later", action: onDismiss)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.50, blue: 0.42))

                Spacer()
            }
        }
        .task {
            if storeManager.product == nil { await storeManager.loadProduct() }
        }
        .onChange(of: storeManager.hasFullAccess) { _, unlocked in
            if unlocked { onDismiss() }
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 0.25, green: 0.50, blue: 0.28))
                .frame(width: 24)
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
        }
    }
}

#Preview {
    StoreView(storeManager: StoreManager.shared) {}
}
