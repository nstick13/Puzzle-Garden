import SwiftUI

// MARK: - Garden tab root: zoom-out world ⇄ zoom-in area

/// Top level of the Garden tab. Shows the world map; tapping an area zooms into its
/// `AreaSceneView`. Pulling back (chevron) zooms out to the map.
struct GardenView: View {
    var playerData: PlayerData

    @State private var zoomedArea: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let k = zoomedArea {
                AreaSceneView(playerData: playerData, areaIndex: k, onZoomOut: zoomOut)
                    .transition(reduceMotion ? .opacity
                                : .scale(scale: 0.86).combined(with: .opacity))
                    .zIndex(1)
            } else {
                WorldMapView(playerData: playerData, onSelect: zoomIn)
                    .transition(.opacity)
            }
        }
    }

    private func zoomIn(_ k: Int) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            zoomedArea = k
        }
    }
    private func zoomOut() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            zoomedArea = nil
        }
    }
}

// MARK: - World map (zoomed-out overview)

private struct WorldMapView: View {
    var playerData: PlayerData
    var onSelect: (Int) -> Void

    // Fractional positions for up to 4 areas, winding bottom → top.
    private let positions: [CGPoint] = [
        CGPoint(x: 0.20, y: 0.82),
        CGPoint(x: 0.62, y: 0.62),
        CGPoint(x: 0.26, y: 0.42),
        CGPoint(x: 0.66, y: 0.22),
    ]

    private var areas: [GardenArea] { playerData.gardenAreas }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.81, green: 0.89, blue: 0.95),
                                 Color(red: 0.74, green: 0.84, blue: 0.56),
                                 Color(red: 0.62, green: 0.76, blue: 0.46)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    Circle()
                        .fill(Color(red: 0.97, green: 0.78, blue: 0.34).opacity(0.85))
                        .frame(width: 56, height: 56)
                        .position(x: geo.size.width * 0.84, y: geo.size.height * 0.10)

                    path(in: geo.size)

                    ForEach(areas.indices, id: \.self) { k in
                        let p = positions[min(k, positions.count - 1)]
                        AreaTile(
                            area: areas[k],
                            unlocked: playerData.isAreaUnlocked(k),
                            complete: playerData.isAreaComplete(k),
                            active: playerData.activeAreaIndex == k,
                            bloomedBeds: playerData.areaBloomedBeds(k),
                            onTap: { onSelect(k) }
                        )
                        .position(x: geo.size.width * p.x, y: geo.size.height * p.y)
                    }
                }
            }
            .navigationTitle("My Garden")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    /// Dashed stone path linking the areas you've reached.
    private func path(in size: CGSize) -> some View {
        let reached = areas.indices.filter { playerData.isAreaUnlocked($0) }
        return Path { p in
            guard let first = reached.first else { return }
            let pt0 = positions[min(first, positions.count - 1)]
            p.move(to: CGPoint(x: size.width * pt0.x, y: size.height * pt0.y))
            for k in reached.dropFirst() {
                let pt = positions[min(k, positions.count - 1)]
                p.addLine(to: CGPoint(x: size.width * pt.x, y: size.height * pt.y))
            }
        }
        .stroke(Color(red: 0.80, green: 0.76, blue: 0.62),
                style: StrokeStyle(lineWidth: 9, lineCap: .round, dash: [1, 16]))
        .accessibilityHidden(true)
    }
}

// MARK: - Area tile

private struct AreaTile: View {
    let area: GardenArea
    let unlocked: Bool
    let complete: Bool
    let active: Bool
    let bloomedBeds: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: { if unlocked { onTap() } }) {
            VStack(spacing: 6) {
                Image(systemName: complete ? area.systemIcon : (unlocked ? area.systemIcon : "lock.fill"))
                    .font(.system(size: 22))
                    .foregroundStyle(unlocked ? Garden.green : Garden.inkSoft.opacity(0.7))

                Text(area.displayName)
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(unlocked ? Garden.ink : Garden.inkSoft)

                statusChip
            }
            .padding(.vertical, 12)
            .frame(width: 138)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unlocked ? Color(red: 0.98, green: 0.96, blue: 0.91)
                                   : Color(red: 0.93, green: 0.92, blue: 0.87))
                    .shadow(color: .black.opacity(unlocked ? 0.14 : 0.06), radius: 5, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(active ? Garden.green : .clear, lineWidth: 2)
            )
            .opacity(unlocked ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    @ViewBuilder
    private var statusChip: some View {
        if complete {
            chip("In full bloom", system: "checkmark.seal.fill",
                 fg: Garden.green, bg: Garden.leaf.opacity(0.18))
        } else if unlocked {
            chip("Tending · \(bloomedBeds)/\(area.bedCount)", system: "leaf.fill",
                 fg: Color(red: 0.12, green: 0.40, blue: 0.62), bg: Color(red: 0.85, green: 0.92, blue: 0.97))
        } else {
            chip("Locked", system: "lock.fill",
                 fg: Garden.inkSoft, bg: Color(red: 0.88, green: 0.86, blue: 0.80))
        }
    }

    private func chip(_ text: String, system: String, fg: Color, bg: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system).font(.system(size: 9))
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(fg)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(bg))
    }
}
