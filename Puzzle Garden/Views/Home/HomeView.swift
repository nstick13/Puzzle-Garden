import SwiftUI

struct HomeView: View {
    var playerData: PlayerData

    @State private var selectedDifficulty: GridSize = .five
    @State private var activePuzzle: Puzzle?
    @State private var isGenerating = false
    @State private var activeIsDaily = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.95, blue: 0.90)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Logo / title
                    VStack(spacing: 6) {
                        Text("🌿")
                            .font(.system(size: 64))
                        Text("Puzzle Garden")
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(Color(red: 0.20, green: 0.38, blue: 0.22))
                        Text("Plant your logic")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))

                        if playerData.stats.currentStreak > 0 {
                            Text("\(playerData.stats.currentStreak)-day streak")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.35))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.72, green: 0.55, blue: 0.35).opacity(0.15))
                                )
                        }
                    }

                    // Daily puzzle button
                    Button(action: generateDaily) {
                        HStack {
                            Label("Today's Puzzle", systemImage: "sun.max.fill")
                                .font(.system(.headline, design: .rounded))
                            if playerData.isDailySolved() {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(.headline))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            playerData.isDailySolved()
                                ? Color(red: 0.45, green: 0.65, blue: 0.48)
                                : Color(red: 0.25, green: 0.50, blue: 0.28)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 32)

                    // Free play section
                    VStack(spacing: 12) {
                        Text("Free Play")
                            .font(.system(.footnote, design: .rounded).uppercaseSmallCaps())
                            .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))

                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(GridSize.allCases, id: \.self) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 32)

                        Button(action: generateFreePlay) {
                            Group {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("New Puzzle", systemImage: "leaf.fill")
                                        .font(.system(.headline, design: .rounded))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.72, green: 0.55, blue: 0.35))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isGenerating)
                        .padding(.horizontal, 32)
                    }

                    Spacer()
                }
            }
            .navigationDestination(item: $activePuzzle) { puzzle in
                GameView(puzzle: puzzle, isDaily: activeIsDaily, playerData: playerData)
            }
        }
    }

    // MARK: - Actions

    private func generateDaily() {
        activeIsDaily = true
        generate(seed: DailyPuzzleManager.todaySeed(), difficulty: .five)
    }

    private func generateFreePlay() {
        activeIsDaily = false
        let seed = UInt64(Date().timeIntervalSince1970 * 1000)
        generate(seed: seed, difficulty: selectedDifficulty)
    }

    private func generate(seed: UInt64, difficulty: GridSize) {
        isGenerating = true
        Task.detached(priority: .userInitiated) {
            let puzzle = PuzzleGenerator.generate(difficulty: difficulty, seed: seed)
            await MainActor.run {
                isGenerating = false
                activePuzzle = puzzle
            }
        }
    }
}

#Preview {
    HomeView(playerData: PlayerData.shared)
}
