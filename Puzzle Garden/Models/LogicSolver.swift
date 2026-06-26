import Foundation

/// A *no-guess* logical solver used to grade how fair a puzzle is.
///
/// It only ever makes deductions a human would make without guessing or looking
/// ahead for contradictions:
///   • **Naked single** — a row, column, or plot with one square left → plant it.
///   • **Line → plot** — a row/column whose open squares are all one plot reserves
///     that plot to the line; clear that plot's squares elsewhere. *(The "column 0
///     is entirely yellow" opening.)*
///   • **Plot → line** — a plot whose open squares all sit in one row/column
///     reserves that line; clear other plots' squares on it.
///   • **Plot subset lock** — K plots whose open squares occupy exactly K columns (or
///     rows) reserve those columns; clear other plots there. *(The "two plots lock
///     two columns" deduction.)*
///   • **Line subset lock** *(dual of the above)* — K rows (or columns) whose open
///     squares occupy exactly K plots reserve those plots to those lines; clear those
///     plots' squares on every other line.
///
/// Both subset locks run for any K up to n−1 (not just K=2,3), so deeper deductions
/// that larger boards rely on are still found without guessing.
///
/// The point: if this solver can't even place the **first flower**, the puzzle
/// requires a leap of faith — reject it. `grade` reports how far pure logic gets.
enum LogicSolver {

    struct Grade {
        let placedByLogic: Int   // flowers forced without guessing
        let total: Int           // n — a full solve places this many

        /// At least one flower falls out of pure logic (a fair opening exists).
        var firstFlowerForced: Bool { placedByLogic >= 1 }
        /// The whole puzzle unravels with no guessing.
        var fullySolved: Bool { placedByLogic == total }
        /// Share of the board logic can place before stalling.
        var coverage: Double { total == 0 ? 0 : Double(placedByLogic) / Double(total) }
    }

