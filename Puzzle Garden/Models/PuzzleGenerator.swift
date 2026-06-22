import Foundation

/// Generates valid, uniquely-solvable Queens puzzles for Puzzle Garden.
///
/// Algorithm (solution-first):
///   1. Place N non-attacking queens (one per row/column, no diagonal adjacency) — this IS
///      the solution. Done before regions exist, so it's fast at any size.
///   2. Grow N contiguous regions outward from the queen cells (one seed per queen). Because
///      every region contains exactly one queen, the solution from step 1 is guaranteed valid
///      for the region map — so at least one solution always exists by construction.
///   3. Verify the puzzle has *exactly* one solution. If a region layout admits alternates,
///      reshape regions (new random growth) and retry.
///
/// This inversion matters at scale: growing regions around a known solution keeps the
/// unique-solution hit rate workable up to 9×9, where the old "random regions then solve"
/// approach produced essentially zero unique puzzles.
enum PuzzleGenerator {

    // MARK: - Public

    /// Generates a puzzle for the given difficulty, seeded deterministically.
    ///
    /// - Parameters:
    ///   - difficulty: Grid size (5 through 9).
    ///   - seed: Deterministic seed. Pass `DailyPuzzleManager.todaySeed()` for the daily puzzle.
    /// - Returns: A fully validated `Puzzle`, or `nil` if generation fails after the retry budget.
    nonisolated static func generate(difficulty: GridSize, seed: UInt64) -> Puzzle? {
        var rng = SeededRNG(seed: seed)
        let n   = difficulty.rawValue

        // Region growth + refinement is cheap; a failed daily (nil) is far worse than retries.
        // Only pathological seeds ever exhaust these, so the deep budget costs nothing typically.
        let attempts = n >= 8 ? 250 : 120

        // Most unique boards still require a guess to crack (empirically only ~15–20% are
        // fully no-guess solvable). We reject the rest so every puzzle has a fair logical
        // path — most importantly a forced *first flower*. A fully-fair board turns up within
        // a handful of attempts, well inside the budget.
        var fallback: Puzzle?     // best-effort if the budget somehow runs out
        var fallbackScore = -1

        for _ in 0..<attempts {
            guard let solution = placeQueens(n: n, rng: &rng) else { continue }

            var regions = growRegions(n: n, solution: solution, rng: &rng)
            // Reshape region boundaries until `solution` is the *only* solution.
            guard refineToUnique(regions: &regions, target: solution, n: n, rng: &rng) else { continue }

            let empty  = Array(repeating: Array(repeating: 0, count: n), count: n)
            let puzzle = Puzzle(grid: empty, regions: regions, solution: solution, difficulty: difficulty)

            let grade = LogicSolver.grade(regions: regions, n: n)
            if grade.fullySolved { return puzzle }

            // Hang onto the fairest board seen, so a degenerate seed still yields *a* puzzle
            // (graceful degradation) rather than nothing.
            if grade.placedByLogic > fallbackScore {
                fallbackScore = grade.placedByLogic
                fallback = puzzle
            }
        }
        return fallback
    }

    // MARK: - Step 3: refine regions to a unique solution

    /// Repeatedly finds an alternate solution and reshapes one boundary cell to invalidate it,
    /// leaving `target` as the sole solution. `target` always stays valid (we only ever move
    /// non-target cells), so the puzzle can never drop to zero solutions. Returns false if it
    /// can't converge within the iteration budget — the caller then retries from a fresh layout.
    private nonisolated static func refineToUnique(
        regions: inout [[Int]],
        target: [[Int]],
        n: Int,
        rng: inout SeededRNG
    ) -> Bool {
        for _ in 0..<(n * n * 4) {
            let sols = solutions(regions, n: n, limit: 2)
            if sols.count <= 1 { return sols.count == 1 }

            // The alternate to destroy: in it, some queen sits in a cell that target leaves empty.
            let alt = sols.first { $0 != target } ?? sols[0]

            var fixed = false
            for r in Array(0..<n).shuffled(using: &rng) {
                let altCol = alt[r].firstIndex(of: 1)!
                let tgtCol = target[r].firstIndex(of: 1)!
                if altCol == tgtCol { continue }   // (r, altCol) is non-target → safe to move

                let g = regions[r][altCol]
                // Hand the cell to an adjacent *different* region. alt then has two queens in
                // that region (invalid) while target — which leaves the cell empty — is untouched.
                guard let g2 = neighbors(r, altCol, n: n)
                    .map({ regions[$0.0][$0.1] })
                    .first(where: { $0 != g }) else { continue }
                // Don't disconnect the region we're carving from.
                guard regionContiguousWithout(regions, regionID: g, removing: (r, altCol), n: n) else { continue }

                regions[r][altCol] = g2
                fixed = true
                break
            }
            if !fixed { return false }
        }
        return false
    }

