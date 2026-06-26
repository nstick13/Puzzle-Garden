import SwiftUI

// MARK: - Garden palette
//
// Warm, cozy tokens shared by the scene. Mirrors ILLUSTRATION.md hex tokens.

enum Garden {
    static let cream      = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let creamWarm  = Color(red: 0.98, green: 0.93, blue: 0.83)
    static let ink        = Color(red: 0.30, green: 0.22, blue: 0.14)
    static let inkSoft    = Color(red: 0.45, green: 0.35, blue: 0.25)
    static let green      = Color(red: 0.20, green: 0.38, blue: 0.22)
    static let leaf       = Color(red: 0.39, green: 0.60, blue: 0.13)

    static let soilTop    = Color(red: 0.52, green: 0.37, blue: 0.24)
    static let soilBottom = Color(red: 0.37, green: 0.26, blue: 0.17)
    static let soilHole   = Color(red: 0.26, green: 0.18, blue: 0.12)
    static let soilRim    = Color(red: 0.60, green: 0.45, blue: 0.30)

    // Scenery
    static let grassTop    = Color(red: 0.74, green: 0.84, blue: 0.58)
    static let grassBottom = Color(red: 0.62, green: 0.76, blue: 0.46)
    static let grassBlade  = Color(red: 0.50, green: 0.67, blue: 0.34)
    static let shrub       = Color(red: 0.45, green: 0.63, blue: 0.34)
    static let shrubDark   = Color(red: 0.37, green: 0.54, blue: 0.28)
    static let fenceWood   = Color(red: 0.95, green: 0.91, blue: 0.81)
    static let fenceShade  = Color(red: 0.80, green: 0.72, blue: 0.57)
    static let stone       = Color(red: 0.82, green: 0.79, blue: 0.72)
    static let stoneDark   = Color(red: 0.68, green: 0.64, blue: 0.56)
    static let gold        = Color(red: 0.98, green: 0.80, blue: 0.30)

    static let plotSize: CGFloat = 54
}

// MARK: - Bed stage (a planter)

struct BedStageView: View {
    let set: CollectibleSet
    var animated: Bool
    var wilted: Bool = false
    var celebrating: Bool = false
    var selectedSlot: Int? = nil
    var onTapPlot: ((Int, Bool) -> Void)? = nil

    private var sortedMembers: [Collectible] {
        self.set.members.sorted { $0.slot < $1.slot }
    }