    /// Runs the no-guess solver against a region map and reports how far it gets.
    static func grade(regions: [[Int]], n: Int) -> Grade {
        // `cand[r][c]` — could this square still hold a flower?
        var cand = Array(repeating: Array(repeating: true, count: n), count: n)
        var rowDone    = Array(repeating: false, count: n)
        var colDone    = Array(repeating: false, count: n)
        var regionDone = Array(repeating: false, count: n)   // region ids are 0..<n
        var placed = 0

        // Cells grouped by region, for quick scans.
        var regionCells = Array(repeating: [(Int, Int)](), count: n)
        for i in 0..<n {
            for j in 0..<n { regionCells[regions[i][j]].append((i, j)) }
        }

        func place(_ r: Int, _ c: Int) {
            placed += 1
            let g = regions[r][c]
            rowDone[r] = true; colDone[c] = true; regionDone[g] = true
            // One per row / column.
            for k in 0..<n { cand[r][k] = false; cand[k][c] = false }
            // One per plot.
            for (i, j) in regionCells[g] { cand[i][j] = false }
            // No diagonal touching (orthogonal is already covered by row/column).
            for dr in -1...1 {
                for dc in -1...1 where !(dr == 0 && dc == 0) {
                    let nr = r + dr, nc = c + dc
                    if nr >= 0, nr < n, nc >= 0, nc < n { cand[nr][nc] = false }
                }
            }
        }

        // Plot subset lock: K plots confined to K lines reserve those lines.
        func applySubsets(byColumn: Bool) -> Bool {
            // For each active plot, which lines (columns or rows) do its open squares touch?
            var active: [Int] = []
            var lines: [Int: Set<Int>] = [:]
            for g in 0..<n where !regionDone[g] {
                let ls = Set(regionCells[g]
                    .filter { cand[$0.0][$0.1] }
                    .map { byColumn ? $0.1 : $0.0 })
                if !ls.isEmpty { active.append(g); lines[g] = ls }
            }
            guard active.count >= 3 else { return false }   // need K + at least one outsider

            for k in 2...min(active.count - 1, n - 1) {
                var hit = false
                combinations(active, choose: k) { combo in
                    var union = Set<Int>()
                    for g in combo { union.formUnion(lines[g]!) }
                    guard union.count == k else { return }
                    // Those lines belong to `combo`; clear every other plot's squares there.
                    let comboSet = Set(combo)
                    for i in 0..<n {
                        for j in 0..<n where cand[i][j] {
                            let line = byColumn ? j : i
                            if union.contains(line), !comboSet.contains(regions[i][j]) {
                                cand[i][j] = false; hit = true
                            }
                        }
                    }
                }
                if hit { return true }
            }
            return false
        }

        // Line subset lock (dual): K lines whose open squares occupy exactly K plots reserve
        // those plots to those lines — each of the K plots must place its flower on one of the
        // K lines, so clear those plots' squares on every other line.
        func applyLineSubsets(byColumn: Bool) -> Bool {
            // For each active line (column or row), which plots do its open squares touch?
            var active: [Int] = []
            var plots: [Int: Set<Int>] = [:]
            for line in 0..<n where !(byColumn ? colDone[line] : rowDone[line]) {
                var regs = Set<Int>()
                for k in 0..<n {
                    let (i, j) = byColumn ? (k, line) : (line, k)
                    if cand[i][j] { regs.insert(regions[i][j]) }
                }
                if !regs.isEmpty { active.append(line); plots[line] = regs }
            }
            guard active.count >= 3 else { return false }

            for k in 2...min(active.count - 1, n - 1) {
                var hit = false
                combinations(active, choose: k) { combo in
                    var union = Set<Int>()
                    for line in combo { union.formUnion(plots[line]!) }
                    guard union.count == k else { return }
                    // Those K plots belong to these K lines; clear their squares on other lines.
                    let comboSet = Set(combo)
                    for i in 0..<n {
                        for j in 0..<n where cand[i][j] {
                            let line = byColumn ? j : i
                            if union.contains(regions[i][j]), !comboSet.contains(line) {
                                cand[i][j] = false; hit = true
                            }
                        }
                    }
                }
                if hit { return true }
            }
            return false
        }

        var changed = true
        while changed {
            changed = false

            // Technique 1 — naked singles.
            for r in 0..<n where !rowDone[r] {
                let cs = (0..<n).filter { cand[r][$0] }
                if cs.count == 1 { place(r, cs[0]); changed = true }
            }
            if changed { continue }
            for c in 0..<n where !colDone[c] {
                let rs = (0..<n).filter { cand[$0][c] }
                if rs.count == 1 { place(rs[0], c); changed = true }
            }
            if changed { continue }
            for g in 0..<n where !regionDone[g] {
                let cells = regionCells[g].filter { cand[$0.0][$0.1] }
                if cells.count == 1 { place(cells[0].0, cells[0].1); changed = true }
            }
            if changed { continue }

            // Technique 2 — line → plot.
            for r in 0..<n where !rowDone[r] {
                let regs = Set((0..<n).filter { cand[r][$0] }.map { regions[r][$0] })
                if regs.count == 1, let g = regs.first {
                    for (i, j) in regionCells[g] where i != r && cand[i][j] { cand[i][j] = false; changed = true }
                }
            }
            for c in 0..<n where !colDone[c] {
                let regs = Set((0..<n).filter { cand[$0][c] }.map { regions[$0][c] })
                if regs.count == 1, let g = regs.first {
                    for (i, j) in regionCells[g] where j != c && cand[i][j] { cand[i][j] = false; changed = true }
                }
            }
            if changed { continue }

            // Technique 3 — plot → line.
            for g in 0..<n where !regionDone[g] {
                let cells = regionCells[g].filter { cand[$0.0][$0.1] }
                let rows = Set(cells.map { $0.0 })
                if rows.count == 1, let r = rows.first {
                    for j in 0..<n where regions[r][j] != g && cand[r][j] { cand[r][j] = false; changed = true }
                }
                let cols = Set(cells.map { $0.1 })
                if cols.count == 1, let c = cols.first {
                    for i in 0..<n where regions[i][c] != g && cand[i][c] { cand[i][c] = false; changed = true }
                }
            }
            if changed { continue }

            // Technique 4 — plot subset locks.
            if applySubsets(byColumn: true)  { changed = true; continue }
            if applySubsets(byColumn: false) { changed = true; continue }

            // Technique 5 — line subset locks (the dual).
            if applyLineSubsets(byColumn: true)  { changed = true; continue }
            if applyLineSubsets(byColumn: false) { changed = true; continue }
        }

        return Grade(placedByLogic: placed, total: n)
    }

    /// Calls `body` with each K-sized combination of `items`.
    private static func combinations(_ items: [Int], choose k: Int, _ body: ([Int]) -> Void) {
        var combo: [Int] = []
        func recurse(_ start: Int) {
            if combo.count == k { body(combo); return }
            guard start < items.count else { return }
            for i in start..<items.count {
                combo.append(items[i])
                recurse(i + 1)
                combo.removeLast()
            }
        }
        recurse(0)
    }
}
