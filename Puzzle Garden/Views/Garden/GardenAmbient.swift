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

// MARK: - Sky background (sits behind the scrolling beds)

struct SkyBackground: View {
    let model: SkyModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [model.sky.top, model.sky.bottom],
                               startPoint: .top, endPoint: .bottom)

                celestial
                    .position(
                        x: geo.size.width * model.celestialPosition.x,
                        y: geo.size.height * model.celestialPosition.y
                    )
            }
        }
        .ignoresSafeArea()
    }

    private var celestial: some View {
        ZStack {
            Circle()
                .fill(model.celestialColor.opacity(0.28))
                .frame(width: 96, height: 96)
                .blur(radius: 14)
            Circle()
                .fill(model.celestialColor)
                .frame(width: 52, height: 52)
            if model.isMoon {
                // Soft crescent: a cream-tinted overlay nudged aside.
                Circle()
                    .fill(model.sky.top)
                    .frame(width: 44, height: 44)
                    .offset(x: 12, y: -6)
                    .blur(radius: 1)
            }
        }
        .accessibilityHidden(true)
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

    var body: some View {
        GeometryReader { geo in
            if asleep || reduceMotion {
                catView(flip: false, bob: 0)
                    .position(x: geo.size.width * 0.78, y: geo.size.height - 18)
            } else {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let c = (t.truncatingRemainder(dividingBy: 26)) / 26   // 0…1 saunter cycle
                    let pos = catPosition(c)
                    let bob = abs(sin(t * 3.2)) * 2.0
                    catView(flip: pos.flip, bob: bob)
                        .position(x: geo.size.width * pos.x, y: geo.size.height - 18 - bob)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func catView(flip: Bool, bob: Double) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(asleep ? "🐈" : "🐈")
                .font(.system(size: 30))
                .scaleEffect(x: flip ? -1 : 1, y: 1)
                .opacity(asleep ? 0.85 : 1)
            if asleep {
                Text("💤")
                    .font(.system(size: 14))
                    .offset(x: 14, y: -10)
            }
        }
    }

    /// Saunter right, pause, saunter left, pause — eased, with flat rests.
    private func catPosition(_ c: Double) -> (x: Double, flip: Bool) {
        func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
        if c < 0.40 {
            return (0.16 + ease(c / 0.40) * 0.66, false)
        } else if c < 0.50 {
            return (0.82, false)
        } else if c < 0.90 {
            return (0.82 - ease((c - 0.50) / 0.40) * 0.66, true)
        } else {
            return (0.16, true)
        }
    }
}
