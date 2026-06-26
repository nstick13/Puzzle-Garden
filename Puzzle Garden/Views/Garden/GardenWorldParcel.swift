import SwiftUI

// MARK: - World ground (the lush map everything sits on)
//
// A rolling meadow with soft hills and scattered storybook scenery, so the
// zoomed-out view is a place worth looking at — not a menu with a backdrop.

struct WorldGround: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Base meadow.
                LinearGradient(
                    colors: [Color(hexString: "#CFE6A6"), Color(hexString: "#A9D079"), Color(hexString: "#8FBE63")],
                    startPoint: .top, endPoint: .bottom
                )

                // Soft rolling hills — big translucent ellipses in varied greens.
                ForEach(Array(Self.hills.enumerated()), id: \.offset) { _, hill in
                    Ellipse()
                        .fill(Color(hexString: hill.hex).opacity(0.55))
                        .frame(width: w * hill.size.width, height: h * hill.size.height)
                        .position(x: w * hill.at.x, y: h * hill.at.y)
                        .blur(radius: 18)
                }

                // Scattered ambient scenery (fixed, deterministic).
                ForEach(Array(Self.scenery.enumerated()), id: \.offset) { _, item in
                    item.view
                        .position(x: w * item.at.x, y: h * item.at.y)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private struct Hill { let at: CGPoint; let size: CGSize; let hex: String }
    private static let hills: [Hill] = [
        Hill(at: CGPoint(x: 0.25, y: 0.16), size: CGSize(width: 0.9, height: 0.28), hex: "#B9DC8A"),
        Hill(at: CGPoint(x: 0.78, y: 0.40), size: CGSize(width: 0.8, height: 0.26), hex: "#9CCB6E"),
        Hill(at: CGPoint(x: 0.30, y: 0.66), size: CGSize(width: 0.95, height: 0.30), hex: "#AED77F"),
        Hill(at: CGPoint(x: 0.74, y: 0.88), size: CGSize(width: 0.85, height: 0.26), hex: "#94C566"),
    ]

    private struct Item { let at: CGPoint; let view: AnyView }
    private static let scenery: [Item] = [
        Item(at: CGPoint(x: 0.10, y: 0.10), view: AnyView(TreeSprite(scale: 1.1))),
        Item(at: CGPoint(x: 0.88, y: 0.13), view: AnyView(TreeSprite(scale: 0.85))),
        Item(at: CGPoint(x: 0.55, y: 0.06), view: AnyView(BushSprite())),
        Item(at: CGPoint(x: 0.92, y: 0.55), view: AnyView(TreeSprite(scale: 1.0))),
        Item(at: CGPoint(x: 0.08, y: 0.48), view: AnyView(BushSprite())),
        Item(at: CGPoint(x: 0.50, y: 0.50), view: AnyView(FlowerTuft())),
        Item(at: CGPoint(x: 0.16, y: 0.82), view: AnyView(TreeSprite(scale: 0.9))),
        Item(at: CGPoint(x: 0.90, y: 0.95), view: AnyView(BushSprite())),
        Item(at: CGPoint(x: 0.40, y: 0.94), view: AnyView(FlowerTuft())),
        Item(at: CGPoint(x: 0.62, y: 0.30), view: AnyView(FlowerTuft())),
    ]
}

// MARK: - Winding path linking the parcels you've reached

struct WorldPath: View {
    var reachable: [CGPoint]

    var body: some View {
        ZStack {
            // Soft, wide cream path with a dashed center line for that garden-trail look.
            line.stroke(Color(hexString: "#E7DEC4").opacity(0.85),
                        style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
            line.stroke(Color(hexString: "#CFC3A0").opacity(0.7),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [2, 22]))
        }
        .accessibilityHidden(true)
    }

    private var line: Path {
        Path { p in
            guard let first = reachable.first else { return }
            p.move(to: first)
            // Gentle curves between waypoints rather than straight segments.
            var prev = first
            for pt in reachable.dropFirst() {
                let mid = CGPoint(x: (prev.x + pt.x) / 2, y: (prev.y + pt.y) / 2)
                let ctrl = CGPoint(x: prev.x, y: mid.y)
                p.addQuadCurve(to: pt, control: ctrl)
                prev = pt
            }
        }
    }
}

