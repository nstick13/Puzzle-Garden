import SwiftUI

struct OnboardingView: View {
    var onDismiss: () -> Void

    @State private var currentPage = 0

    private let warmGreen = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let terra     = Color(red: 0.769, green: 0.443, blue: 0.294)
    private let bg        = Color(red: 0.961, green: 0.941, blue: 0.910)

    var body: some View {
        ZStack(alignment: .top) {
            bg.ignoresSafeArea()

            TabView(selection: $currentPage) {
                MechanicPage()
                    .tag(0)
                DeductionPage()
                    .tag(1)
                ControlsPage()
                    .tag(2)
                GardenPage()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Skip button
            HStack {
                Spacer()
                Button("Skip") {
                    onDismiss()
                }
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.42, blue: 0.38))
                .padding(.horizontal, 20)
                .padding(.top, 56)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if currentPage == 3 {
                Button(action: onDismiss) {
                    Text("Get started")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(warmGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
}

// MARK: - Page 1: The Mechanic

private struct MechanicPage: View {
    private let warmGreen = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let warmGray  = Color(red: 0.45, green: 0.42, blue: 0.38)

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 72)

                Text("How to grow\nyour garden")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(warmGreen)
                    .multilineTextAlignment(.center)

                MechanicGrid()
                    .padding(.horizontal, 40)

                VStack(alignment: .leading, spacing: 14) {
                    RuleRow(icon: "square.grid.2x2.fill",
                            iconColor: Color(red: 0.420, green: 0.561, blue: 0.278),
                            text: "Each plot belongs to a **region** shown by color")
                    RuleRow(icon: "leaf.fill",
                            iconColor: warmGreen,
                            text: "Plant exactly **one flower** per row, column, and region")
                    RuleRow(icon: "arrow.up.left.and.arrow.down.right",
                            iconColor: Color(red: 0.769, green: 0.443, blue: 0.294),
                            text: "Flowers can't touch — **not even diagonally**")
                }
                .padding(.horizontal, 36)

                Spacer().frame(height: 80)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct RuleRow: View {
    let icon: String
    let iconColor: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(red: 0.30, green: 0.25, blue: 0.20))
        }
    }
}

// MARK: - Page 2: How to think (deduction)

/// Teaches the mental model — elimination, not guessing. A 4×4 board solves itself:
/// place a flower → it rules out its row/column/neighbors → that forces the next, and so on.
/// The cascade is hand-verified: every "only one left" beat is a true naked single.
private struct DeductionPage: View {
    private let warmGreen = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let warmGray  = Color(red: 0.45, green: 0.42, blue: 0.38)

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 72)

            Text("You never\nhave to guess")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(warmGreen)
                .multilineTextAlignment(.center)

            DeductionBoard()
                .padding(.horizontal, 44)

            Spacer()
        }
    }
}

