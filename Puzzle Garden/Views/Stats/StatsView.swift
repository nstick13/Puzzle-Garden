import SwiftUI

struct StatsView: View {
    var playerData: PlayerData

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.95, blue: 0.90)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        streakCards
                        totalCard
                        bestTimesCard
                        DailyCalendarView(dailyHistory: playerData.dailyHistory)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var streakCards: some View {
        HStack(spacing: 12) {
            statCard(
                title: "Current Streak",
                value: "\(playerData.stats.currentStreak)",
                icon: "flame.fill",
                color: Color(red: 0.90, green: 0.55, blue: 0.25)
            )
            statCard(
                title: "Longest Streak",
                value: "\(playerData.stats.longestStreak)",
                icon: "trophy.fill",
                color: Color(red: 0.72, green: 0.55, blue: 0.35)
            )
        }
    }

    private var totalCard: some View {
        statCard(
            title: "Total Solved",
            value: "\(playerData.stats.totalSolved)",
            icon: "leaf.fill",
            color: Color(red: 0.25, green: 0.50, blue: 0.28)
        )
    }

    private var bestTimesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Best Times", systemImage: "clock.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))

            ForEach(GridSize.allCases, id: \.self) { size in
                HStack {
                    Text(size.label)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
                    Spacer()
                    if let best = playerData.stats.bestTimes[size] {
                        Text(formatTime(best))
                            .font(.system(.body, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                    } else {
                        Text("--:--")
                            .font(.system(.body, design: .rounded).monospacedDigit())
                            .foregroundStyle(Color(red: 0.70, green: 0.65, blue: 0.58))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.94, green: 0.91, blue: 0.86))
        )
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.20, green: 0.15, blue: 0.10))
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.94, green: 0.91, blue: 0.86))
        )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    StatsView(playerData: PlayerData.shared)
}
