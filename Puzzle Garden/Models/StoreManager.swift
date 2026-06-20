import StoreKit
import Observation

@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()

    private let productID = "com.puzzlegarden.fullaccess"

    var hasFullAccess = false
    var product: Product?
    var isPurchasing = false
    var purchaseError: String?

    private init() {
        Task {
            for await result in Transaction.updates {
                await self.handle(result)
            }
        }
        Task { await load() }
    }

    // MARK: - Public

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification): await handle(verification)
            case .userCancelled, .pending: break
            @unknown default: break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func load() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            purchaseError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.productID == productID {
                found = true
            }
        }
        hasFullAccess = found
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        await tx.finish()
        await refreshEntitlements()
    }
}
