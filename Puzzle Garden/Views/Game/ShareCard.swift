import SwiftUI

// MARK: - Share card view

struct ShareCardView: View {
    let puzzle: Puzzle
    let elapsedSeconds: Int

    // Colored-square emojis indexed by region ID (up to 7 regions).
    private let regionEmojis = ["🟫", "🟩", "🟦", "🟧", "🟨", "🟥", "🟪"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            grid
            footer
        }
        .padding(20)
        .background(Color(red: 0.97, green: 0.95, blue: 0.90))
        .cornerRadius(18)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("🌿")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("Puzzle Garden")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(Color(red: 0.20, green: 0.38, blue: 0.22))
                Text("\(puzzle.difficulty.label) · \(timeString)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
            }
            Spacer()
        }
    }

    private var grid: some View {
        let emojiSize: CGFloat = puzzle.size <= 5 ? 32 : puzzle.size == 6 ? 28 : 24
        return VStack(spacing: 2) {
            ForEach(0..<puzzle.size, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<puzzle.size, id: \.self) { col in
                        let isFlower = puzzle.solution[row][col] == 1
                        let regionID = puzzle.regions[row][col]
                        Text(isFlower ? "🌸" : regionEmojis[regionID % regionEmojis.count])
                            .font(.system(size: emojiSize))
                    }
                }
            }
        }
    }

    private var footer: some View {
        Text("puzzlegarden.app")
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 0.35))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var timeString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Render helper

extension ShareCardView {
    @MainActor
    func rendered() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

// MARK: - Preview

#Preview {
    let regions: [[Int]] = [
        [0, 0, 1, 1, 1],
        [0, 0, 1, 2, 2],
        [0, 3, 3, 2, 2],
        [4, 3, 3, 3, 2],
        [4, 4, 4, 4, 4],
    ]
    let empty = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    var solution = empty
    _ = QueensSolver.solve(&solution, regions)
    let puzzle = Puzzle(grid: empty, regions: regions, solution: solution, difficulty: .five)
    return ShareCardView(puzzle: puzzle, elapsedSeconds: 154)
        .padding()
        .background(Color.gray.opacity(0.2))
}