private struct DeductionBoard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Region index per cell. A=0, B=1, C=2, D=3.
    private let regions: [[Int]] = [
        [0, 0, 1, 1],
        [2, 0, 0, 1],
        [2, 2, 3, 1],
        [2, 3, 3, 3],
    ]
    private let regionColors: [Color] = [
        Color(red: 0.353, green: 0.478, blue: 0.235),
        Color(red: 0.769, green: 0.443, blue: 0.294),
        Color(red: 0.545, green: 0.412, blue: 0.259),
        Color(red: 0.420, green: 0.561, blue: 0.278),
    ]
    private let gold = Color(red: 0.85, green: 0.62, blue: 0.18)

    // Verified forced cascade (see header). Eliminations revealed step by step.
    private let f1 = GridIndex(row: 0, col: 1)
    private let f2 = GridIndex(row: 1, col: 3)
    private let f3 = GridIndex(row: 3, col: 2)
    private let f4 = GridIndex(row: 2, col: 0)
    private let e1 = [(0,0),(0,2),(0,3),(1,0),(1,1),(1,2),(2,1),(3,1)].map { GridIndex(row: $0.0, col: $0.1) }
    private let e2 = [(2,3),(3,3),(2,2)].map { GridIndex(row: $0.0, col: $0.1) }
    private let e3 = [GridIndex(row: 3, col: 0)]

    @State private var flowers: Set<GridIndex> = []
    @State private var ruledOut: Set<GridIndex> = []
    @State private var forced: GridIndex?
    @State private var caption = "Every row, column, and plot gets one flower."

    private let warmGray = Color(red: 0.45, green: 0.42, blue: 0.38)

    var body: some View {
        VStack(spacing: 18) {
            grid
            Text(caption)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(warmGray)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)
                .animation(.easeInOut(duration: 0.2), value: caption)
        }
        .task {
            if reduceMotion {
                showSolved()
            } else {
                await play()
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { col in
                        cell(GridIndex(row: row, col: col))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.98, green: 0.96, blue: 0.93))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
    }

    private func cell(_ idx: GridIndex) -> some View {
        let color = regionColors[regions[idx.row][idx.col]]
        let isFlower = flowers.contains(idx)
        let isOut = ruledOut.contains(idx)
        let isForced = forced == idx

        return ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(isOut && !isFlower ? 0.12 : 0.30))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isForced ? gold : color.opacity(isOut ? 0.2 : 0.5),
                                lineWidth: isForced ? 3 : 1.5)
                )

            if isFlower {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            } else if isOut {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(warmGray.opacity(0.45))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(isForced ? 1.06 : 1)
    }

    private func showSolved() {
        flowers = [f1, f2, f3, f4]
        caption = "Every move is forced by logic — no guessing."
    }

    private func play() async {
        while !Task.isCancelled {
            reset()
            await pause(1.1)

            caption = "Plant one flower…"
            bloom(f1)
            await pause(1.0)

            caption = "…it rules out its row, column, and every touching square."
            rule(e1)
            await pause(1.6)

            await force(f2, "Only one open square left in this row.", reveal: e2)
            await force(f3, "Only one left in this plot, too.", reveal: e3)
            await force(f4, "And the last falls into place.", reveal: [])

            caption = "Rule out the impossible. You never have to guess. 🌱"
            await pause(2.6)
        }
    }

    // MARK: - Steps

    private func reset() {
        withAnimation(.easeInOut(duration: 0.3)) {
            flowers = []; ruledOut = []; forced = nil
        }
        caption = "Every row, column, and plot gets one flower."
    }

    private func bloom(_ idx: GridIndex) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            _ = flowers.insert(idx)
        }
    }

    private func rule(_ cells: [GridIndex]) {
        withAnimation(.easeInOut(duration: 0.45)) {
            ruledOut.formUnion(cells)
        }
    }

    /// Highlight a forced cell, then bloom it and reveal the next round of eliminations.
    private func force(_ idx: GridIndex, _ text: String, reveal: [GridIndex]) async {
        caption = text
        withAnimation(.easeInOut(duration: 0.25)) { forced = idx }
        await pause(0.9)
        withAnimation(.easeInOut(duration: 0.2)) { forced = nil }
        bloom(idx)
        if !reveal.isEmpty { rule(reveal) }
        await pause(1.3)
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

// MARK: - Page 3: The Controls

private struct ControlsPage: View {
    private let warmGreen = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let warmGray  = Color(red: 0.45, green: 0.42, blue: 0.38)

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 72)

            Text("Two taps\nto play")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(warmGreen)
                .multilineTextAlignment(.center)

            TapDemoCell()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 14) {
                RuleRow(icon: "hand.point.up.left",
                        iconColor: Color(red: 0.769, green: 0.443, blue: 0.294),
                        text: "**Single tap** to rule a square out — tap again to clear it")
                RuleRow(icon: "hand.tap.fill",
                        iconColor: warmGreen,
                        text: "**Double tap** to plant a flower. Only a quick double tap counts as a guess")
            }
            .padding(.horizontal, 36)

            Spacer()
        }
    }
}

/// A single demo cell that loops: single-tap → ✕, clear, then double-tap → flower.
private struct TapDemoCell: View {
    private enum Symbol { case none, mark, flower }

    @State private var symbol: Symbol = .none
    @State private var caption = "Single tap to rule it out"
    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0

    private let green = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let warmGray = Color(red: 0.45, green: 0.42, blue: 0.38)

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(green.opacity(0.20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(green.opacity(0.45), lineWidth: 2)
                    )

                // Tap ripple.
                Circle()
                    .fill(green.opacity(0.35))
                    .frame(width: 70, height: 70)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)

                switch symbol {
                case .none:
                    EmptyView()
                case .mark:
                    Image(systemName: "xmark")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(warmGray.opacity(0.7))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                case .flower:
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(green)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: 132, height: 132)

