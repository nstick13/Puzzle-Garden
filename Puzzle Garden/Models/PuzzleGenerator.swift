import Foundation

/// Generates valid, uniquely-solvable Queens puzzles for Puzzle Garden.
///
/// Algorithm:
///   1. Build N contiguous regions via randomized flood-fill.
///   2. Backtrack to place N queens satisfying all constraints — this IS the solution.
///   3. Verify the region map + empty grid has exactly one solution (should always pass
///      for well-formed regions, but we double-check and retry if not).
enum PuzzleGenerator {

    // MARK: - Public

    /// Generates a puzzle for the given difficulty, seeded deterministically.
    ///
    /// - Parameters:
    ///   - difficulty: Grid size (5, 6, or 7).
    ///   - seed: Deterministic seed. Pass `DailyPuzzleManager.todaySeed()` for the daily puzzle.
    /// - Returns: A fully validated `Puzzle`, or `nil` if generation fails after `maxAttempts`.
    nonisolated static func generate(difficulty: GridSize, seed: UInt64) -> Puzzle? {
        var rng = SeededRNG(seed: seed)
        let n   = difficulty.rawValue

        for _ in 0..<50 {   // retry budget
            guard let regions  = makeRegions(n: n, rng: &rng),
                  let solution = solveRandom(n: n, regions: regions, rng: &rng)
            else { continue }

            let empty = Array(repeating: Array(repeating: 0, count: n), count: n)
            guard QueensSolver.countSolutions(empty, regions) == 1 else { continue }

            return Puzzle(grid: empty, regions: regions, solution: solution, difficulty: difficulty)
        }
        return nil
    }

    /// Generates a solved grid (for testing / pre-generation).
    static func generateSolvedGrid(size: Int, rng: inout SeededRNG) -> [[Int]]? {
        let dummy = makeRegionsUnchecked(n: size, rng: &rng)
        return solveRandom(n: size, regions: dummy, rng: &rng)
    }

    // MARK: - Region generation

    /// Flood-fill region partition. Returns nil if it can't assign all cells.
    private static func makeRegions(n: Int, rng: inout SeededRNG) -> [[Int]]? {
        let regions = makeRegionsUnchecked(n: n, rng: &rng)
        // Verify every region ID 0..<n appears at least once
        let ids = Set(regions.flatMap { $0 })
        guard ids.count == n else { return nil }
        return regions
    }

    private static func makeRegionsUnchecked(n: Int, rng: inout SeededRNG) -> [[Int]] {
        var grid = Array(repeating: Array(repeating: -1, count: n), count: n)

        // Pick one random seed cell per region
        var allCells = (0..<n*n).map { ($0 / n, $0 % n) }.shuffled(using: &rng)
        var frontiers: [[( Int, Int)]] = []

        for regionID in 0..<n {
            let (sr, sc) = allCells.removeLast()
            grid[sr][sc] = regionID
            frontiers.append(neighbors(sr, sc, n: n).filter { grid[$0][$1] == -1 })
        }

        // Expand frontiers round-robin until all cells assigned
        var unassigned = n * n - n
        while unassigned > 0 {
            for regionID in 0..<n where unassigned > 0 {
                var frontier = frontiers[regionID].filter { grid[$0][$1] == -1 }
                if frontier.isEmpty { continue }
                frontier.shuffle(using: &rng)
                let (r, c) = frontier.removeLast()
                if grid[r][c] != -1 { continue }
                grid[r][c] = regionID
                unassigned -= 1
                frontier += neighbors(r, c, n: n).filter { grid[$0][$1] == -1 }
                frontiers[regionID] = frontier
            }
        }

        // Fill any remaining -1 cells (shouldn't happen, but be safe)
        for r in 0..<n {
            for c in 0..<n where grid[r][c] == -1 {
                grid[r][c] = rng.next(upperBound: UInt64(n))
            }
        }
        return grid
    }

    private static func neighbors(_ r: Int, _ c: Int, n: Int) -> [(Int, Int)] {
        [(r-1,c),(r+1,c),(r,c-1),(r,c+1)].filter { $0.0 >= 0 && $0.0 < n && $0.1 >= 0 && $0.1 < n }
    }

    // MARK: - Randomised solve

    /// Backtrack with randomised column order so each run produces a different solution layout.
    private static func solveRandom(n: Int, regions: [[Int]], rng: inout SeededRNG) -> [[Int]]? {
        var board       = Array(repeating: Array(repeating: 0, count: n), count: n)
        var usedCols    = Set<Int>(minimumCapacity: n)
        var usedRegions = Set<Int>(minimumCapacity: n)
        let colOrders   = (0..<n).map { _ in Array(0..<n).shuffled(using: &rng) }

        guard _randomSolve(&board, regions, colOrders: colOrders, row: 0, n: n,
                           usedCols: &usedCols, usedRegions: &usedRegions)
        else { return nil }
        return board
    }

    private static func _randomSolve(
        _ board: inout [[Int]],
        _ regions: [[Int]],
        colOrders: [[Int]],
        row: Int,
        n: Int,
        usedCols: inout Set<Int>,
        usedRegions: inout Set<Int>
    ) -> Bool {
        if row == n { return true }

        for col in colOrders[row] {
            guard !usedCols.contains(col) else { continue }
            let region = regions[row][col]
            guard !usedRegions.contains(region) else { continue }
            guard !hasAdjacentDiagonal(board, row: row, col: col) else { continue }

            board[row][col] = 1
            usedCols.insert(col)
            usedRegions.insert(region)

            if _randomSolve(&board, regions, colOrders: colOrders, row: row + 1, n: n,
                            usedCols: &usedCols, usedRegions: &usedRegions) {
                return true
            }

            board[row][col] = 0
            usedCols.remove(col)
            usedRegions.remove(region)
        }
        return false
    }

    private static func hasAdjacentDiagonal(_ board: [[Int]], row: Int, col: Int) -> Bool {
        let prevRow = row - 1
        guard prevRow >= 0 else { return false }
        let n = board[prevRow].count
        if col > 0     && board[prevRow][col - 1] == 1 { return true }
        if col < n - 1 && board[prevRow][col + 1] == 1 { return true }
        return false
    }
}

// MARK: - Seeded RNG

/// A fast, deterministic pseudo-random number generator (xorshift64).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Ensure non-zero state
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return x
    }

    /// Returns a value in `0 ..< upperBound`.
    mutating func next(upperBound: UInt64) -> Int {
        Int(next() % upperBound)
    }
}

// MARK: - Daily puzzle seed helper

enum DailyPuzzleManager {
    /// Produces the same seed for every call on the same calendar day (device locale-independent).
    static func todaySeed() -> UInt64 {
        let cal  = Calendar(identifier: .gregorian)
        let now  = Date()
        let year = UInt64(cal.component(.year,  from: now))
        let mon  = UInt64(cal.component(.month, from: now))
        let day  = UInt64(cal.component(.day,   from: now))
        // Simple, collision-free encoding
        return year &* 10_000 &+ mon &* 100 &+ day
    }
}
