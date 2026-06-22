import Foundation
import Observation
import SwiftUI

enum CellState: Equatable {
    case empty
    case marked   // trowel / dig mark
    case flower   // placed queen
}

struct CellCoord: Hashable {
    let row: Int
    let col: Int
}

@Observable
final class GameState {
    let puzzle: Puzzle
    var cellStates: [[CellState]]
    var conflicts: Set<CellCoord> = []
    var isSolved = false
    var showWin = false
    var elapsedSeconds = 0
    var wrongPlacement = false
    var correctPlacement: CellCoord?
    var onWin: (() -> Void)?

    private var timer: Timer?

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        cellStates = Array(
            repeating: Array(repeating: .empty, count: puzzle.size),
            count: puzzle.size
        )
    }

    // MARK: - Timer

    func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Interactions

    /// Single tap — rule a square *out*. Toggles the dig mark on/off, and also
    /// clears a flower back to empty. Never plants a flower: only a true double
    /// tap (`guess`) does that, so a slow second tap can't be mistaken for a guess.
    func toggleMark(_ coord: CellCoord) {
        guard !isSolved else { return }
        switch cellStates[coord.row][coord.col] {
        case .empty:  cellStates[coord.row][coord.col] = .marked
        case .marked: cellStates[coord.row][coord.col] = .empty
        case .flower: cellStates[coord.row][coord.col] = .empty
        }
        refreshState()
    }

    /// Double tap — the only "guess". Plants a flower, or lifts one already there.
    func guess(_ coord: CellCoord) {
        guard !isSolved else { return }
        if cellStates[coord.row][coord.col] == .flower {
            cellStates[coord.row][coord.col] = .empty
        } else {
            cellStates[coord.row][coord.col] = .flower
            checkWrongPlacement(coord)
        }
        refreshState()
    }

    /// Paints a dig mark while dragging — skips cells that already have flowers.
    func dragMark(_ coord: CellCoord) {
        guard !isSolved, cellStates[coord.row][coord.col] == .empty else { return }
        cellStates[coord.row][coord.col] = .marked
    }

    // MARK: - Internal

    private func checkWrongPlacement(_ coord: CellCoord) {
        if puzzle.solution[coord.row][coord.col] != 1 {
            wrongPlacement.toggle()
            correctPlacement = nil
        } else {
            correctPlacement = coord
        }
    }

    private func refreshState() {
        updateConflicts()
        checkWin()
    }

    private func updateConflicts() {
        let n = puzzle.size
        var flowers: [CellCoord] = []
        for r in 0..<n {
            for c in 0..<n where cellStates[r][c] == .flower {
                flowers.append(CellCoord(row: r, col: c))
            }
        }

        var bad = Set<CellCoord>()
        for i in 0..<flowers.count {
            for j in (i + 1)..<flowers.count {
                let a = flowers[i], b = flowers[j]
                let violates =
                    a.row == b.row ||
                    a.col == b.col ||
                    puzzle.regions[a.row][a.col] == puzzle.regions[b.row][b.col] ||
                    (abs(a.row - b.row) == 1 && abs(a.col - b.col) == 1)
                if violates { bad.insert(a); bad.insert(b) }
            }
        }
        conflicts = bad
    }

    private func checkWin() {
        let n = puzzle.size
        // Easy mode: the puzzle is solved once every correct cell (the unique solution)
        // holds a flower. Incorrect guesses render as a red ✗ and never block the win —
        // the player is not required to clear them first.
        for r in 0..<n {
            for c in 0..<n where puzzle.solution[r][c] == 1 {
                if cellStates[r][c] != .flower { return }
            }
        }
        stopTimer()
        isSolved = true
        showWin = true
        onWin?()
    }
}
