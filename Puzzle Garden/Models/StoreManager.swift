import Foundation
import Observation
import StoreKit

@Observable
final class StoreManager {
    static let shared = StoreManager()

    private(set) var hasFullAccess = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let productID = "com.puzzlegarden.fullaccess"
    private(set) var product: Product?
    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    var priceString: String {
        product?.displayPrice ?? "$4.99"
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                hasFullAccess = true
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Internal

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            // Non-fatal: price falls back to default display string
        }
    }

    private func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID {
                hasFullAccess = true
                return
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result,
                   transaction.productID == self.productID {
                    await transaction.finish()
                    await MainActor.run { self.hasFullAccess = true }
                }
            }
        }
    }
}
