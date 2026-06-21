import Foundation
import Observation

// MARK: - Supporting types

struct PlayerStats: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalSolved: Int = 0
    var bestTimes: [GridSize: TimeInterval] = [:]

    private enum CodingKeys: String, CodingKey {
        case currentStreak, longestStreak, totalSolved, bestTimes
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentStreak = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try c.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        totalSolved   = try c.decodeIfPresent(Int.self, forKey: .totalSolved) ?? 0
        bestTimes     = try c.decodeIfPresent([GridSize: TimeInterval].self, forKey: .bestTimes) ?? [:]
    }
}

struct Plant: Codable, Identifiable {
    var id: UUID = UUID()
    var emoji: String
    var assetName: String?
    var earnedDate: String
    var fromDaily: Bool
    var difficulty: GridSize
    var gardenRow: Int
    var gardenCol: Int
}

struct DailyResult: Codable {
    var date: String
    var gridSize: GridSize
    var solveTime: TimeInterval
    var completed: Bool
}

// MARK: - Persistent store (JSON file)

private struct PlayerDataStore: Codable {
    var stats: PlayerStats = PlayerStats()
    var garden: [Plant] = []
    var dailyHistory: [String: DailyResult] = [:]
    var lastPlayedDate: String?
}

// MARK: - Plant asset names (SVG imagesets in Assets.xcassets/Plants/)

enum PlantAsset {
    static let easy:   [String] = ["Plants/herb_lavender", "Plants/herb_chamomile", "Plants/herb_clover", "Plants/herb_mint", "Plants/herb_thyme"]
    static let medium: [String] = ["Plants/flower_rose", "Plants/flower_foxglove", "Plants/flower_hydrangea", "Plants/flower_dahlia", "Plants/flower_sweetpeas"]
    static let hard:   [String] = ["Plants/tree_apple_blossom", "Plants/vine_wisteria", "Plants/shrub_rosehip", "Plants/tree_elderflower", "Plants/vine_climbing_roses"]

    static func random(for difficulty: GridSize) -> String {
        let pool: [String]
        switch difficulty {
        case .five:  pool = easy
        case .six:   pool = medium
        // 7×7 and the larger Full Access sizes (8–9) all draw from the "hard" pool for now.
        case .seven, .eight, .nine: pool = hard
        }
        return pool.randomElement()!
    }
}

// MARK: - Plant emoji pools (fallback for legacy saved plants without assetName)

enum PlantEmoji {
    static let easy:   [String] = ["🌱", "🌿", "🪴", "☘️"]
    static let medium: [String] = ["🌸", "🌷", "🌻", "🌺", "💐"]
    static let hard:   [String] = ["🌳", "🌲", "🎋", "🎄"]

    static func random(for difficulty: GridSize) -> String {
        let pool: [String]
        switch difficulty {
        case .five:  pool = easy
        case .six:   pool = medium
        case .seven, .eight, .nine: pool = hard
        }
        return pool.randomElement()!
    }
}

// MARK: - PlayerData (observable singleton)

@Observable
final class PlayerData {
    static let shared = PlayerData()

    private(set) var stats: PlayerStats
    private(set) var garden: [Plant]
    private(set) var dailyHistory: [String: DailyResult]
    private var lastPlayedDate: String?

    var lastAwardedPlant: Plant?

    private static let gardenColumns = 6

    private init() {
        let store = Self.load()
        stats = store.stats
        garden = store.garden
        dailyHistory = store.dailyHistory
        lastPlayedDate = store.lastPlayedDate
    }

    // MARK: - Record a solve

    func recordSolve(difficulty: GridSize, solveTime: TimeInterval, isDaily: Bool) {
        let today = Self.todayString()

        if isDaily {
            guard dailyHistory[today] == nil else { return }
            dailyHistory[today] = DailyResult(
                date: today, gridSize: difficulty, solveTime: solveTime, completed: true
            )
            updateStreak(today: today)
        }

        stats.totalSolved += 1

        if let best = stats.bestTimes[difficulty] {
            if solveTime < best { stats.bestTimes[difficulty] = solveTime }
        } else {
            stats.bestTimes[difficulty] = solveTime
        }

        let plant = awardPlant(difficulty: difficulty, isDaily: isDaily, date: today)
        lastAwardedPlant = plant

        save()
    }

    func isDailySolved() -> Bool {
        dailyHistory[Self.todayString()] != nil
    }

    // MARK: - Streak logic

    private func updateStreak(today: String) {
        let cal = Calendar(identifier: .gregorian)
        let fmt = Self.dateFormatter()

        guard let todayDate = fmt.date(from: today) else { return }
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayDate)!
        let yesterdayStr = fmt.string(from: yesterday)

        if lastPlayedDate == yesterdayStr {
            stats.currentStreak += 1
        } else if lastPlayedDate != today {
            stats.currentStreak = 1
        }

        if stats.currentStreak > stats.longestStreak {
            stats.longestStreak = stats.currentStreak
        }

        lastPlayedDate = today
    }

    // MARK: - Plant award

    private func awardPlant(difficulty: GridSize, isDaily: Bool, date: String) -> Plant {
        let nextIndex = garden.count
        let row = nextIndex / Self.gardenColumns
        let col = nextIndex % Self.gardenColumns

        let plant = Plant(
            emoji: PlantEmoji.random(for: difficulty),
            assetName: PlantAsset.random(for: difficulty),
            earnedDate: date,
            fromDaily: isDaily,
            difficulty: difficulty,
            gardenRow: row,
            gardenCol: col
        )
        garden.append(plant)
        return plant
    }

    // MARK: - Persistence

    private static func fileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("player_data.json")
    }

    private static func load() -> PlayerDataStore {
        guard let data = try? Data(contentsOf: fileURL()),
              let store = try? JSONDecoder().decode(PlayerDataStore.self, from: data)
        else { return PlayerDataStore() }
        return store
    }

    private func save() {
        let store = PlayerDataStore(
            stats: stats,
            garden: garden,
            dailyHistory: dailyHistory,
            lastPlayedDate: lastPlayedDate
        )
        guard let data = try? JSONEncoder().encode(store) else { return }
        try? data.write(to: Self.fileURL(), options: .atomic)
    }

    // MARK: - Date helpers

    static func todayString() -> String {
        dateFormatter().string(from: Date())
    }

    static func dateFormatter() -> DateFormatter {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = .current
        return fmt
    }
}