// MARK: - Area parcel (level-of-detail: miniature map tile ⇄ real planter beds)

struct AreaPlot: View {
    var playerData: PlayerData
    let areaIndex: Int
    let detail: Double
    var dim: Double = 0
    var onFocus: () -> Void

    @State private var picked: PickedPlot?
    @State private var celebratingBedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct PickedPlot: Equatable { let setID: String; let slot: Int }

    private var area: GardenArea { playerData.gardenAreas[areaIndex] }
    private var sets: [CollectibleSet] { playerData.setsForArea(areaIndex) }
    private var unlocked: Bool { playerData.isAreaUnlocked(areaIndex) }
    private var complete: Bool { playerData.isAreaComplete(areaIndex) }
    private var bloomed: Int { playerData.areaBloomedBeds(areaIndex) }

    var body: some View {
        ZStack {
            island

            if detail < 0.98 {
                farLayer
                    .opacity(min(1, (1 - detail) * 1.4))
                    .allowsHitTesting(false)
            }
            if detail > 0.05 {
                nearLayer
                    .opacity(detail)
                    .allowsHitTesting(detail > 0.5)
            }
        }
        // Contain everything within the plot so beds/decor never spill onto the map.
        .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
        .saturation(unlocked ? 1 : 0.4)
        .scaleEffect(1 - dim * 0.05)
        .opacity(1 - dim * 0.92)
        .overlay {
            // Tap-to-zoom is only live from the map; up close, taps tend the plants.
            if detail < 0.5 {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { if unlocked { onFocus() } }
            }
        }
    }

    // MARK: Island base — a contained "plot" of land that holds the beds

