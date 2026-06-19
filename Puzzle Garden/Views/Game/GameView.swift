import SwiftUI

struct GameView: View {
    @State private var game: GameState
    @State private var conflictTrigger = false   // drives shake animation
    @AppStorage("showRules") private var showRules = true

    let isDaily: Bool
    var playerData: PlayerData

    init(puzzle: Puzzle, isDaily: Bool = false, playerData: PlayerData) {
        _game = State(initialValue: GameState(puzzle: puzzle))
        self.isDaily = isDaily
        self.playerData = playerData
    }

    var body: some View {
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

                ZStack(alignment: .topLeading) {
                    grid(cellSize: cellSize)
                        .modifier(ShakeModifier(trigger: conflictTrigger))
                        .gesture(dragGesture(cellSize: cellSize))
                        .overlay(outerBorder)

                    if game.showWin {
                        winOverlay(gridSize: available)
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: game.showWin)
                .frame(width: available, height: available)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
        }
        .background(Color(red: 0.97, green: 0.95, blue: 0.90))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            game.startTimer()
            game.onWin = {
                playerData.recordSolve(
                    difficulty: game.puzzle.difficulty,
                    solveTime: TimeInterval(game.elapsedSeconds),
                    isDaily: isDaily
                )
            }
        }
        .onDisappear { game.stopTimer() }
        .onChange(of: game.wrongPlacement) { _, _ in
            triggerShake()
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
                        .onTapGesture { game.tap(coord) }
                        .onLongPressGesture(minimumDuration: 0.4) { game.longPress(coord) }
                    }
                }
            }
        }
    }

    private var outerBorder: some View {
        Rectangle()
            .strokeBorder(Color(red: 0.40, green: 0.30, blue: 0.20), lineWidth: 2)
    }

    private func winOverlay(gridSize: CGFloat) -> some View {
        ZStack {
            Color(red: 1.0, green: 0.97, blue: 0.80)
                .opacity(0.95)
                .cornerRadius(12)

            VStack(spacing: 14) {
                Text("☀️")
                    .font(.system(size: 64))

                Text("Puzzle Solved!")
                    .font(.system(.title2, design: .rounded).bold())
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
                            .font(.system(size: 28))
                        Text("Plant earned!")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.25, green: 0.50, blue: 0.28).opacity(0.12))
                    )
                }
            }
            .padding(32)
        }
        .frame(width: gridSize, height: gridSize)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.75)),
            removal: .opacity
        ))
    }

    // MARK: - Drag gesture

    private func dragGesture(cellSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let col = Int(value.location.x / cellSize)
                let row = Int(value.location.y / cellSize)
                let n   = game.puzzle.size
                guard row >= 0, row < n, col >= 0, col < n else { return }
                game.dragMark(CellCoord(row: row, col: col))
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
