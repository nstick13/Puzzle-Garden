import Foundation

/// Serves large puzzles from a pre-generated, bundled set instead of generating them live.
///
/// Live generation is guaranteed no-guess (see `PuzzleGenerator`/`LogicSolver`), but at 9×9 the
/// time has a slow tail (occasionally several seconds on older devices). Every board in the bank
/// was generated offline and already passed the no-guess gate, so it loads instantly with zero
/// tail and zero failure risk. Build the bundled JSON with `tools/build_bank.sh`.
///
/// Currently 9×9 only; add a size by generating `boards_NxN.json` and listing N in `bankedSizes`.
enum PuzzleBank {

    /// Sizes served from a bundled bank rather than live generation.
    static let bankedSizes: Set<Int> = [9]

    private struct BankBoard: Decodable {
        let regions: [[Int]]
        let solution: [[Int]]
    }
    private struct BankFile: Decodable {
        let size: Int
        let boards: [BankBoard]
    }

    /// Lazily loaded once. Missing/corrupt files simply yield no bank for that size (caller then
    /// falls back to live generation), so a bad bundle degrades gracefully rather than crashing.
    private static let banks: [Int: BankFile] = loadAll()

    private static func loadAll() -> [Int: BankFile] {
        var result: [Int: BankFile] = [:]
        for n in bankedSizes {
            guard let url = Bundle.main.url(forResource: "boards_\(n)x\(n)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder().decode(BankFile.self, from: data),
                  !file.boards.isEmpty
            else { continue }
            result[n] = file
        }
        return result
    }

    /// True if `difficulty` is served from a bank.
    static func hasBank(for difficulty: GridSize) -> Bool {
        banks[difficulty.rawValue] != nil
    }

    /// A puzzle for `difficulty`, picked deterministically by `seed` — so the daily stays stable
    /// across devices and Free Play's time-based seed gives an effectively random board. Returns
    /// nil when no bank exists for the size (caller should generate live).
    static func puzzle(for difficulty: GridSize, seed: UInt64) -> Puzzle? {
        guard let file = banks[difficulty.rawValue], !file.boards.isEmpty else { return nil }
        let board = file.boards[Int(seed % UInt64(file.boards.count))]
        let n = difficulty.rawValue
        let empty = Array(repeating: Array(repeating: 0, count: n), count: n)
        return Puzzle(grid: empty, regions: board.regions, solution: board.solution, difficulty: difficulty)
    }
}
