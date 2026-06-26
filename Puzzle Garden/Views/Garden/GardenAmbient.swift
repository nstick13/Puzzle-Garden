import SwiftUI

// MARK: - Sky model (time-of-day)
//
// Cozy storybook sky, not photoreal: tints stay light/pastel even at night so the
// dark navigation title and content stay readable. Drives a gentle wash over the
// cream scene plus a sun/moon arcing by the system clock.

struct SkyModel {
    let date: Date

    private var hour: Double {
        let c = Calendar.current
        return Double(c.component(.hour, from: date)) + Double(c.component(.minute, from: date)) / 60.0
    }

    enum Band { case night, dawn, day, dusk }

    var band: Band {
        switch hour {
        case 5..<8:   return .dawn
        case 8..<17:  return .day
        case 17..<20: return .dusk
        default:      return .night
        }
    }

    var isMoon: Bool { band == .night }

    /// Sky gradient (top, bottom) — gentle pastel washes.
    var sky: (top: Color, bottom: Color) {
        switch band {
        case .dawn:  return (Color(red: 0.99, green: 0.86, blue: 0.78), Color(red: 0.99, green: 0.94, blue: 0.86))
        case .day:   return (Color(red: 0.86, green: 0.92, blue: 0.95), Color(red: 0.97, green: 0.95, blue: 0.90))
        case .dusk:  return (Color(red: 0.98, green: 0.82, blue: 0.66), Color(red: 0.98, green: 0.92, blue: 0.83))
        case .night: return (Color(red: 0.82, green: 0.83, blue: 0.90), Color(red: 0.93, green: 0.92, blue: 0.94))
        }
    }

    var celestialColor: Color {
        switch band {
        case .day:   return Color(red: 0.97, green: 0.78, blue: 0.34)
        case .dawn, .dusk: return Color(red: 0.96, green: 0.65, blue: 0.36)
        case .night: return Color(red: 0.95, green: 0.95, blue: 0.99)
        }
    }

    /// Position of the sun/moon as fractions of the available area (x: 0 left…1 right,
    /// y: 0 top…1 lower). Arc peaks high mid-passage.
    var celestialPosition: (x: Double, y: Double) {
        let t: Double
        if isMoon {
            // Night spans 20:00 → 06:00 (10h).
            let nh = hour >= 20 ? hour - 20 : hour + 4
            t = min(max(nh / 10.0, 0), 1)
        } else {
            // Daylight 06:00 → 20:00 (14h).
            t = min(max((hour - 6) / 14.0, 0), 1)
        }
        let x = 0.14 + t * 0.72
        let y = 0.34 - sin(.pi * t) * 0.22
        return (x, y)
    }
}

// MARK: - Breeze (drifting leaves)

struct BreezeLayer: View {
    var paused: Bool          // wilted → slower/fewer; reduce-motion → static
    var reduceMotion: Bool

