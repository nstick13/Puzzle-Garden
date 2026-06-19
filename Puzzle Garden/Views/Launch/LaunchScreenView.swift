import SwiftUI

struct LaunchScreenView: View {
    private let warmGreen = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let warmGray  = Color(red: 0.45, green: 0.42, blue: 0.38)
    private let bg        = Color(red: 0.961, green: 0.941, blue: 0.910)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            VStack(spacing: 20) {
                MiniPlantIcon()

                Text("Puzzle Garden")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(warmGreen)

                Text("A garden that grows with you")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(warmGray)
            }
        }
    }
}

// Minimal plant: stem + two leaves + flower head using shapes only
private struct MiniPlantIcon: View {
    private let green    = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let secGreen = Color(red: 0.420, green: 0.561, blue: 0.278)
    private let terra    = Color(red: 0.769, green: 0.443, blue: 0.294)
    private let cream    = Color(red: 0.980, green: 0.965, blue: 0.933)

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2

            // Stem
            let stemRect = CGRect(x: cx - 3, y: cy - 4, width: 6, height: 38)
            let stemPath = Path(roundedRect: stemRect, cornerRadius: 3)
            ctx.fill(stemPath, with: .color(green))

            // Left leaf
            ctx.drawLayer { lCtx in
                lCtx.translateBy(x: cx - 18, y: cy + 10)
                lCtx.rotate(by: .degrees(30))
                let leaf = Path(ellipseIn: CGRect(x: -20, y: -10, width: 40, height: 18))
                lCtx.fill(leaf, with: .color(secGreen))
            }

            // Right leaf
            ctx.drawLayer { lCtx in
                lCtx.translateBy(x: cx + 18, y: cy + 14)
                lCtx.rotate(by: .degrees(-30))
                let leaf = Path(ellipseIn: CGRect(x: -20, y: -10, width: 40, height: 18))
                lCtx.fill(leaf, with: .color(green))
            }

            // Petals (6 around flower centre at cy - 20)
            let flowerY = cy - 22
            let petalDist: CGFloat = 17
            let petalW: CGFloat = 18
            let petalH: CGFloat = 10
            for i in 0..<6 {
                let angleDeg = Double(i) * 60 - 90
                let angleRad = angleDeg * .pi / 180
                ctx.drawLayer { lCtx in
                    lCtx.translateBy(x: cx + petalDist * CGFloat(cos(angleRad)),
                                     y: flowerY + petalDist * CGFloat(sin(angleRad)))
                    lCtx.rotate(by: .degrees(angleDeg + 90))
                    let petal = Path(ellipseIn: CGRect(x: -petalW/2, y: -petalH/2,
                                                       width: petalW, height: petalH))
                    lCtx.fill(petal, with: .color(terra.opacity(0.85)))
                }
            }

            // Flower centre
            let centreR: CGFloat = 11
            let centrePath = Path(ellipseIn: CGRect(x: cx - centreR, y: flowerY - centreR,
                                                    width: centreR*2, height: centreR*2))
            ctx.fill(centrePath, with: .color(cream))

            let dotR: CGFloat = 4
            let dotPath = Path(ellipseIn: CGRect(x: cx - dotR, y: flowerY - dotR,
                                                 width: dotR*2, height: dotR*2))
            ctx.fill(dotPath, with: .color(terra))
        }
        .frame(width: 88, height: 88)
    }
}

#Preview {
    LaunchScreenView()
}