            Text(caption)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(warmGray)
                .animation(.easeInOut(duration: 0.2), value: caption)
        }
        .task { await loop() }
    }

    private func ripple() async {
        ringScale = 0.3
        ringOpacity = 0.6
        withAnimation(.easeOut(duration: 0.45)) {
            ringScale = 1.25
            ringOpacity = 0
        }
        try? await Task.sleep(nanoseconds: 220_000_000)
    }

    private func loop() async {
        while !Task.isCancelled {
            // Single tap → rule out.
            caption = "Single tap to rule it out"
            await ripple()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { symbol = .mark }
            try? await Task.sleep(nanoseconds: 1_300_000_000)

            // Single tap again → clear.
            await ripple()
            withAnimation(.easeInOut(duration: 0.25)) { symbol = .none }
            try? await Task.sleep(nanoseconds: 700_000_000)

            // Double tap → plant a flower.
            caption = "Double tap to plant a flower"
            await ripple()
            await ripple()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { symbol = .flower }
            try? await Task.sleep(nanoseconds: 1_700_000_000)

            // Reset for the next loop.
            withAnimation(.easeInOut(duration: 0.3)) { symbol = .none }
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }
}

// 4×4 grid demonstrating the mechanic
private struct MechanicGrid: View {
    // Region color index per cell [row][col]
    private let regions: [[Int]] = [
        [0, 0, 1, 1],
        [0, 2, 2, 1],
        [3, 2, 3, 3],
        [3, 3, 2, 1],
    ]

    // Correct flower placements: (row, col)
    private let flowers: Set<GridIndex> = [
        GridIndex(row: 0, col: 3),
        GridIndex(row: 1, col: 0),
        GridIndex(row: 2, col: 2),
        GridIndex(row: 3, col: 1),
    ]

    // Wrong/invalid cell demonstrating adjacency rule (diagonal to flower at 0,3)
    private let invalidCell = GridIndex(row: 1, col: 2)

    private let regionColors: [Color] = [
        Color(red: 0.353, green: 0.478, blue: 0.235),   // warm green
        Color(red: 0.769, green: 0.443, blue: 0.294),   // terracotta
        Color(red: 0.545, green: 0.412, blue: 0.259),   // earth brown
        Color(red: 0.420, green: 0.561, blue: 0.278),   // sec green
    ]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { col in
                        let idx = GridIndex(row: row, col: col)
                        let isFlower = flowers.contains(idx)
                        let isInvalid = idx == invalidCell
                        let color = regionColors[regions[row][col]]

                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(color.opacity(0.28))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(color.opacity(0.50), lineWidth: 1.5)
                                )

                            if isFlower {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(color)
                            } else if isInvalid {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.red.opacity(0.75))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.98, green: 0.96, blue: 0.93))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
    }
}

private struct GridIndex: Hashable {
    let row: Int
    let col: Int
}

// MARK: - Page 2: The Garden

private struct GardenPage: View {
    private let warmGreen = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let warmGray  = Color(red: 0.45, green: 0.42, blue: 0.38)

    @State private var visibleCount = 0

    // 4×4 garden: true = has plant, false = empty plot
    private let plotsFilled: [Bool] = [
        true, true, false, false,
        true, false, false, false,
        false, false, false, false,
        false, false, false, false,
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 72)

            Text("Every puzzle\nplants something new")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(warmGreen)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            GardenPlotGrid(plotsFilled: plotsFilled, visibleCount: visibleCount)
                .padding(.horizontal, 50)
                .onAppear {
                    animatePlants()
                }

            Text("Solve puzzles. Watch your garden grow.")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(warmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func animatePlants() {
        visibleCount = 0
        let filledIndices = plotsFilled.indices.filter { plotsFilled[$0] }
        for (i, _) in filledIndices.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15 + 0.3) {
                withAnimation(.spring(duration: 0.4)) {
                    visibleCount = i + 1
                }
            }
        }
    }
}

private struct GardenPlotGrid: View {
    let plotsFilled: [Bool]
    let visibleCount: Int

    private let terra    = Color(red: 0.769, green: 0.443, blue: 0.294)
    private let green    = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let secGreen = Color(red: 0.420, green: 0.561, blue: 0.278)
    private let soil     = Color(red: 0.545, green: 0.412, blue: 0.259)

    private let plantEmojis = ["🌸", "🌿", "🌱", "🌻"]
    private var filledIndices: [Int] { plotsFilled.indices.filter { plotsFilled[$0] } }

    var body: some View {
        let cols = 4
        VStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<cols, id: \.self) { col in
                        let idx = row * cols + col
                        let isFilled = plotsFilled[idx]
                        let filledRank = filledIndices.firstIndex(of: idx) ?? -1
                        let isVisible = isFilled && filledRank < visibleCount

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(soil.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(soil.opacity(0.30), lineWidth: 1.5)
                                )

                            if isVisible {
                                Text(plantEmojis[filledRank % plantEmojis.count])
                                    .font(.system(size: 26))
                                    .transition(.scale(scale: 0.1).combined(with: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.98, green: 0.965, blue: 0.945))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
    }
}

#Preview {
    OnboardingView(onDismiss: {})
}
