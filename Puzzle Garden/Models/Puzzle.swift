import Foundation

/// Grid size supported by the puzzle engine.
enum GridSize: Int, Codable, CaseIterable, Hashable {
    case five  = 5
    case six   = 6
    case seven = 7

    var label: String {
        "\(rawValue)×\(rawValue)"
    }
}

/// A fully-described Queens puzzle: empty grid, region map, and the unique solution.
struct Puzzle: Identifiable, Codable, Hashable {
    let id: UUID

    /// N×N grid shown to the player (0 = empty, 1 = queen/flower).
    var grid: [[Int]]

    /// N×N map of region IDs (0 ..< N). Cells with the same value belong to one plot.
    let regions: [[Int]]

    /// The unique solved grid, used for validation and win detection.
    let solution: [[Int]]

    let size: Int
    let difficulty: GridSize

    init(grid: [[Int]], regions: [[Int]], solution: [[Int]], difficulty: GridSize) {
        self.id         = UUID()
        self.grid       = grid
        self.regions    = regions
        self.solution   = solution
        self.size       = difficulty.rawValue
        self.difficulty = difficulty
    }
}
