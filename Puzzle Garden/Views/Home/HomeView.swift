import SwiftUI

struct HomeView: View {
    var playerData: PlayerData
    var storeManager: StoreManager

    @State private var selectedDifficulty: GridSize = .five
    @State private var activePuzzle: Puzzle?
    @State private var isGenerating = false
    @State private var activeIsDaily = false
    @State private var showPaywall = false

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

                    // Daily puzzle button (always free)
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

                    // Free play section (gated behind purchase)
                    VStack(spacing: 12) {
                        HStack {
                            Text("Free Play")
                                .font(.system(.footnote, design: .rounded).uppercaseSmallCaps())
                                .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                            if !storeManager.hasFullAccess {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(red: 0.72, green: 0.55, blue: 0.35))
                            }
                        }

                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(GridSize.allCases, id: \.self) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 32)
                        .opacity(storeManager.hasFullAccess ? 1 : 0.5)

                        Button(action: handleFreePlayTap) {
                            Group {
                                if isGenerating {
                                    ProgressView()
                                        .tint(.white)
                                } else if storeManager.hasFullAccess {
                                    Label("New Puzzle", systemImage: "leaf.fill")
                                        .font(.system(.headline, design: .rounded))
                                } else {
                                    Label("Unlock Free Play", systemImage: "lock.open.fill")
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
                        .sheet(isPresented: $showPaywall) { PaywallView() }
                    }

                    Spacer()
                }
            }
            .navigationDestination(item: $activePuzzle) { puzzle in
                GameView(puzzle: puzzle, isDaily: activeIsDaily, playerData: playerData)
            }
            .sheet(isPresented: $showPaywall) {
                StoreView(storeManager: storeManager) { showPaywall = false }
            }
        }
    }

    // MARK: - Actions

    private func generateDaily() {
        activeIsDaily = true
        generate(seed: DailyPuzzleManager.todaySeed(), difficulty: .five)
    }

    private func handleFreePlayTap() {
        guard storeManager.hasFullAccess else {
            showPaywall = true
            return
        }
        generateFreePlay()
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
    HomeView(playerData: PlayerData.shared, storeManager: StoreManager.shared)
}
