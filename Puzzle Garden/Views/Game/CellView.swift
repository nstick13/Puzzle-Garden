import SwiftUI

/// Earthy botanical palette — one color per region ID. Holds 10 distinct hues so
/// no plot ever reuses a color up through 10×10 (largest planned grid); only wraps
/// beyond that. The 9th/10th were added so 9×9 doesn't repeat sage.
let regionColors: [Color] = [
    Color(red: 0.76, green: 0.88, blue: 0.72),  // sage
    Color(red: 0.95, green: 0.85, blue: 0.65),  // wheat
    Color(red: 0.85, green: 0.72, blue: 0.88),  // lavender
    Color(red: 0.95, green: 0.75, blue: 0.70),  // terracotta
    Color(red: 0.72, green: 0.85, blue: 0.88),  // sky
    Color(red: 0.88, green: 0.88, blue: 0.68),  // butter
    Color(red: 0.80, green: 0.70, blue: 0.65),  // dusty rose
    Color(red: 0.70, green: 0.80, blue: 0.76),  // seafoam
    Color(red: 0.72, green: 0.74, blue: 0.93),  // periwinkle
    Color(red: 0.93, green: 0.74, blue: 0.80),  // blush
]

struct CellView: View {
    let state: CellState
    let regionID: Int
    let isConflict: Bool
    let isCorrect: Bool?   // nil = not a flower; true/false = matches solution or not
    let size: CGFloat
    var popAnimation: Bool = false

    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            regionColors[regionID % regionColors.count]

            if isConflict {
                Color.red.opacity(0.30)
            }

            switch state {
            case .empty:
                EmptyView()
            case .marked:
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Color(red: 0.4, green: 0.3, blue: 0.2).opacity(0.7))
            case .flower:
                if isCorrect == false {
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.38, weight: .semibold))
                        .foregroundStyle(Color.red)
                } else {
                    Text("🌿")
                        .font(.system(size: size * 0.48))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .scaleEffect(scale)
                }
            }
        }
        .frame(width: size, height: size)
        .border(Color(white: 0.55), width: 0.5)
        .onChange(of: popAnimation) { _, shouldPop in
            guard shouldPop else { return }
            scale = 1.4
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                scale = 1.0
            }
        }
    }

}

#Preview {
    HStack(spacing: 0) {
        CellView(state: .empty,  regionID: 0, isConflict: false, isCorrect: nil,   size: 60)
        CellView(state: .marked, regionID: 1, isConflict: false, isCorrect: nil,   size: 60)
        CellView(state: .flower, regionID: 2, isConflict: false, isCorrect: true,  size: 60)
        CellView(state: .flower, regionID: 3, isConflict: false, isCorrect: false, size: 60)
    }
}
