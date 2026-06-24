import SwiftUI

extension Color {
    /// Parse "#RRGGBB". Falls back to clear on malformed input.
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        self = Color(
            red: Double((v & 0xFF0000) >> 16) / 255,
            green: Double((v & 0x00FF00) >> 8) / 255,
            blue: Double(v & 0x0000FF) / 255
        )
    }
}

// MARK: - Garden world background
//
// Turns the blank scene into a *place*: a time-of-day sky up top, a row of shrubs
// and a white picket fence at the horizon, and a grassy ground the beds sit in.

struct GardenWorldBackground: View {
    let sky: SkyModel
    /// Optional per-area skin; falls back to the default garden palette.
    var scenery: AreaScenery? = nil

    private var grassTop: Color { scenery.map { Color(hexString: $0.grassTopHex) } ?? Garden.grassTop }
    private var grassBottom: Color { scenery.map { Color(hexString: $0.grassBottomHex) } ?? Garden.grassBottom }
    private var shrubColor: Color { scenery.map { Color(hexString: $0.shrubHex) } ?? Garden.shrub }
    private var fenceColor: Color { scenery.map { Color(hexString: $0.fenceHex) } ?? Garden.fenceWood }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let horizon = h * 0.32

            ZStack(alignment: .topLeading) {
                // Sky
                LinearGradient(colors: [sky.sky.top, sky.sky.bottom],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: horizon + 40)

                // Sun / moon
                celestial
                    .position(x: w * sky.celestialPosition.x,
                              y: (horizon + 40) * min(max(sky.celestialPosition.y * 1.4, 0.12), 0.9))

                // Grass ground
                LinearGradient(colors: [grassTop, grassBottom],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: h - horizon)
                    .offset(y: horizon)

                // Shrubs nestled along the horizon, peeking above the fence
                shrubRow(width: w)
                    .position(x: w / 2, y: horizon - 6)

                // Picket fence at the horizon
                PicketFence(wood: fenceColor)
                    .frame(width: w, height: 46)
                    .position(x: w / 2, y: horizon + 6)
            }
        }
        .ignoresSafeArea()
    }

    private var celestial: some View {
        ZStack {
            Circle().fill(sky.celestialColor.opacity(0.30)).frame(width: 92, height: 92).blur(radius: 14)
            Circle().fill(sky.celestialColor).frame(width: 48, height: 48)
            if sky.isMoon {
                Circle().fill(sky.sky.top).frame(width: 40, height: 40).offset(x: 11, y: -6).blur(radius: 1)
            }
        }
        .accessibilityHidden(true)
    }

    private func shrubRow(width: CGFloat) -> some View {
        HStack(spacing: -18) {
            ForEach(0..<Int(width / 46) + 2, id: \.self) { i in
                Ellipse()
                    .fill(i % 2 == 0 ? shrubColor : shrubColor.opacity(0.82))
                    .frame(width: 62, height: 38)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Picket fence

struct PicketFence: View {
    var wood: Color = Garden.fenceWood

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let pickets = max(Int(w / 26), 6)
            ZStack {
                // Back rails
                VStack(spacing: 10) {
                    rail; rail
                }
                .padding(.top, 12)

                // Pickets
                HStack(spacing: 12) {
                    ForEach(0..<pickets, id: \.self) { _ in
                        Picket(wood: wood)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var rail: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(wood)
            .frame(height: 5)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Garden.fenceShade, lineWidth: 0.5))
    }
}

private struct Picket: View {
    var wood: Color = Garden.fenceWood
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 1,
                               bottomTrailingRadius: 1, topTrailingRadius: 6)
            .fill(wood)
            .overlay(
                UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 1,
                                       bottomTrailingRadius: 1, topTrailingRadius: 6)
                    .stroke(Garden.fenceShade, lineWidth: 0.5)
            )
            .frame(width: 14)
    }
}

// MARK: - Stepping stones (between rows)

struct SteppingStones: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .fill(
                        LinearGradient(colors: [Garden.stone, Garden.stoneDark],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 38, height: 17)
                    .overlay(Ellipse().stroke(Garden.stoneDark.opacity(0.6), lineWidth: 0.5))
                    .offset(y: i == 1 ? -5 : 0)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Grass fringe (nests a planter into the ground)

struct GrassFringe: View {
    var body: some View {
        GeometryReader { geo in
            let blades = max(Int(geo.size.width / 12), 8)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<blades, id: \.self) { i in
                    BladeShape()
                        .fill(i % 2 == 0 ? Garden.grassBlade : Garden.shrub)
                        .frame(width: 6, height: i % 3 == 0 ? 14 : 10)
                }
            }
            .frame(width: geo.size.width, alignment: .center)
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}

private struct BladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.midY))
        return p
    }
}

// MARK: - Seedling (real .seed-state art — a sprout, not a shrunk flower)

struct SeedlingView: View {
    var size: CGFloat

    private let stem = Color(red: 0.40, green: 0.58, blue: 0.26)
    private let leafColor = Color(red: 0.52, green: 0.72, blue: 0.34)

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(stem)
                .frame(width: size * 0.09, height: size * 0.46)

            LeafShape()
                .fill(leafColor)
                .frame(width: size * 0.36, height: size * 0.24)
                .rotationEffect(.degrees(-34), anchor: .bottomTrailing)
                .offset(x: -size * 0.10, y: -size * 0.30)

            LeafShape()
                .fill(leafColor)
                .frame(width: size * 0.36, height: size * 0.24)
                .scaleEffect(x: -1)
                .rotationEffect(.degrees(34), anchor: .bottomLeading)
                .offset(x: size * 0.10, y: -size * 0.30)
        }
        .frame(width: size, height: size, alignment: .bottom)
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

// MARK: - Sparkle burst (set-complete celebration)

struct SparkleBurst: View {
    @State private var go = false

    private struct Spark: Identifiable { let id = UUID(); let offset: CGSize; let size: CGFloat }
    private let sparks: [Spark] = [
        .init(offset: CGSize(width: -78, height: -34), size: 22),
        .init(offset: CGSize(width: 72, height: -42), size: 26),
        .init(offset: CGSize(width: -46, height: 26), size: 16),
        .init(offset: CGSize(width: 60, height: 22), size: 20),
        .init(offset: CGSize(width: 0, height: -56), size: 24),
        .init(offset: CGSize(width: -92, height: -2), size: 18),
        .init(offset: CGSize(width: 92, height: -10), size: 16),
        .init(offset: CGSize(width: 26, height: -28), size: 14),
        .init(offset: CGSize(width: -24, height: -20), size: 14),
    ]

    var body: some View {
        ZStack {
            // Soft expanding ring
            Circle()
                .stroke(Garden.gold.opacity(0.5), lineWidth: 3)
                .frame(width: 60, height: 60)
                .scaleEffect(go ? 2.4 : 0.3)
                .opacity(go ? 0 : 0.7)

            ForEach(sparks) { spark in
                Image(systemName: "sparkle")
                    .font(.system(size: spark.size))
                    .foregroundStyle(Garden.gold)
                    .scaleEffect(go ? 1.0 : 0.2)
                    .opacity(go ? 0 : 1)
                    .offset(go ? spark.offset : .zero)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.25)) { go = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
