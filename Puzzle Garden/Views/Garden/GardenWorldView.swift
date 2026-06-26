import SwiftUI

// MARK: - Garden tab root: one continuous world you fly a camera over
//
// The whole garden lives on a single fixed-size canvas (`World.size`). A camera
// (zoom + center) maps that canvas onto the screen. Far out you see the whole
// estate as a lush map; tap an area — or pinch toward it — and that parcel scales
// up *in place* while finer detail (real planter beds you can tend) fades in.
// Pinch back, drag to pan, or tap the chevron to pull out to the map again.

struct GardenView: View {
    var playerData: PlayerData

    var body: some View {
        GeometryReader { proxy in
            // Capture the safe-area inset before going full-bleed, so the HUD can sit
            // clear of the status bar / clock while the map itself fills the screen.
            GardenWorldCanvas(playerData: playerData, safeTop: proxy.safeAreaInsets.top)
                .ignoresSafeArea()
        }
    }
}

// MARK: - World geometry

private enum World {
    /// Logical canvas the camera moves over (portrait, taller than the screen).
    /// The vertical margins are deliberately ≥ half a focused screen so the camera
    /// can center fully on the top/bottom parcels without the clamp fighting it.
    static let size = CGSize(width: 1000, height: 2040)
    /// Footprint of one area parcel in world units.
    static let areaSize = CGSize(width: 440, height: 500)

    /// Parcel centers, winding bottom → top like a path up a hillside garden.
    static let centers: [CGPoint] = [
        CGPoint(x: 270, y: 1500),
        CGPoint(x: 720, y: 1180),
        CGPoint(x: 280, y: 860),
        CGPoint(x: 710, y: 540),
    ]

    static func center(_ k: Int) -> CGPoint { centers[min(k, centers.count - 1)] }
    static var worldCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }
}

private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
    guard b > a else { return x >= b ? 1 : 0 }
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}

// MARK: - The canvas (camera + content + gestures + HUD)

private struct GardenWorldCanvas: View {
    var playerData: PlayerData
    var safeTop: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Live camera.
    @State private var zoom: CGFloat = 1
    @State private var center: CGPoint = World.worldCenter
    // Snapshots taken at the start of a continuous gesture.
    @State private var baseZoom: CGFloat = 1
    @State private var baseCenter: CGPoint = World.worldCenter

    @State private var screen: CGSize = .zero
    @State private var didInit = false

    // Share
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @Environment(\.displayScale) private var displayScale