    private let leaves: [LeafSpec] = [
        LeafSpec(yBase: 0.18, speed: 26, phase: 0.0, size: 16, tint: Color(red: 0.45, green: 0.62, blue: 0.22)),
        LeafSpec(yBase: 0.42, speed: 34, phase: 0.45, size: 13, tint: Color(red: 0.55, green: 0.68, blue: 0.30)),
        LeafSpec(yBase: 0.66, speed: 30, phase: 0.8, size: 18, tint: Color(red: 0.38, green: 0.55, blue: 0.20)),
    ]

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                EmptyView()  // no drifting motion
            } else {
                TimelineView(.animation(paused: false)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    ForEach(leaves) { leaf in
                        leafView(leaf, t: t, size: geo.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func leafView(_ leaf: LeafSpec, t: Double, size: CGSize) -> some View {
        let speed = paused ? leaf.speed * 2.4 : leaf.speed      // wilted = sluggish
        let cycle = ((t / speed) + leaf.phase).truncatingRemainder(dividingBy: 1)
        let x = -0.1 + cycle * 1.2                              // drift left → right, offscreen ends
        let drift = sin((cycle * 2 + leaf.phase) * .pi * 2) * 0.05
        let y = leaf.yBase + drift
        let rotation = sin((cycle * 3 + leaf.phase) * .pi * 2) * 28
        let fade = sin(cycle * .pi)                             // fade in/out at the edges
        return Image(systemName: "leaf.fill")
            .font(.system(size: leaf.size))
            .foregroundStyle(leaf.tint.opacity((paused ? 0.25 : 0.5) * fade))
            .rotationEffect(.degrees(rotation))
            .position(x: size.width * x, y: size.height * y)
    }

    private struct LeafSpec: Identifiable {
        let id = UUID()
        let yBase: Double
        let speed: Double
        let phase: Double
        let size: CGFloat
        let tint: Color
    }
}

// MARK: - Wandering cat

struct WanderingCat: View {
    var asleep: Bool          // wilted or reduce-motion → curled up, still
    var reduceMotion: Bool
    var onTap: (() -> Void)? = nil

    @State private var pop = false

    // Roam targets scattered across the garden (x,y fractions), not a single floor line.
    private let waypoints: [CGPoint] = [
        CGPoint(x: 0.20, y: 0.86), CGPoint(x: 0.70, y: 0.80), CGPoint(x: 0.46, y: 0.64),
        CGPoint(x: 0.82, y: 0.52), CGPoint(x: 0.30, y: 0.50), CGPoint(x: 0.58, y: 0.74),
        CGPoint(x: 0.16, y: 0.66),
    ]
    private let travel = 4.6      // seconds gliding between waypoints
    private let pause  = 2.6      // seconds resting at each

    var body: some View {
        GeometryReader { geo in
            if asleep || reduceMotion {
                sleeping
                    .scaleEffect(pop ? 1.25 : 1)
                    .contentShape(Rectangle())
                    .onTapGesture { tapped() }
                    .position(x: geo.size.width * 0.74, y: geo.size.height * 0.84)
            } else {
                TimelineView(.animation) { ctx in
                    let s = state(at: ctx.date.timeIntervalSinceReferenceDate)
                    let depth = 0.84 + s.point.y * 0.34            // nearer (lower) = bigger
                    CatView(asleep: false, walkPhase: s.walkPhase, height: 30 * depth)
                        .scaleEffect(x: s.facingLeft ? -1 : 1)
                        .scaleEffect(pop ? 1.25 : 1)
                        .contentShape(Rectangle())
                        .onTapGesture { tapped() }
                        .position(x: geo.size.width * s.point.x,
                                  y: geo.size.height * s.point.y - s.bob)
                }
            }
        }
        .allowsHitTesting(onTap != nil)
        .accessibilityHidden(true)
    }

    /// Meow + a happy little bounce when the cat is tapped.
    private func tapped() {
        guard let onTap else { return }
        onTap()
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { pop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pop = false }
        }
    }

    private var sleeping: some View {
        ZStack(alignment: .topTrailing) {
            CatView(asleep: true, walkPhase: 0, height: 34)
            Text("z z").font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Garden.inkSoft.opacity(0.7))
                .offset(x: 16, y: -8)
        }
    }

    /// Interpolate along the waypoint loop with eased travel and flat rests.
    private func state(at t: Double) -> (point: CGPoint, facingLeft: Bool, walkPhase: Double, bob: CGFloat) {
        let legTime = travel + pause
        let n = waypoints.count
        let tt = t.truncatingRemainder(dividingBy: legTime * Double(n))
        let i = Int(tt / legTime)
        let local = tt - Double(i) * legTime
        let from = waypoints[i]
        let to = waypoints[(i + 1) % n]

        let moving = local < travel
        let p = moving ? smooth(local / travel) : 1.0
        let x = from.x + (to.x - from.x) * p
        let y = from.y + (to.y - from.y) * p
        let facingLeft = (to.x - from.x) < 0
        let walkPhase = moving ? t * 8 : 0
        let bob = moving ? CGFloat(abs(sin(t * 8))) * 2.4 : 0
        return (CGPoint(x: x, y: y), facingLeft, walkPhase, bob)
    }

    private func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}

// MARK: - Cat illustration (vector, drawn to match the cozy garden art)

struct CatView: View {
    var asleep: Bool
    var walkPhase: Double
    var height: CGFloat

    private let coat     = Color(red: 0.90, green: 0.62, blue: 0.34)
    private let coatDark = Color(red: 0.78, green: 0.48, blue: 0.24)
    private let cream    = Color(red: 0.98, green: 0.94, blue: 0.86)
    private let ink      = Color(red: 0.27, green: 0.18, blue: 0.12)
    private let pink     = Color(red: 0.93, green: 0.66, blue: 0.62)

    var body: some View {
        Canvas { ctx, size in
            if asleep { drawCurled(&ctx, size) } else { drawWalking(&ctx, size) }
        }
        .frame(width: height * 1.42, height: height)
    }

    // Facing right; the parent flips horizontally for leftward travel.
    private func drawWalking(_ ctx: inout GraphicsContext, _ s: CGSize) {
        let w = s.width, h = s.height
        func R(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat) -> CGRect {
            CGRect(x: x * w, y: y * h, width: ww * w, height: hh * h)
        }
        func Pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }

        let swing = CGFloat(sin(walkPhase)) * 0.03 * w

        // Legs (behind body)
        for (lx, dir) in [(0.30, 1.0), (0.40, -1.0), (0.60, -1.0), (0.70, 1.0)] {
            let leg = Path(roundedRect: CGRect(x: CGFloat(lx) * w - 0.03 * w + swing * CGFloat(dir),
                                               y: 0.66 * h, width: 0.075 * w, height: 0.30 * h),
                           cornerSize: CGSize(width: 0.035 * w, height: 0.035 * w))
            ctx.fill(leg, with: .color(coatDark))
        }

        // Tail
        var tail = Path()
        let tsway = CGFloat(sin(walkPhase * 0.5)) * 0.05
        tail.move(to: Pt(0.18, 0.66))
        tail.addQuadCurve(to: Pt(0.04 + tsway, 0.18), control: Pt(-0.04, 0.52))
        ctx.stroke(tail, with: .color(coat), style: StrokeStyle(lineWidth: 0.085 * w, lineCap: .round))
        ctx.fill(Path(ellipseIn: R(0.0 + tsway, 0.13, 0.10, 0.10)), with: .color(cream))

        // Body + belly
        ctx.fill(Path(ellipseIn: R(0.16, 0.44, 0.60, 0.42)), with: .color(coat))
        ctx.fill(Path(ellipseIn: R(0.26, 0.62, 0.40, 0.24)), with: .color(cream))

        // Ears (behind head)
        var earL = Path(); earL.move(to: Pt(0.64, 0.34)); earL.addLine(to: Pt(0.66, 0.16)); earL.addLine(to: Pt(0.75, 0.30)); earL.closeSubpath()
        var earR = Path(); earR.move(to: Pt(0.80, 0.30)); earR.addLine(to: Pt(0.90, 0.16)); earR.addLine(to: Pt(0.91, 0.36)); earR.closeSubpath()
        ctx.fill(earL, with: .color(coat)); ctx.fill(earR, with: .color(coat))
        var earLi = Path(); earLi.move(to: Pt(0.67, 0.30)); earLi.addLine(to: Pt(0.68, 0.22)); earLi.addLine(to: Pt(0.73, 0.30)); earLi.closeSubpath()
        ctx.fill(earLi, with: .color(pink))

        // Head + muzzle
        ctx.fill(Path(ellipseIn: R(0.60, 0.26, 0.34, 0.36)), with: .color(coat))
        ctx.fill(Path(ellipseIn: R(0.72, 0.44, 0.20, 0.16)), with: .color(cream))

        // Tabby stripes
        for sx in [0.34, 0.44, 0.54] {
            var st = Path(); st.move(to: Pt(CGFloat(sx), 0.46)); st.addLine(to: Pt(CGFloat(sx) - 0.02, 0.6))
            ctx.stroke(st, with: .color(coatDark), style: StrokeStyle(lineWidth: 0.028 * w, lineCap: .round))
        }
        for hy in [0.30, 0.37] {
            var st = Path(); st.move(to: Pt(0.70, CGFloat(hy))); st.addLine(to: Pt(0.78, CGFloat(hy) - 0.015))
            ctx.stroke(st, with: .color(coatDark), style: StrokeStyle(lineWidth: 0.022 * w, lineCap: .round))
        }

        // Eye + nose
        ctx.fill(Path(ellipseIn: R(0.785, 0.40, 0.04, 0.055)), with: .color(ink))
        ctx.fill(Path(ellipseIn: R(0.86, 0.50, 0.03, 0.025)), with: .color(pink))
    }

    private func drawCurled(_ ctx: inout GraphicsContext, _ s: CGSize) {
        let w = s.width, h = s.height
        func R(_ x: CGFloat, _ y: CGFloat, _ ww: CGFloat, _ hh: CGFloat) -> CGRect {
            CGRect(x: x * w, y: y * h, width: ww * w, height: hh * h)
        }
        func Pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }

        // Curled body
        ctx.fill(Path(ellipseIn: R(0.10, 0.40, 0.78, 0.50)), with: .color(coat))
        // Tail wrapped along the front
        var tail = Path()
        tail.move(to: Pt(0.18, 0.74))
        tail.addQuadCurve(to: Pt(0.82, 0.80), control: Pt(0.5, 1.02))
        ctx.stroke(tail, with: .color(coatDark), style: StrokeStyle(lineWidth: 0.075 * w, lineCap: .round))
        // Head tucked
        ctx.fill(Path(ellipseIn: R(0.58, 0.50, 0.30, 0.30)), with: .color(coat))
        ctx.fill(Path(ellipseIn: R(0.66, 0.62, 0.16, 0.12)), with: .color(cream))
        // Ears
        var earL = Path(); earL.move(to: Pt(0.62, 0.54)); earL.addLine(to: Pt(0.62, 0.44)); earL.addLine(to: Pt(0.70, 0.52)); earL.closeSubpath()
        var earR = Path(); earR.move(to: Pt(0.80, 0.52)); earR.addLine(to: Pt(0.86, 0.44)); earR.addLine(to: Pt(0.86, 0.55)); earR.closeSubpath()
        ctx.fill(earL, with: .color(coat)); ctx.fill(earR, with: .color(coat))
        // Closed eye
        var eye = Path(); eye.move(to: Pt(0.72, 0.60)); eye.addQuadCurve(to: Pt(0.80, 0.60), control: Pt(0.76, 0.64))
        ctx.stroke(eye, with: .color(ink), style: StrokeStyle(lineWidth: 0.018 * w, lineCap: .round))
        // Back stripes
        for sx in [0.30, 0.42, 0.54] {
            var st = Path(); st.move(to: Pt(CGFloat(sx), 0.44)); st.addLine(to: Pt(CGFloat(sx) - 0.02, 0.58))
            ctx.stroke(st, with: .color(coatDark), style: StrokeStyle(lineWidth: 0.025 * w, lineCap: .round))
        }
    }
}
