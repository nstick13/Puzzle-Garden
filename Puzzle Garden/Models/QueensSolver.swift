import Foundation

/// Backtracking solver for the Queens / Star Battle variant used in Puzzle Garden.
///
/// Rules enforced per placement:
///   • At most one queen per row (ensured structurally — we place one queen per row)
///   • At most one queen per column
///   • At most one queen per region
///   • No two queens are diagonally adjacent (distance-1 diagonal only)
///
/// Note: The LinkedIn/Puzzle Garden diagonal rule is adjacency-only (|Δr|==1 && |Δc|==1),
/// NOT the full N-Queens "no shared diagonal" rule. This matches the actual game.
enum QueensSolver {

    // MARK: - Public API

    /// Fills `board` in-place with a valid solution. Returns `true` if one was found.
    @discardableResult
    static func solve(_ board: inout [[Int]], _ regions: [[Int]]) -> Bool {
        let n = board.count
        var usedCols    = Set<Int>(minimumCapacity: n)
        var usedRegions = Set<Int>(minimumCapacity: n)
        return _solve(&board, regions, row: 0, n: n,
                      usedCols: &usedCols, usedRegions: &usedRegions)
    }

    /// Validates whether placing a queen at (row, col) is legal given the current board state.
    static func isValid(_ board: [[Int]], _ regions: [[Int]], _ row: Int, _ col: Int) -> Bool {
        let n = board.count
        // Column conflict
        for r in 0..<row where board[r][col] == 1 { return false }

        // Region conflict
        let region = regions[row][col]
        for r in 0..<n {
            for c in 0..<n where regions[r][c] == region && board[r][c] == 1 { return false }
        }

        // Diagonal adjacency conflict (distance-1 only)
        for r in 0..<row {
            for c in 0..<n where board[r][c] == 1 {
                if abs(r - row) == 1 && abs(c - col) == 1 { return false }
            }
        }

        return true
    }

    /// Returns 0, 1, or 2 — stops counting after finding a second solution (uniqueness check).
    static func countSolutions(_ board: [[Int]], _ regions: [[Int]]) -> Int {
        var copy        = board
        var usedCols    = Set<Int>()
        var usedRegions = Set<Int>()
        var count       = 0
        _count(&copy, regions, row: 0, n: board.count,
               usedCols: &usedCols, usedRegions: &usedRegions, count: &count)
        return count
    }

    // MARK: - Internal

    private static func _solve(
        _ board: inout [[Int]],
        _ regions: [[Int]],
        row: Int,
        n: Int,
        usedCols: inout Set<Int>,
        usedRegions: inout Set<Int>
    ) -> Bool {
        if row == n { return true }

        for col in 0..<n {
            guard !usedCols.contains(col) else { continue }
            let region = regions[row][col]
            guard !usedRegions.contains(region) else { continue }
            guard !hasAdjacentDiagonal(board, row: row, col: col) else { continue }

            board[row][col] = 1
            usedCols.insert(col)
            usedRegions.insert(region)

            if _solve(&board, regions, row: row + 1, n: n,
                      usedCols: &usedCols, usedRegions: &usedRegions) {
                return true
            }

            board[row][col] = 0
            usedCols.remove(col)
            usedRegions.remove(region)
        }
        return false
    }

    private static func _count(
        _ board: inout [[Int]],
        _ regions: [[Int]],
        row: Int,
        n: Int,
        usedCols: inout Set<Int>,
        usedRegions: inout Set<Int>,
        count: inout Int
    ) {
        if row == n {
            count += 1
            return
        }
        if count >= 2 { return }   // early exit — we only need to know 0 / 1 / 2+

        for col in 0..<n {
            guard !usedCols.contains(col) else { continue }
            let region = regions[row][col]
            guard !usedRegions.contains(region) else { continue }
            guard !hasAdjacentDiagonal(board, row: row, col: col) else { continue }

            board[row][col] = 1
            usedCols.insert(col)
            usedRegions.insert(region)

            _count(&board, regions, row: row + 1, n: n,
                   usedCols: &usedCols, usedRegions: &usedRegions, count: &count)

            board[row][col] = 0
            usedCols.remove(col)
            usedRegions.remove(region)

            if count >= 2 { return }
        }
    }

    /// Returns true if any already-placed queen in the rows above is diagonally adjacent (distance 1).
    private static func hasAdjacentDiagonal(_ board: [[Int]], row: Int, col: Int) -> Bool {
        let prevRow = row - 1
        guard prevRow >= 0 else { return false }
        let n = board[prevRow].count
        if col > 0     && board[prevRow][col - 1] == 1 { return true }
        if col < n - 1 && board[prevRow][col + 1] == 1 { return true }
        return false
    }
}