    /// Enumerates up to `limit` full solutions for a region map (used to detect alternates).
    private nonisolated static func solutions(_ regions: [[Int]], n: Int, limit: Int) -> [[[Int]]] {
        var board       = Array(repeating: Array(repeating: 0, count: n), count: n)
        var usedCols    = Set<Int>(minimumCapacity: n)
        var usedRegions = Set<Int>(minimumCapacity: n)
        var found: [[[Int]]] = []

        func recurse(_ row: Int) {
            if found.count >= limit { return }
            if row == n { found.append(board); return }
            for col in 0..<n {
                guard !usedCols.contains(col) else { continue }
                let region = regions[row][col]
                guard !usedRegions.contains(region) else { continue }
                guard !hasAdjacentDiagonal(board, row: row, col: col) else { continue }

                board[row][col] = 1; usedCols.insert(col); usedRegions.insert(region)
                recurse(row + 1)
                board[row][col] = 0; usedCols.remove(col); usedRegions.remove(region)
                if found.count >= limit { return }
            }
        }
        recurse(0)
        return found
    }

    /// True if region `regionID` stays a single connected component after removing `cell`.
    private nonisolated static func regionContiguousWithout(
        _ regions: [[Int]],
        regionID: Int,
        removing cell: (Int, Int),
        n: Int
    ) -> Bool {
        var members: [(Int, Int)] = []
        for r in 0..<n {
            for c in 0..<n where regions[r][c] == regionID && (r, c) != cell {
                members.append((r, c))
            }
        }
        guard let start = members.first else { return false }   // never empty a region

        var seen = Set<Int>([start.0 * n + start.1])
        var stack = [start]
        while let (r, c) = stack.popLast() {
            for (nr, nc) in neighbors(r, c, n: n) where regions[nr][nc] == regionID && (nr, nc) != cell {
                let key = nr * n + nc
                if seen.insert(key).inserted { stack.append((nr, nc)) }
            }
        }
        return seen.count == members.count
    }

    // MARK: - Step 1: place the solution

    /// Backtracking placement of one queen per row with randomised column order, enforcing
    /// distinct columns and no distance-1 diagonal adjacency. Returns the solved board.
    private nonisolated static func placeQueens(n: Int, rng: inout SeededRNG) -> [[Int]]? {
        var board     = Array(repeating: Array(repeating: 0, count: n), count: n)
        var usedCols  = Set<Int>(minimumCapacity: n)
        let colOrders = (0..<n).map { _ in Array(0..<n).shuffled(using: &rng) }

        guard _placeQueens(&board, colOrders: colOrders, row: 0, n: n, usedCols: &usedCols)
        else { return nil }
        return board
    }

    private nonisolated static func _placeQueens(
        _ board: inout [[Int]],
        colOrders: [[Int]],
        row: Int,
        n: Int,
        usedCols: inout Set<Int>
    ) -> Bool {
        if row == n { return true }

        for col in colOrders[row] {
            guard !usedCols.contains(col) else { continue }
            guard !hasAdjacentDiagonal(board, row: row, col: col) else { continue }

            board[row][col] = 1
            usedCols.insert(col)

            if _placeQueens(&board, colOrders: colOrders, row: row + 1, n: n, usedCols: &usedCols) {
                return true
            }

            board[row][col] = 0
            usedCols.remove(col)
        }
        return false
    }

    // MARK: - Step 2: grow regions from each queen

    /// Seeds one region per queen cell, then expands all regions round-robin via randomised
    /// flood-fill until every cell is claimed. Each region therefore contains exactly one queen.
    private nonisolated static func growRegions(n: Int, solution: [[Int]], rng: inout SeededRNG) -> [[Int]] {
        var grid = Array(repeating: Array(repeating: -1, count: n), count: n)
        var frontiers: [[(Int, Int)]] = []
        frontiers.reserveCapacity(n)

        // Region id = the queen's row index (0..<n), so all ids are guaranteed present.
        for r in 0..<n {
            let c = solution[r].firstIndex(of: 1)!
            grid[r][c] = r
            frontiers.append(neighbors(r, c, n: n).filter { grid[$0][$1] == -1 })
        }

        var unassigned = n * n - n
        while unassigned > 0 {
            var progressed = false
            for regionID in 0..<n where unassigned > 0 {
                var frontier = frontiers[regionID].filter { grid[$0][$1] == -1 }
                if frontier.isEmpty { continue }
                frontier.shuffle(using: &rng)
                let (r, c) = frontier.removeLast()
                if grid[r][c] != -1 { continue }
                grid[r][c] = regionID
                unassigned -= 1
                progressed = true
                frontier += neighbors(r, c, n: n).filter { grid[$0][$1] == -1 }
                frontiers[regionID] = frontier
            }
            // A stranded cell can occur if every neighbour was claimed first; hand it to any
            // adjacent region to keep regions contiguous.
            if !progressed {
                for r in 0..<n {
                    for c in 0..<n where grid[r][c] == -1 {
                        if let (nr, nc) = neighbors(r, c, n: n).first(where: { grid[$0][$1] != -1 }) {
                            grid[r][c] = grid[nr][nc]
                            unassigned -= 1
                        }
                    }
                }
                break
            }
        }
        return grid
    }

    private nonisolated static func neighbors(_ r: Int, _ c: Int, n: Int) -> [(Int, Int)] {
        [(r-1,c),(r+1,c),(r,c-1),(r,c+1)].filter { $0.0 >= 0 && $0.0 < n && $0.1 >= 0 && $0.1 < n }
    }

    private nonisolated static func hasAdjacentDiagonal(_ board: [[Int]], row: Int, col: Int) -> Bool {
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