    /// Member occupying a given slot index (slots are reorderable, not contiguous).
    private func member(atSlot slot: Int) -> Collectible? {
        self.set.members.first { $0.slot == slot }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            planter
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            // A few stones leading into the named bed, so each corner reads as a
            // little destination along the garden path.
            SteppingPathMarker()

            // A soft cream "plaque" behind the name so it stays legible over the
            // fence/grass and reads as an intentional label, never text-on-pickets.
            HStack(spacing: 6) {
                Text(set.displayName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Garden.ink)
                if set.isComplete {
                    bloomBadge
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Garden.cream.opacity(0.85))
                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            )

            Spacer()
            progressPips
        }
        .padding(.horizontal, 4)
    }

    private var bloomBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
            Text("in bloom")
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(Garden.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Garden.leaf.opacity(0.18)))
    }

    private var progressPips: some View {
        HStack(spacing: 4) {
            ForEach(0..<set.capacity, id: \.self) { i in
                Circle()
                    .fill(i < set.completedCount ? Garden.leaf : Garden.soilRim.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private var planter: some View {
        HStack(spacing: 8) {
            ForEach(0..<set.capacity, id: \.self) { i in
                let m = member(atSlot: i)
                PlotView(
                    member: m,
                    phase: Double(i),
                    animated: animated,
                    wilted: wilted,
                    isSelected: selectedSlot == i,
                    onTap: { onTapPlot?(i, m != nil) }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(soilBackground)
        .overlay(alignment: .bottom) {
            GrassFringe()
                .padding(.horizontal, 14)
                .offset(y: 7)
        }
        .overlay {
            if celebrating { SparkleBurst() }
        }
        .scaleEffect(celebrating ? 1.015 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: celebrating)
    }

    private var soilBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Garden.soilTop, Garden.soilBottom],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Garden.soilRim.opacity(0.45), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .shadow(color: Garden.soilBottom.opacity(0.35), radius: 10, x: 0, y: 6)
    }
}

// MARK: - A single plot (hole + collectible, or empty)

private struct PlotView: View {
    let member: Collectible?
    let phase: Double
    var animated: Bool
    var wilted: Bool = false
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // Planting hole — gives each plant a place to sit.
            Ellipse()
                .fill(Garden.soilHole)
                .frame(width: Garden.plotSize * 0.74, height: Garden.plotSize * 0.34)
                .offset(y: -2)
                .overlay(
                    Ellipse()
                        .stroke(isSelected ? Garden.leaf.opacity(0.9) : Garden.soilBottom.opacity(0.6),
                                lineWidth: isSelected ? 2 : 1)
                        .frame(width: Garden.plotSize * 0.74, height: Garden.plotSize * 0.34)
                        .offset(y: -2)
                )

            if let member {
                CollectibleView(collectible: member, phase: phase, animated: animated, wilted: wilted)
                    .scaleEffect(isSelected ? 1.14 : 1, anchor: .bottom)
                    .offset(y: isSelected ? -6 : 0)
                    .shadow(color: .black.opacity(isSelected ? 0.22 : 0), radius: 6, y: 5)
            } else {
                // Empty: a small mound + faint seed hint.
                Circle()
                    .fill(Garden.soilTop.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .offset(y: -6)
            }
        }
        .frame(height: Garden.plotSize + 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Collectible (growth-state rendering)

private struct CollectibleView: View {
    let collectible: Collectible
    let phase: Double
    var animated: Bool
    var wilted: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Per-state visual treatment. Real per-state art is step 4; for now we derive
    // seed/growing from the bloomed art by scaling + softening (per ILLUSTRATION.md).
    private var scale: CGFloat {
        switch collectible.state {
        case .seed:     return 0.92   // SeedlingView is already drawn small
        case .growing:  return 0.78
        case .complete: return 1.0
        }
    }
    private var saturation: Double {
        switch collectible.state {
        case .seed:     return 1.0    // a fresh sprout is vivid green
        case .growing:  return 0.9
        case .complete: return 1.0
        }
    }
    private var opacity: Double { 1.0 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !shouldSway)) { ctx in
            artwork
                .rotationEffect(.degrees(swayAngle(at: ctx.date)), anchor: .bottom)
        }
        .accessibilityLabel(accessibilityText)
    }

    private var artwork: some View {
        Group {
            if collectible.state == .seed {
                // Real seed-state art: a little sprout, not a shrunk flower.
                SeedlingView(size: Garden.plotSize)
            } else if !collectible.assetBase.isEmpty {
                Image(collectible.assetBase)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(collectible.emoji)
                    .font(.system(size: 34))
            }
        }
        .frame(width: Garden.plotSize, height: Garden.plotSize)
        .scaleEffect(scale, anchor: .bottom)
        .saturation(saturation * (wilted ? 0.55 : 1.0))
        .opacity(opacity * (wilted ? 0.92 : 1.0))
        .shadow(color: .black.opacity(collectible.state == .complete ? 0.18 : 0),
                radius: 3, x: 0, y: 3)
        .offset(y: 4)
        .rotationEffect(.degrees(wilted ? droopAngle : 0), anchor: .bottom)
        .animation(.spring(response: 0.7, dampingFraction: 0.7), value: wilted)
    }

    /// Gentle, alternating droop when the garden is neglected — reverses on revival.
    private var droopAngle: Double {
        Int(phase) % 2 == 0 ? 8 : -7
    }

    private var shouldSway: Bool {
        animated && !reduceMotion && !wilted && collectible.state == .complete
    }

    private func swayAngle(at date: Date) -> Double {
        guard shouldSway else { return 0 }
        let t = date.timeIntervalSinceReferenceDate
        return sin(t * 1.1 + phase * 0.8) * 1.6
    }

    private var accessibilityText: String {
        let state: String
        switch collectible.state {
        case .seed:     state = "seedling"
        case .growing:  state = "growing"
        case .complete: state = "in bloom"
        }
        return "Plant, \(state)"
    }
}

// MARK: - Snapshot view (for ImageRenderer; static, no sway)

struct GardenSnapshotView: View {
    let sets: [CollectibleSet]
    let totalPlants: Int
    let bedsInBloom: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").foregroundStyle(Garden.leaf)
                Text("My Puzzle Garden")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(Garden.green)
            }
            Text("\(totalPlants) plants • \(bedsInBloom) in bloom")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Garden.inkSoft)

            ForEach(Array(sets.enumerated()), id: \.element.id) { _, set in
                BedStageView(set: set, animated: false)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(Garden.cream)
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    GardenView(playerData: PlayerData.shared)
}