    private var areas: [GardenArea] { playerData.gardenAreas }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            // Pin the stack to the screen (top-leading) and clip, so the giant world
            // frame doesn't balloon the layout — screen-space overlays (cat, breeze,
            // HUD) then position against the real screen, not the 1000×2040 canvas.
            ZStack(alignment: .topLeading) {
                worldContent(screen: s)
                    .frame(width: World.size.width, height: World.size.height)
                    .scaleEffect(zoom, anchor: .topLeading)
                    .offset(x: offset(s).x, y: offset(s).y)
                    .gesture(panGesture(screen: s))
                    .simultaneousGesture(zoomGesture(screen: s))

                // Ambient life rides above the map in screen space.
                BreezeLayer(paused: playerData.isWilted, reduceMotion: reduceMotion)
                    .frame(width: s.width, height: s.height)
                WanderingCat(asleep: playerData.isWilted, reduceMotion: reduceMotion) {
                    SoundManager.shared.playMeow()
                    HapticsManager.shared.hapticDigMark()
                }
                .frame(width: s.width, height: s.height)

                hud(screen: s)
                    .frame(width: s.width, height: s.height, alignment: .top)
            }
            .frame(width: s.width, height: s.height, alignment: .topLeading)
            .clipped()
            .background(skyFloor)
            .onAppear {
                screen = s
                if !didInit { initCamera(s); didInit = true }
            }
        }
        .sheet(isPresented: $showShare) {
            if let img = shareImage { ShareSheet(items: [img]) }
        }
    }

    // A soft sky wash behind everything so the map never sits on black during a zoom.
    private var skyFloor: some View {
        TimelineView(.periodic(from: .now, by: 120)) { ctx in
            let sky = SkyModel(date: ctx.date).sky
            LinearGradient(colors: [sky.top, sky.bottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    // MARK: World content

    @ViewBuilder
    private func worldContent(screen s: CGSize) -> some View {
        let details = areas.indices.map { detail($0, screen: s) }
        let maxD = details.max() ?? 0
        let topK = details.firstIndex(of: maxD)
        let someFocused = maxD > 0.55

        return ZStack {
            WorldGround()
            WorldPath(reachable: reachableCenters)
            ForEach(areas.indices, id: \.self) { k in
                let isTop = someFocused && k == topK
                AreaPlot(
                    playerData: playerData,
                    areaIndex: k,
                    detail: details[k],
                    // Fade the parcels you're not drilling into so the focused one stands alone.
                    dim: isTop ? 0 : (someFocused ? maxD : 0),
                    onFocus: { focus(k, screen: s) }
                )
                .frame(width: World.areaSize.width, height: World.areaSize.height)
                .position(World.center(k))
                .zIndex(isTop ? 1 : 0)
            }
        }
    }

    private var reachableCenters: [CGPoint] {
        areas.indices.filter { playerData.isAreaUnlocked($0) }.map { World.center($0) }
    }

    // MARK: Camera math

    private func overviewZoom(_ s: CGSize) -> CGFloat {
        guard s.width > 0 else { return 1 }
        return min(s.width / World.size.width, s.height / World.size.height)
    }
    private func focusZoom(_ s: CGSize) -> CGFloat {
        guard s.width > 0 else { return 1 }
        return min(s.width / World.areaSize.width, s.height / World.areaSize.height) * 0.97
    }
    // Never zoom past the point where a single parcel fills the screen — beyond that
    // the beds would spill off the edges with nothing more to reveal.
    private func maxZoom(_ s: CGSize) -> CGFloat { focusZoom(s) }

    /// World→screen offset so that `center` lands at the screen midpoint.
    private func offset(_ s: CGSize) -> CGPoint {
        CGPoint(x: s.width / 2 - center.x * zoom,
                y: s.height / 2 - center.y * zoom)
    }

    private func clampZoom(_ z: CGFloat, _ s: CGSize) -> CGFloat {
        min(max(z, overviewZoom(s) * 0.9), maxZoom(s))
    }

    /// Keep the camera inside the world; recenters on the axis where the world is
    /// smaller than the viewport (so the map can't drift off into empty space).
    private func clampCenter(_ c: CGPoint, _ z: CGFloat, _ s: CGSize) -> CGPoint {
        var p = c
        let hx = s.width / (2 * z)
        if World.size.width >= 2 * hx { p.x = min(max(p.x, hx), World.size.width - hx) }
        else { p.x = World.size.width / 2 }
        let hy = s.height / (2 * z)
        if World.size.height >= 2 * hy { p.y = min(max(p.y, hy), World.size.height - hy) }
        else { p.y = World.size.height / 2 }
        return p
    }

    private func initCamera(_ s: CGSize) {
        zoom = overviewZoom(s)
        center = clampCenter(World.worldCenter, zoom, s)
        baseZoom = zoom
        baseCenter = center
    }

    // 0 = far/map, 1 = fully drilled in. Gated by proximity so only the area you
    // move toward blooms into full detail.
    private func detail(_ k: Int, screen s: CGSize) -> Double {
        let g = smoothstep(overviewZoom(s) * 1.5, focusZoom(s) * 0.92, zoom)
        let d = hypot(center.x - World.center(k).x, center.y - World.center(k).y)
        let prox = max(0, 1 - d / (World.areaSize.width * 0.85))
        return Double(g) * Double(prox)
    }

    private var focusedIndex: Int? {
        areas.indices
            .map { ($0, detail($0, screen: screen)) }
            .filter { $0.1 > 0.55 }
            .max { $0.1 < $1.1 }?.0
    }

    // MARK: Gestures

    private func zoomGesture(screen s: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { v in
                zoom = clampZoom(baseZoom * v, s)
                center = clampCenter(center, zoom, s)
            }
            .onEnded { _ in
                if zoom < overviewZoom(s) * 1.25 { goOverview(s) }
                baseZoom = zoom
                baseCenter = center
            }
    }

    private func panGesture(screen s: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                let p = CGPoint(x: baseCenter.x - v.translation.width / zoom,
                                y: baseCenter.y - v.translation.height / zoom)
                center = clampCenter(p, zoom, s)
            }
            .onEnded { _ in
                baseCenter = center
                baseZoom = zoom
            }
    }

    private func focus(_ k: Int, screen s: CGSize) {
        guard playerData.isAreaUnlocked(k) else { return }
        let z = focusZoom(s)
        let c = clampCenter(World.center(k), z, s)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.82)) {
            zoom = z
            center = c
        }
        baseZoom = z
        baseCenter = c
        HapticsManager.shared.hapticDigMark()
    }

    private func goOverview(_ s: CGSize) {
        let z = overviewZoom(s)
        let c = clampCenter(World.worldCenter, z, s)
        withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)) {
            zoom = z
            center = c
        }
        baseZoom = z
        baseCenter = c
    }

    // MARK: HUD

    @ViewBuilder
    private func hud(screen s: CGSize) -> some View {
        let focused = focusedIndex
        VStack {
            HStack(alignment: .top) {
                if focused != nil {
                    hudButton(system: "chevron.left") { goOverview(s) }
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Spacer().frame(width: 44)
                }

                Spacer()

                titlePill(focused: focused)

                Spacer()

                if let k = focused, !playerData.setsForArea(k).isEmpty {
                    hudButton(system: "square.and.arrow.up") { shareArea(k) }
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Spacer().frame(width: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, safeTop + 6)

            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: focused)
    }

    private func titlePill(focused: Int?) -> some View {
        Text(focused.map { areas[$0].displayName } ?? "My Garden")
            .font(.system(.headline, design: .rounded).bold())
            .foregroundStyle(Garden.green)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Garden.cream.opacity(0.92))
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
            )
            .id(focused ?? -1)
            .transition(.opacity)
    }

    private func hudButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Garden.green)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Garden.cream.opacity(0.92))
                    .shadow(color: .black.opacity(0.12), radius: 5, y: 2))
        }
    }

    @MainActor
    private func shareArea(_ k: Int) {
        let sets = playerData.setsForArea(k)
        let total = sets.reduce(0) { $0 + $1.members.count }
        let bloom = sets.filter { $0.isComplete }.count
        let view = GardenSnapshotView(sets: sets, totalPlants: total, bedsInBloom: bloom)
        let renderer = ImageRenderer(content: view)
        renderer.scale = displayScale
        if let img = renderer.uiImage {
            shareImage = img
            showShare = true
        }
    }
}

#Preview {
    GardenView(playerData: PlayerData.shared)
}
