import SwiftUI

struct GameView: View {
    @State private var game: GameState
    @State private var conflictTrigger = false   // drives shake animation
    @State private var shareImage: UIImage?
    @State private var isLoadingNext = false      // generating the next Free Play puzzle
    @AppStorage("showRules") private var showRules = true

    @Environment(\.dismiss) private var dismiss

    let isDaily: Bool
    var playerData: PlayerData

    init(puzzle: Puzzle, isDaily: Bool = false, playerData: PlayerData) {
        _game = State(initialValue: GameState(puzzle: puzzle))
        self.isDaily = isDaily
        self.playerData = playerData
    }

    var body: some View {
        // Top-level ZStack so game.showWin is read at body scope — not inside
        // GeometryReader, whose content closure may be re-invoked outside the
        // Observation tracking context, causing the win overlay to silently skip.
        ZStack {
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                if showRules {
                    rulesBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                Spacer(minLength: 0)

                GeometryReader { geo in
                    let available = min(geo.size.width, geo.size.height)
                    let cellSize  = available / CGFloat(game.puzzle.size)

                    grid(cellSize: cellSize)
                        .modifier(ShakeModifier(trigger: conflictTrigger))
                        .gesture(dragGesture(cellSize: cellSize))
                        .frame(width: available, height: available)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .background(Color(red: 0.97, green: 0.95, blue: 0.90))

            // Win overlay is outside GeometryReader so game.showWin is observed
            // at body scope. This guarantees the view re-renders on win.
            if game.showWin {
                winOverlay
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: game.showWin)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            wireWin(game)
            game.startTimer()
        }
        .onDisappear { game.stopTimer() }
        .task(id: game.showWin) {
            guard game.showWin else { return }
            shareImage = ShareCardView(puzzle: game.puzzle, elapsedSeconds: game.elapsedSeconds).rendered()
        }
        .onChange(of: game.wrongPlacement) { _, _ in
            triggerShake()
        }
        .onChange(of: game.correctPlacement) { _, newValue in
            if newValue != nil {
                SoundManager.shared.playFlowerPlaced()
                HapticsManager.shared.hapticFlowerPlaced()
            }
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        HStack {
            Text(game.puzzle.difficulty.label)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showRules.toggle() }
            } label: {
                Image(systemName: showRules ? "eye.fill" : "eye.slash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
            }

            Label(timeString, systemImage: "clock")
                .font(.system(.subheadline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
        }
    }

    private var rulesBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ruleChip("1 per row", icon: "arrow.left.and.right")
                ruleChip("1 per column", icon: "arrow.up.and.down")
                ruleChip("1 per color", icon: "square.grid.2x2.fill")
            }
            HStack {
                ruleChip("Plants can't touch — not even diagonally", icon: "hand.raised.fill")
            }
        }
    }

    private func ruleChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, design: .rounded))
        }
        .foregroundStyle(Color(red: 0.40, green: 0.30, blue: 0.20))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.92, green: 0.88, blue: 0.82))
        )
    }

    private func grid(cellSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<game.puzzle.size, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<game.puzzle.size, id: \.self) { col in
                        let coord = CellCoord(row: row, col: col)
                        let isFlower = game.cellStates[row][col] == .flower
                        CellView(
                            state:      game.cellStates[row][col],
                            regionID:   game.puzzle.regions[row][col],
                            isConflict: game.conflicts.contains(coord),
                            isCorrect:  isFlower ? game.puzzle.solution[row][col] == 1 : nil,
                            size:       cellSize,
                            popAnimation: game.correctPlacement == coord
                        )
                        // Double tap = guess (plant a flower). Single tap = rule the
                        // square out. The count:2 gesture is declared first so SwiftUI
                        // waits out the double-tap window before firing a single tap —
                        // two slow taps stay two single taps, never a guess.
                        .onTapGesture(count: 2) { game.guess(coord) }
                        .onTapGesture(count: 1) {
                            let wasEmpty = game.cellStates[row][col] == .empty
                            game.toggleMark(coord)
                            if wasEmpty {
                                SoundManager.shared.playDigMark()
                                HapticsManager.shared.hapticDigMark()
                            }
                        }
                    }
                }
            }
        }
    }

    private var winOverlay: some View {
        ZStack {
            Color(red: 0.97, green: 0.95, blue: 0.90)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("☀️")
                    .font(.system(size: 72))

                Text("Puzzle Solved!")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(Color(red: 0.20, green: 0.38, blue: 0.22))

                Text(timeString)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                    .monospacedDigit()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.72, green: 0.55, blue: 0.35).opacity(0.15))
                    )

                if let plant = playerData.lastAwardedPlant {
                    HStack(spacing: 8) {
                        Text(plant.emoji)
                            .font(.system(size: 32))
                        Text("Plant earned!")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 0.25, green: 0.50, blue: 0.28).opacity(0.12))
                    )
                }

                VStack(spacing: 10) {
                    if isDaily {
                        // Daily is one-per-day — just return to the garden/home.
                        Button { dismiss() } label: {
                            primaryButtonLabel(Text("Continue"))
                        }
                    } else {
                        // Free Play is unlimited — keep the player going without a trip home.
                        Button { loadNextPuzzle() } label: {
                            primaryButtonLabel(
                                Group {
                                    if isLoadingNext {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Next Puzzle")
                                    }
                                }
                            )
                        }
                        .disabled(isLoadingNext)

                        Button { dismiss() } label: {
                            secondaryButtonLabel(Text("Back to Home"))
                        }
                    }

                    ShareLink(item: shareText) {
                        secondaryButtonLabel(Label("Share Result", systemImage: "square.and.arrow.up"))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            .padding(32)
        }
    }

    // MARK: - Share text

    private var shareText: String {
        let n = game.puzzle.size
        var rows: [String] = []
        for r in 0..<n {
            var line = ""
            for c in 0..<n {
                line += game.puzzle.solution[r][c] == 1 ? "🌸" : "⬜"
            }
            rows.append(line)
        }
        let grid = rows.joined(separator: "\n")
        let label = isDaily
            ? "Puzzle Garden — Daily \(PlayerData.todayString())"
            : "Puzzle Garden — \(game.puzzle.difficulty.label)"
        return "\(grid)\n\(label)"
    }

    // MARK: - Drag gesture

    private func dragGesture(cellSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let col = Int(value.location.x / cellSize)
                let row = Int(value.location.y / cellSize)
                let n   = game.puzzle.size
                guard row >= 0, row < n, col >= 0, col < n else { return }
                let coord = CellCoord(row: row, col: col)
                let willMark = !game.isSolved && game.cellStates[row][col] == .empty
                game.dragMark(coord)
                if willMark {
                    SoundManager.shared.playDigMark()
                    HapticsManager.shared.hapticDigMark()
                }
            }
    }

    // MARK: - Helpers

    private var timeString: String {
        let m = game.elapsedSeconds / 60
        let s = game.elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func triggerShake() {
        withAnimation { conflictTrigger.toggle() }
    }

    // MARK: - Win wiring & "next puzzle"

    /// Wires a game's fire-once win callback. Captures the specific instance (not the `@State`)
    /// so it stays correct after `startGame` swaps in a new game. See gotcha #2 in HANDOFF.
    private func wireWin(_ g: GameState) {
        g.onWin = { [weak g, isDaily, playerData] in
            guard let g else { return }
            playerData.recordSolve(
                difficulty: g.puzzle.difficulty,
                solveTime: TimeInterval(g.elapsedSeconds),
                isDaily: isDaily
            )
            SoundManager.shared.playSolve()
            HapticsManager.shared.hapticSolve()
        }
    }

    /// Swaps in a fresh puzzle in place — dismisses the win overlay (new game starts unsolved)
    /// and starts a new timer, no trip back to Home.
    private func startGame(with puzzle: Puzzle) {
        let next = GameState(puzzle: puzzle)
        wireWin(next)
        shareImage = nil
        game = next
        game.startTimer()
    }

    /// Generates the next Free Play puzzle at the same size (off the main thread — banked 9×9 is
    /// instant, smaller sizes generate live) and swaps it in.
    private func loadNextPuzzle() {
        let difficulty = game.puzzle.difficulty
        isLoadingNext = true
        Task.detached(priority: .userInitiated) {
            let seed = UInt64(Date().timeIntervalSince1970 * 1000)
            let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed)
            await MainActor.run {
                isLoadingNext = false
                if let puzzle { startGame(with: puzzle) }
            }
        }
    }

    // MARK: - Win-overlay button styles

    private func primaryButtonLabel(_ content: some View) -> some View {
        content
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.25, green: 0.50, blue: 0.28))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func secondaryButtonLabel(_ content: some View) -> some View {
        content
            .font(.system(.subheadline, design: .rounded).bold())
            .foregroundStyle(Color(red: 0.25, green: 0.50, blue: 0.28))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.25, green: 0.50, blue: 0.28).opacity(0.12))
            )
    }
}

// MARK: - Shake modifier

private struct ShakeModifier: ViewModifier, Animatable {
    var trigger: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, _ in
                Task {
                    for delta: CGFloat in [8, -8, 6, -6, 4, -4, 0] {
                        try? await Task.sleep(nanoseconds: 40_000_000)
                        withAnimation(.easeInOut(duration: 0.04)) { offset = delta }
                    }
                }
            }
    }
}

#Preview {
    let regions: [[Int]] = [
        [0, 0, 1, 1, 1],
        [0, 0, 1, 2, 2],
        [0, 3, 3, 2, 2],
        [4, 3, 3, 3, 2],
        [4, 4, 4, 4, 4],
    ]
    let empty    = Array(repeating: Array(repeating: 0, count: 5), count: 5)
    var solution = empty
    _ = QueensSolver.solve(&solution, regions)
    let puzzle   = Puzzle(grid: empty, regions: regions, solution: solution, difficulty: .five)
    return NavigationStack { GameView(puzzle: puzzle, playerData: PlayerData.shared) }
}
