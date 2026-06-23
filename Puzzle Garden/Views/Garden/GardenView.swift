import SwiftUI

// MARK: - Garden palette
//
// Warm, cozy tokens shared by the scene. Mirrors ILLUSTRATION.md hex tokens.

private enum Garden {
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

    static let plotSize: CGFloat = 54
}

// MARK: - Garden scene

struct GardenView: View {
    var playerData: PlayerData

    @State private var gardenImage: UIImage?
    @State private var showShareSheet = false
    @State private var picked: PickedPlot?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sets: [CollectibleSet] { playerData.gardenSets }
    private var totalPlants: Int { sets.reduce(0) { $0 + $1.members.count } }
    private var bedsInBloom: Int { sets.filter { $0.isComplete }.count }

    struct PickedPlot: Equatable { let setID: String; let slot: Int }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if totalPlants == 0 {
                    emptyState
                } else {
                    scene
                }

                // Ambient life floats over the scene (fixed, doesn't scroll).
                BreezeLayer(paused: playerData.isWilted, reduceMotion: reduceMotion)
                WanderingCat(asleep: playerData.isWilted, reduceMotion: reduceMotion)
                    .padding(.bottom, 2)
            }
            .navigationTitle("My Garden")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if totalPlants > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { renderAndShare() } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .tint(Garden.green)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = gardenImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    // Sky tints with the system clock; refreshes each minute as the sun/moon arcs.
    private var background: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            SkyBackground(model: SkyModel(date: ctx.date))
        }
    }

    private var scene: some View {
        ScrollView {
            VStack(spacing: 22) {
                summaryHeader

                if playerData.isWilted {
                    wiltNote
                }

                ForEach(Array(sets.enumerated()), id: \.element.id) { _, set in
                    BedStageView(
                        set: set,
                        animated: true,
                        wilted: playerData.isWilted,
                        selectedSlot: picked?.setID == set.id ? picked?.slot : nil,
                        onTapPlot: { slot, hasPlant in handleTap(setID: set.id, slot: slot, hasPlant: hasPlant) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    /// Tap a plant to lift it, tap another plot in the same bed to drop/swap it.
    private func handleTap(setID: String, slot: Int, hasPlant: Bool) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
            if let p = picked {
                if p.setID == setID, p.slot != slot {
                    playerData.moveCollectible(setID: setID, fromSlot: p.slot, toSlot: slot)
                }
                picked = nil
            } else if hasPlant {
                picked = PickedPlot(setID: setID, slot: slot)
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 14) {
            summaryStat(value: "\(totalPlants)", label: totalPlants == 1 ? "plant" : "plants")
            Divider().frame(height: 28).overlay(Garden.inkSoft.opacity(0.25))
            summaryStat(value: "\(bedsInBloom)", label: bedsInBloom == 1 ? "bed in bloom" : "beds in bloom")
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Garden.soilRim.opacity(0.18), lineWidth: 1)
        )
    }

    private func summaryStat(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Garden.green)
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Garden.inkSoft)
        }
    }

    private var wiltNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .foregroundStyle(Color(red: 0.45, green: 0.62, blue: 0.78))
            Text("Your garden misses you — solve a puzzle to perk it back up.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Garden.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.90, green: 0.93, blue: 0.95))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 54))
                .foregroundStyle(Garden.leaf.opacity(0.8))
            Text("Your garden is empty")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Garden.ink)
            Text("Solve a puzzle to plant your first seed.\nIt'll sprout and bloom over the days you return.")
                .multilineTextAlignment(.center)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Garden.inkSoft)
        }
        .padding(32)
    }

    // MARK: - Share

    @MainActor
    private func renderAndShare() {
        let view = GardenSnapshotView(sets: sets, totalPlants: totalPlants, bedsInBloom: bedsInBloom)
        let renderer = ImageRenderer(content: view)
        renderer.scale = displayScale
        if let image = renderer.uiImage {
            gardenImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Bed stage (a planter)

private struct BedStageView: View {
    let set: CollectibleSet
    var animated: Bool
    var wilted: Bool = false
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
            Text(set.displayName)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Garden.ink)

            if set.isComplete {
                bloomBadge
            }

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
        case .seed:     return 0.52
        case .growing:  return 0.78
        case .complete: return 1.0
        }
    }
    private var saturation: Double {
        switch collectible.state {
        case .seed:     return 0.55
        case .growing:  return 0.85
        case .complete: return 1.0
        }
    }
    private var opacity: Double {
        collectible.state == .seed ? 0.85 : 1.0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !shouldSway)) { ctx in
            artwork
                .rotationEffect(.degrees(swayAngle(at: ctx.date)), anchor: .bottom)
        }
        .accessibilityLabel(accessibilityText)
    }

    private var artwork: some View {
        Group {
            if !collectible.assetBase.isEmpty {
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

private struct GardenSnapshotView: View {
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

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    GardenView(playerData: PlayerData.shared)
}
