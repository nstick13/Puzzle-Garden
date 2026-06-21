import SwiftUI

struct GardenView: View {
    var playerData: PlayerData

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let minSlots = 24

    @State private var gardenImage: UIImage?
    @State private var showShareSheet = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.95, blue: 0.90)
                    .ignoresSafeArea()

                if playerData.garden.isEmpty {
                    emptyState
                } else {
                    gardenGrid
                }
            }
            .navigationTitle("My Garden")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !playerData.garden.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            renderAndShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = gardenImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🌱")
                .font(.system(size: 64))
            Text("Your garden is empty")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
            Text("Solve a puzzle to plant your first flower")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
        }
    }

    private var gardenGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                let totalSlots = max(minSlots, playerData.garden.count + 6)
                ForEach(0..<totalSlots, id: \.self) { index in
                    if index < playerData.garden.count {
                        plantSlot(playerData.garden[index])
                    } else {
                        emptySlot
                    }
                }
            }
            .padding(16)
        }
    }

    private func plantSlot(_ plant: Plant) -> some View {
        VStack(spacing: 2) {
            plantImage(plant)
                .frame(width: 56, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(slotColor(for: plant.difficulty).opacity(0.3))
                )

            if plant.fromDaily {
                Text(shortDate(plant.earnedDate))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
            } else {
                Text(difficultyLabel(plant.difficulty))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.50, blue: 0.42))
            }
        }
    }

    @ViewBuilder
    private func plantImage(_ plant: Plant) -> some View {
        if let assetName = plant.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Text(plant.emoji)
                .font(.system(size: 36))
        }
    }

    private var emptySlot: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.88, green: 0.85, blue: 0.80).opacity(0.4))
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.80, green: 0.76, blue: 0.70).opacity(0.3))
                        .frame(width: 20, height: 20)
                )
            Text(" ")
                .font(.system(size: 9))
        }
    }

    private func slotColor(for difficulty: GridSize) -> Color {
        switch difficulty {
        case .five:  return Color(red: 0.76, green: 0.88, blue: 0.72)
        case .six:   return Color(red: 0.95, green: 0.85, blue: 0.65)
        case .seven: return Color(red: 0.85, green: 0.72, blue: 0.88)
        case .eight: return Color(red: 0.72, green: 0.82, blue: 0.90)
        case .nine:  return Color(red: 0.90, green: 0.74, blue: 0.72)
        }
    }

    private func shortDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3 else { return dateStr }
        return "\(parts[1])/\(parts[2])"
    }

    private func difficultyLabel(_ difficulty: GridSize) -> String {
        difficulty.label
    }

    // MARK: - Share

    @MainActor
    private func renderAndShare() {
        let view = GardenSnapshotView(playerData: playerData)
        let renderer = ImageRenderer(content: view)
        renderer.scale = displayScale
        if let image = renderer.uiImage {
            gardenImage = image
            showShareSheet = true
        }
    }
}

// MARK: - Snapshot view (used for ImageRenderer; no NavigationStack)

private struct GardenSnapshotView: View {
    var playerData: PlayerData

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let minSlots = 24

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("🌿")
                    .font(.system(size: 24))
                Text("My Puzzle Garden")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(Color(red: 0.20, green: 0.38, blue: 0.22))
            }

            LazyVGrid(columns: columns, spacing: 8) {
                let totalSlots = max(minSlots, playerData.garden.count + 6)
                ForEach(0..<totalSlots, id: \.self) { index in
                    if index < playerData.garden.count {
                        snapshotPlantSlot(playerData.garden[index])
                    } else {
                        snapshotEmptySlot
                    }
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.97, green: 0.95, blue: 0.90))
        .frame(width: 360)
    }

    private func snapshotPlantSlot(_ plant: Plant) -> some View {
        Group {
            if let assetName = plant.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Text(plant.emoji)
                    .font(.system(size: 32))
            }
        }
        .frame(width: 48, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(slotColor(for: plant.difficulty).opacity(0.3))
        )
    }

    private var snapshotEmptySlot: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(red: 0.88, green: 0.85, blue: 0.80).opacity(0.4))
            .frame(width: 48, height: 48)
    }

    private func slotColor(for difficulty: GridSize) -> Color {
        switch difficulty {
        case .five:  return Color(red: 0.76, green: 0.88, blue: 0.72)
        case .six:   return Color(red: 0.95, green: 0.85, blue: 0.65)
        case .seven: return Color(red: 0.85, green: 0.72, blue: 0.88)
        case .eight: return Color(red: 0.72, green: 0.82, blue: 0.90)
        case .nine:  return Color(red: 0.90, green: 0.74, blue: 0.72)
        }
    }
}

// MARK: - UIActivityViewController wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    GardenView(playerData: PlayerData.shared)
}
