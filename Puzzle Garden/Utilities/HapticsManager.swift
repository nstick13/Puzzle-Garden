import UIKit

@MainActor
final class HapticsManager {
    static let shared = HapticsManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notification.prepare()
    }

    private var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    func hapticDigMark() {
        guard hapticsEnabled else { return }
        lightImpact.impactOccurred()
    }

    func hapticFlowerPlaced() {
        guard hapticsEnabled else { return }
        mediumImpact.impactOccurred()
    }

    func hapticSolve() {
        guard hapticsEnabled else { return }
        notification.notificationOccurred(.success)
    }
}
