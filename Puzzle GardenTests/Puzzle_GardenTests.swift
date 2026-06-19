import Testing
@testable import Puzzle_Garden

struct QueensSolverTests {

    // A hand-crafted 5×5 region map with a known unique solution.
    // Regions 0-4 each form a distinct contiguous zone.
    //
    //   0 0 1 1 1
    //   0 0 1 2 2
    //   0 3 3 2 2
    //   4 3 3 3 2
    //   4 4 4 4 4
    let regions5: [[Int]] = [
        [0, 0, 1, 1, 1],
        [0, 0, 1, 2, 2],
        [0, 3, 3, 2, 2],
        [4, 3, 3, 3, 2],
        [4, 4, 4, 4, 4],
    ]

    @Test func solverFindsASolution() {
        var board = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        let found = QueensSolver.solve(&board, regions5)
        #expect(found)
    }

    @Test func solutionSatisfiesAllConstraints() {
        var board = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        _ = QueensSolver.solve(&board, regions5)

        let n = 5
        // One queen per row
        for r in 0..<n {
            #expect(board[r].reduce(0, +) == 1, "Row \(r) must have exactly 1 queen")
        }
        // One queen per column
        for c in 0..<n {
            let colCount = (0..<n).filter { board[$0][c] == 1 }.count
            #expect(colCount == 1, "Column \(c) must have exactly 1 queen")
        }
        // One queen per region
        var regionCounts = [Int: Int]()
        for r in 0..<n {
            for c in 0..<n where board[r][c] == 1 {
                regionCounts[regions5[r][c], default: 0] += 1
            }
        }
        for id in 0..<n {
            #expect(regionCounts[id] == 1, "Region \(id) must have exactly 1 queen")
        }
        // No diagonal adjacency
        let queenPositions = (0..<n).flatMap { r in (0..<n).compactMap { c in board[r][c] == 1 ? (r, c) : nil } }
        for i in 0..<queenPositions.count {
            for j in (i+1)..<queenPositions.count {
                let (r1, c1) = queenPositions[i]
                let (r2, c2) = queenPositions[j]
                #expect(!(abs(r1 - r2) == 1 && abs(c1 - c2) == 1),
                        "Queens at (\(r1),\(c1)) and (\(r2),\(c2)) are diagonally adjacent")
            }
        }
    }

    @Test func isValidRejectsColumnConflict() {
        var board = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        board[0][2] = 1
        #expect(!QueensSolver.isValid(board, regions5, 1, 2))
    }

    @Test func isValidRejectsDiagonalAdjacency() {
        var board = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        board[0][2] = 1
        #expect(!QueensSolver.isValid(board, regions5, 1, 3))
        #expect(!QueensSolver.isValid(board, regions5, 1, 1))
    }

    @Test func countSolutionsReturnsOneForWellFormedBoard() {
        let empty = Array(repeating: Array(repeating: 0, count: 5), count: 5)
        let count = QueensSolver.countSolutions(empty, regions5)
        #expect(count == 1)
    }
}

struct PuzzleGeneratorTests {

    @Test func generateReturnsPuzzleFor5x5() {
        let puzzle = PuzzleGenerator.generate(difficulty: .five, seed: 42)
        #expect(puzzle != nil)
        if let p = puzzle {
            #expect(p.size == 5)
            #expect(p.grid.count == 5)
            #expect(p.regions.count == 5)
            #expect(p.solution.count == 5)
        }
    }

    @Test func generateIsDeterministic() {
        let seed: UInt64 = 20260612
        let p1 = PuzzleGenerator.generate(difficulty: .five, seed: seed)
        let p2 = PuzzleGenerator.generate(difficulty: .five, seed: seed)
        #expect(p1?.solution == p2?.solution)
        #expect(p1?.regions == p2?.regions)
    }

    @Test func generatedPuzzleHasUniqueSolution() {
        guard let puzzle = PuzzleGenerator.generate(difficulty: .five, seed: 99) else {
            Issue.record("Generator returned nil")
            return
        }
        let count = QueensSolver.countSolutions(puzzle.grid, puzzle.regions)
        #expect(count == 1)
    }

    @Test func dailySeedIsStable() {
        let s1 = DailyPuzzleManager.todaySeed()
        let s2 = DailyPuzzleManager.todaySeed()
        #expect(s1 == s2)
        #expect(s1 > 0)
    }

    @Test func generateFor6x6() {
        let puzzle = PuzzleGenerator.generate(difficulty: .six, seed: 777)
        #expect(puzzle != nil)
        if let p = puzzle {
            #expect(p.size == 6)
        }
    }

    @Test func generationCompletesQuickly() {
        // Soft performance check — not a hard deadline, but surfaces regressions.
        let start = Date()
        _ = PuzzleGenerator.generate(difficulty: .seven, seed: 12345)
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 5.0, "7×7 generation took \(elapsed)s — investigate if consistently slow")
    }
}