    private var island: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let shape = RoundedRectangle(cornerRadius: 52, style: .continuous)
            ZStack {
                // Cast shadow grounding the parcel on the map.
                shape
                    .fill(Color.black.opacity(0.10))
                    .frame(width: w * 0.94, height: h * 0.94)
                    .blur(radius: 12)
                    .offset(y: h * 0.03)

                // Soil base peeking under the grass.
                shape
                    .fill(LinearGradient(colors: [Garden.soilRim, Garden.soilBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.94, height: h * 0.94)
                    .offset(y: 6)

                // Grass surface.
                shape
                    .fill(LinearGradient(
                        colors: [Color(hexString: area.scenery.grassTopHex),
                                 Color(hexString: area.scenery.grassBottomHex)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.94, height: h * 0.94)
            }
            .frame(width: w, height: h)
        }
    }

    // MARK: Far layer — a charming miniature you read at a glance

    private var farLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                if unlocked {
                    themeDecor(width: w, height: h)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: w * 0.13))
                        .foregroundStyle(Garden.inkSoft)
                        .position(x: w * 0.5, y: h * 0.5)
                }
                nameBanner.position(x: w * 0.5, y: h * 0.18)
            }
            .frame(width: w, height: h)
        }
    }

    private var nameBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: complete ? "checkmark.seal.fill" : area.systemIcon)
                .font(.system(size: 15))
                .foregroundStyle(complete ? Garden.green : Garden.leaf)
            Text(area.displayName)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Garden.ink)
            if unlocked {
                Text(complete ? "in bloom" : "\(bloomed)/\(area.bedCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(complete ? Garden.green : Garden.inkSoft)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Garden.leaf.opacity(0.16)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Garden.cream.opacity(0.94))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        )
    }

    @ViewBuilder
    private func themeDecor(width w: CGFloat, height h: CGFloat) -> some View {
        switch area.id {
        case "orchard":
            ForEach(0..<3, id: \.self) { i in
                TreeSprite(scale: 1.5)
                    .position(x: w * (0.32 + Double(i) * 0.18), y: h * (0.5 + (i == 1 ? 0.06 : 0)))
            }
        case "pond":
            ZStack {
                Ellipse().fill(Color(hexString: "#7FB8C9"))
                    .frame(width: w * 0.5, height: h * 0.3)
                ForEach(0..<3, id: \.self) { i in
                    Ellipse().fill(Color(hexString: "#6FAE63"))
                        .frame(width: w * 0.1, height: h * 0.05)
                        .offset(x: w * (Double(i) * 0.13 - 0.13), y: h * (i == 1 ? -0.03 : 0.02))
                }
            }
            .position(x: w * 0.5, y: h * 0.52)
        case "meadow":
            ForEach(0..<6, id: \.self) { i in
                FlowerTuft()
                    .scaleEffect(1.3)
                    .position(x: w * (0.24 + Double(i % 3) * 0.18),
                              y: h * (0.44 + Double(i / 3) * 0.16))
            }
        default: // flowerbeds
            ForEach(0..<5, id: \.self) { i in
                FlowerTuft()
                    .scaleEffect(1.4)
                    .position(x: w * (0.26 + Double(i) * 0.12),
                              y: h * (0.5 + (i % 2 == 0 ? 0.04 : -0.04)))
            }
        }
    }

    // MARK: Near layer — the real, tendable beds laid into the parcel

    private var nearLayer: some View {
        VStack(spacing: 16) {
            ForEach(Array(sets.enumerated()), id: \.element.id) { _, set in
                BedStageView(
                    set: set,
                    animated: true,
                    wilted: playerData.isWilted,
                    celebrating: celebratingBedID == set.id,
                    selectedSlot: picked?.setID == set.id ? picked?.slot : nil,
                    onTapPlot: { slot, has in handleTap(setID: set.id, slot: slot, hasPlant: has) }
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .onAppear { checkCelebrations() }
        .onChange(of: completedSignature) { checkCelebrations() }
    }

    // MARK: Bed interaction (lifted from the old AreaSceneView)

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

    private var completedSignature: String {
        sets.filter { $0.isComplete }.map { $0.id }.joined(separator: ",")
    }

    private func checkCelebrations() {
        guard celebratingBedID == nil else { return }
        guard let bed = sets.first(where: { $0.isComplete && !playerData.celebratedSetIDs.contains($0.id) })
        else { return }

        celebratingBedID = bed.id
        HapticsManager.shared.hapticSolve()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            playerData.markCelebrated(bed.id)
            celebratingBedID = nil
            checkCelebrations()
        }
    }
}

// MARK: - Storybook scenery sprites (shared by the map and parcels)

struct TreeSprite: View {
    var scale: CGFloat = 1
    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Color(hexString: "#8A623C"))
                .frame(width: 7 * scale, height: 20 * scale)
            ZStack {
                Circle().fill(Color(hexString: "#5E9446")).frame(width: 34 * scale, height: 34 * scale)
                Circle().fill(Color(hexString: "#72A857")).frame(width: 22 * scale, height: 22 * scale)
                    .offset(x: -8 * scale, y: -6 * scale)
            }
            .offset(y: -16 * scale)
            .shadow(color: .black.opacity(0.12), radius: 3, y: 3)
        }
        .frame(width: 40 * scale, height: 48 * scale, alignment: .bottom)
    }
}

struct BushSprite: View {
    var body: some View {
        ZStack {
            Ellipse().fill(Color(hexString: "#5E9446")).frame(width: 40, height: 26)
            Ellipse().fill(Color(hexString: "#6FA855")).frame(width: 24, height: 18).offset(x: -8, y: -4)
            Ellipse().fill(Color(hexString: "#6FA855")).frame(width: 22, height: 16).offset(x: 9, y: -2)
        }
        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
    }
}

struct FlowerTuft: View {
    private let petals = ["#E98AA8", "#F2C14E", "#E07A5F", "#9D8DF1"]
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let dx = [CGFloat(-9), 9, 0][i]
                let dy = [CGFloat(2), 3, -6][i]
                Circle()
                    .fill(Color(hexString: petals[i % petals.count]))
                    .frame(width: 11, height: 11)
                    .overlay(Circle().fill(Color(hexString: "#FFF3C9")).frame(width: 4, height: 4))
                    .offset(x: dx, y: dy)
            }
        }
        .frame(width: 30, height: 22)
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
    }
}
