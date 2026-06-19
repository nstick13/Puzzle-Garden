import SwiftUI

struct DailyCalendarView: View {
    let dailyHistory: [String: DailyResult]

    @State private var displayedMonth = Date()
    @State private var selectedDay: DailyResult?

    private let calendar = Calendar(identifier: .gregorian)
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = Calendar(identifier: .gregorian).veryShortWeekdaySymbols

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            daysGrid

            if let selected = selectedDay {
                solveDetail(selected)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.94, green: 0.91, blue: 0.86))
        )
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.body, weight: .semibold))
            }

            Spacer()

            Text(monthYearString)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))

            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(.body, weight: .semibold))
            }
        }
        .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: dayColumns, spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 11, design: .rounded).bold())
                    .foregroundStyle(Color(red: 0.55, green: 0.50, blue: 0.42))
                    .frame(height: 24)
            }
        }
    }

    private var daysGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: dayColumns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                if day == 0 {
                    Color.clear.frame(height: 36)
                } else {
                    dayCell(day)
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let dateStr = dateString(for: day)
        let result = dailyHistory[dateStr]
        let isToday = dateStr == PlayerData.todayString()

        return Button {
            if let r = result { selectedDay = r }
        } label: {
            ZStack {
                if isToday {
                    Circle()
                        .strokeBorder(Color(red: 0.25, green: 0.50, blue: 0.28), lineWidth: 2)
                }

                if result != nil {
                    Text("🌿")
                        .font(.system(size: 16))
                } else {
                    Text("\(day)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(
                            isToday
                                ? Color(red: 0.25, green: 0.50, blue: 0.28)
                                : Color(red: 0.45, green: 0.35, blue: 0.25)
                        )
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
    }

    private func solveDetail(_ result: DailyResult) -> some View {
        HStack(spacing: 12) {
            Text("🌿")
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.date)
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
                Text("\(result.gridSize.label) solved in \(formatTime(result.solveTime))")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.76, green: 0.88, blue: 0.72).opacity(0.3))
        )
    }

    // MARK: - Helpers

    private func shiftMonth(_ delta: Int) {
        if let newDate = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newDate
            selectedDay = nil
        }
    }

    private var monthYearString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: displayedMonth)
    }

    private func daysInMonth() -> [Int] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let blanks = weekday - calendar.firstWeekday
        let leading = (blanks + 7) % 7

        var days = Array(repeating: 0, count: leading)
        days += Array(range)
        return days
    }

    private func dateString(for day: Int) -> String {
        let comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        let fmt = PlayerData.dateFormatter()
        var dc = comps
        dc.day = day
        guard let date = calendar.date(from: dc) else { return "" }
        return fmt.string(from: date)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    DailyCalendarView(dailyHistory: [
        "2026-06-10": DailyResult(date: "2026-06-10", gridSize: .five, solveTime: 95, completed: true),
        "2026-06-11": DailyResult(date: "2026-06-11", gridSize: .five, solveTime: 142, completed: true),
    ])
    .padding()
}
