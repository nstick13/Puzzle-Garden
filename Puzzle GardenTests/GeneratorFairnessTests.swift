import Testing
import Foundation
@testable import Puzzle_Garden

/// Guards the core promise: every generated puzzle must be solvable by pure logic with NO
/// guessing. Regression net for the generator's "only ship `LogicSolver.fullySolved` boards"
/// gate — a guess-requiring puzzle must never ship again.
struct GeneratorFairnessTests {

    /// For each *live-generated* grid size, generate many puzzles and assert each is produced,
    /// uniquely solvable, and fully solvable by the no-guess `LogicSolver`. 9×9 is excluded here
    /// because it's served from the bank (covered by `PuzzleBankTests`, which also keeps the
    /// shared cursor out of this parallel test).
    @Test(arguments: [GridSize.five, .six, .seven, .eight])
    func everyGeneratedPuzzleIsFairAndUnique(size: GridSize) {
        let n = size.rawValue
        let trials = n >= 8 ? 15 : 30

        for t in 0..<trials {
            let seed = 0xA11CE5EED &+ UInt64(t) &* 0x9E3779B97F4A7C15 &+ UInt64(n)

            guard let puzzle = PuzzleGenerator.generate(difficulty: size, seed: seed) else {
                Issue.record("generate() returned nil for \(n)×\(n) (seed \(seed))")
                continue
            }

            // (a) Exactly one solution.
            let solutions = QueensSolver.countSolutions(puzzle.grid, puzzle.regions)
            #expect(solutions == 1, "\(n)×\(n) seed \(seed): \(solutions) solutions, expected 1")

            // (b) No guessing required — pure logic places all n flowers.
            let grade = LogicSolver.grade(regions: puzzle.regions, n: n)
            #expect(grade.fullySolved,
                    "\(n)×\(n) seed \(seed) needs a guess: logic placed \(grade.placedByLogic)/\(n)")
        }
    }

}

/// 9×9 bank tests. Serialized because they share the persisted no-repeat cursor
/// (`UserDefaults`) — running them in parallel would interleave cursor draws and make the
/// no-repeat assertion flaky. No other suite touches the 9×9 cursor (the fairness test above
/// excludes `.nine`), so within this suite the cursor is deterministic.
@Suite(.serialized)
struct PuzzleBankTests {

    private static let orderKey = "puzzleBank.order.9"
    private static let posKey   = "puzzleBank.pos.9"

    private func resetCursor() {
        UserDefaults.standard.removeObject(forKey: Self.orderKey)
        UserDefaults.standard.removeObject(forKey: Self.posKey)
    }

    /// The bank is bundled, loads in-app, and serves fully no-guess boards.
    @Test func loadsFromBundledBankAndIsFair() {
        #expect(PuzzleBank.hasBank(for: .nine), "9×9 bank (boards_9x9.json) should be bundled and loaded")
        resetCursor()
        for _ in 0..<8 {
            guard let puzzle = PuzzleGenerator.generate(difficulty: .nine, seed: 0) else {
                Issue.record("bank returned nil"); continue
            }
            #expect(LogicSolver.grade(regions: puzzle.regions, n: 9).fullySolved,
                    "banked 9×9 must be fully no-guess solvable")
        }
    }

    /// The no-repeat cursor serves every board once before any repeat: 200 consecutive draws
    /// must all be distinct (with random `seed % count` selection, the birthday paradox would
    /// make a repeat near-certain by ~40 draws — so this meaningfully proves the cursor).
    @Test func cursorServesDistinctBoardsWithoutRepeats() {
        resetCursor()
        var seen = Set<String>()
        let draws = 200
        for _ in 0..<draws {
            guard let puzzle = PuzzleGenerator.generate(difficulty: .nine, seed: 0) else {
                Issue.record("bank returned nil"); continue
            }
            seen.insert(puzzle.regions.map { $0.map(String.init).joined() }.joined(separator: "|"))
        }
        #expect(seen.count == draws,
                "first \(draws) bank draws should be distinct (no-repeat cursor); got \(seen.count)")
    }
}
