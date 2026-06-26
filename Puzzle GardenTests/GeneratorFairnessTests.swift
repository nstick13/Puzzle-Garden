import Testing
import Foundation
@testable import Puzzle_Garden

/// Guards the core promise: every generated puzzle must be solvable by pure logic with NO
/// guessing. Regression net for the generator's "only ship `LogicSolver.fullySolved` boards"
/// gate — a guess-requiring puzzle must never ship again.
struct GeneratorFairnessTests {

    /// For each grid size, generate many puzzles and assert each one is produced,
    /// uniquely solvable, and fully solvable by the no-guess `LogicSolver`.
    @Test(arguments: GridSize.allCases)
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
