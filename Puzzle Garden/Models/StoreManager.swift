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
        // Self-heal: the product may not have loaded at launch (cold-start race, or it
        // wasn't fetchable yet). Try once more before giving up so the button isn't a no-op.
        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = "The store isn't ready yet. Please try again in a moment."
            return
        }
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

    /// Fetch the IAP product. Public so the paywall can retry on appear / on tap.
    /// Surfaces a real reason on failure instead of silently leaving `product` nil.
    func loadProduct() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [productID])
            if let first = products.first {
                product = first
            } else {
                errorMessage = "The store is unavailable right now. Please check your connection and try again."
                NSLog("[Store] No products returned for id \(productID). " +
                      "Simulator: confirm the StoreKit configuration is selected in the run scheme. " +
                      "Device/TestFlight: confirm the IAP exists in App Store Connect in a fetchable state " +
                      "(at least 'Ready to Submit'), the Paid Apps agreement is active, and the id matches exactly.")
            }
        } catch {
            errorMessage = error.localizedDescription
            NSLog("[Store] Product.products(for:) threw: \(error)")
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
