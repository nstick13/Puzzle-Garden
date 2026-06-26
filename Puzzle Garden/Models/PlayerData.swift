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
    var schemaVersion: Int = 1
    var stats: PlayerStats = PlayerStats()
    /// Legacy v1 collection. Still written for one version as a rollback safety net.
    var garden: [Plant] = []
    /// v2 source of truth, keyed by package id ("garden", "cucina", …).
    var collections: [String: [CollectibleSet]] = [:]
    var dailyHistory: [String: DailyResult] = [:]
    var lastPlayedDate: String?
    /// Last date the daily growth tick ran, so each collectible advances at most once per day.
    var lastGrowthDate: String?
    /// Last date ANY puzzle was solved (daily or free play). Drives wilting, independent of the
    /// daily-only streak clock in `lastPlayedDate`.
    var lastTendedDate: String?
    /// Bed (set) ids whose "in bloom" celebration has already played, so it fires once.
    var celebratedSetIDs: Set<String> = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, stats, garden, collections, dailyHistory
        case lastPlayedDate, lastGrowthDate, lastTendedDate, celebratedSetIDs
    }

    /// Tolerant decode: missing keys fall back to defaults so v1 save files (which lack the
    /// v2 fields) load without throwing — otherwise the decode would fail and wipe the garden.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        stats         = try c.decodeIfPresent(PlayerStats.self, forKey: .stats) ?? PlayerStats()
        garden        = try c.decodeIfPresent([Plant].self, forKey: .garden) ?? []
        collections   = try c.decodeIfPresent([String: [CollectibleSet]].self, forKey: .collections) ?? [:]
        dailyHistory  = try c.decodeIfPresent([String: DailyResult].self, forKey: .dailyHistory) ?? [:]
        lastPlayedDate = try c.decodeIfPresent(String.self, forKey: .lastPlayedDate)
        lastGrowthDate = try c.decodeIfPresent(String.self, forKey: .lastGrowthDate)
        lastTendedDate = try c.decodeIfPresent(String.self, forKey: .lastTendedDate)
        celebratedSetIDs = try c.decodeIfPresent(Set<String>.self, forKey: .celebratedSetIDs) ?? []
    }
}

// MARK: - Plant asset names (SVG imagesets in Assets.xcassets/Plants/)

enum PlantAsset {
    static let easy:   [String] = ["Plants/herb_lavender", "Plants/herb_chamomile", "Plants/herb_clover", "Plants/herb_mint", "Plants/herb_thyme"]
    static let medium: [String] = ["Plants/flower_rose", "Plants/flower_foxglove", "Plants/flower_hydrangea", "Plants/flower_dahlia", "Plants/flower_sweetpeas"]
    static let hard:   [String] = ["Plants/tree_apple_blossom", "Plants/shrub_rosehip", "Plants/tree_elderflower", "Plants/vine_climbing_roses"]
    /// Assets pulled from rotation; existing planted instances are swapped on load.
    static let retired: [String] = ["Plants/vine_wisteria"]

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
    /// v2 collections, keyed by package id. Garden lives at `GardenPackage.packageID`.
    private(set) var collections: [String: [CollectibleSet]]
    private(set) var dailyHistory: [String: DailyResult]
    private var lastPlayedDate: String?
    private var lastGrowthDate: String?
    private var lastTendedDate: String?
    private(set) var celebratedSetIDs: Set<String>

    var lastAwardedPlant: Plant?

    private static let gardenColumns = 6

    private init() {
        var store = Self.load()
        Self.migrateIfNeeded(&store)
        Self.refreshBedNames(&store)
        Self.replaceRetiredAssets(&store)
        stats = store.stats
        garden = store.garden
        collections = store.collections
        dailyHistory = store.dailyHistory
        lastPlayedDate = store.lastPlayedDate
        lastGrowthDate = store.lastGrowthDate
        lastTendedDate = store.lastTendedDate
        celebratedSetIDs = store.celebratedSetIDs

        // Advance growth for any day(s) that passed while the app was closed.
        advanceGrowthIfNeeded()
    }

    /// Record that a bed's bloom celebration has played (fires once per bed).
    func markCelebrated(_ setID: String) {
        guard !celebratedSetIDs.contains(setID) else { return }
        celebratedSetIDs.insert(setID)
        save()
    }

    // MARK: - v2 collection accessors

    /// The garden package's sets (the beds), in fill order.
    var gardenSets: [CollectibleSet] {
        collections[GardenPackage.packageID] ?? []
    }

    /// Whole days since the last solve (any mode). 0 if never played or played today.
    /// Falls back to the streak clock for pre-v2 saves that have no `lastTendedDate` yet.
    var daysSinceTended: Int {
        guard let last = lastTendedDate ?? lastPlayedDate,
              let lastDate = Self.dateFormatter().date(from: last),
              let todayDate = Self.dateFormatter().date(from: Self.todayString())
        else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let days = cal.dateComponents([.day], from: lastDate, to: todayDate).day ?? 0
        return max(0, days)
    }

    /// Wilt threshold — gentle, fully reversible (see GARDEN_V2.md §Wilting). Tune here.
    static let wiltThresholdDays = 5

    /// True when the scene should show the wilted presentation. Derived, never persisted.
    var isWilted: Bool { daysSinceTended >= Self.wiltThresholdDays }

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

        // v2: dual-write the same reward into the garden package's beds.
        awardCollectible(difficulty: difficulty, isDaily: isDaily, date: today)

        // Any solve tends the garden — clears a wilt lapse.
        lastTendedDate = today

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

    // MARK: - v2 rearrange

    /// Move/swap a collectible within its bed (tap-to-rearrange). `toSlot` may be empty
    /// (just moves) or occupied (swaps the two). No-op across different beds.
    func moveCollectible(setID: String, fromSlot: Int, toSlot: Int) {
        guard fromSlot != toSlot,
              var sets = collections[GardenPackage.packageID],
              let bedIndex = sets.firstIndex(where: { $0.id == setID }),
              let aIndex = sets[bedIndex].members.firstIndex(where: { $0.slot == fromSlot })
        else { return }

        if let bIndex = sets[bedIndex].members.firstIndex(where: { $0.slot == toSlot }) {
            sets[bedIndex].members[aIndex].slot = toSlot
            sets[bedIndex].members[bIndex].slot = fromSlot
        } else {
            sets[bedIndex].members[aIndex].slot = toSlot
        }
        collections[GardenPackage.packageID] = sets
        save()
    }

    // MARK: - v2 collectible award + growth

    /// Drop a freshly earned collectible (as `.seed`) into the garden's first non-full bed,
    /// opening a new bed when all are full. Flora is drawn from the owning area's pool.
    private func awardCollectible(difficulty: GridSize, isDaily: Bool, date: String) {
        let pkg = GardenPackage.shared
        let tier = CollectibleTier(gridSize: difficulty)
        var sets = collections[pkg.id] ?? []

        // Find the active (first non-full) bed, or open a new one in its area.
        var activeIndex = sets.firstIndex { !$0.isFull }
        if activeIndex == nil {
            let newIndex = sets.count
            sets.append(CollectibleSet(
                id: "\(pkg.id)-bed-\(newIndex)",
                templateID: "bed",
                displayName: pkg.displayName(forSetIndex: newIndex),
                capacity: pkg.setCapacity
            ))
            activeIndex = sets.count - 1
        }

        guard let index = activeIndex else { return }
        let area = pkg.area(forBedIndex: index)
        let slot = sets[index].members.count
        let item = Collectible(
            packageID: pkg.id,
            setID: sets[index].id,
            assetBase: area.asset(for: tier),
            emoji: area.emoji(for: tier),
            tier: tier,
            state: .seed,
            slot: slot,
            earnedDate: date,
            fromDaily: isDaily
        )
        sets[index].members.append(item)
        collections[pkg.id] = sets
    }

    // MARK: - v2 area queries (for the world map + zoom)

    var gardenAreas: [GardenArea] { GardenPackage.shared.areas }

    /// Beds belonging to area `k` (a slice of the flat bed list, which fills in order).
    func setsForArea(_ k: Int) -> [CollectibleSet] {
        let pkg = GardenPackage.shared
        guard k < pkg.areas.count else { return [] }
        let start = pkg.areaStartIndex(k)
        let end = min(start + pkg.areas[k].bedCount, gardenSets.count)
        return start < end ? Array(gardenSets[start..<end]) : []
    }

    /// An area is reachable once the beds before it have begun filling.
    func isAreaUnlocked(_ k: Int) -> Bool {
        GardenPackage.shared.areaStartIndex(k) <= gardenSets.count
    }

    func areaBloomedBeds(_ k: Int) -> Int { setsForArea(k).filter { $0.isComplete }.count }

    func isAreaComplete(_ k: Int) -> Bool {
        let area = GardenPackage.shared.areas[k]
        let s = setsForArea(k)
        return s.count == area.bedCount && s.allSatisfy { $0.isComplete }
    }

    /// The area currently being tended (first unlocked, not-yet-complete area).
    var activeAreaIndex: Int {
        let pkg = GardenPackage.shared
        for k in pkg.areas.indices where isAreaUnlocked(k) && !isAreaComplete(k) { return k }
        return pkg.areas.count - 1
    }

    /// Advance growth once per calendar day: every collectible earned on an earlier day
    /// steps `.seed`→`.growing`→`.complete`. Today's rewards stay young until tomorrow.
    private func advanceGrowthIfNeeded() {
        let today = Self.todayString()
        guard lastGrowthDate != today else { return }

        for (pkgID, var sets) in collections {
            for s in sets.indices {
                for m in sets[s].members.indices where sets[s].members[m].earnedDate != today {
                    sets[s].members[m].state = sets[s].members[m].state.advanced
                }
            }
            collections[pkgID] = sets
        }
        lastGrowthDate = today
        save()
    }

    // MARK: - Migration (v1 garden → v2 collections)

    /// One-time, non-destructive: wrap legacy `Plant`s into the garden package as completed,
    /// bloomed beds. Old plants therefore appear as a finished garden — no loss. Runs only if
    /// the garden package hasn't been populated yet.
    private static func migrateIfNeeded(_ store: inout PlayerDataStore) {
        let gid = GardenPackage.packageID
        guard store.collections[gid] == nil else { return }

        let pkg = GardenPackage.shared
        var sets: [CollectibleSet] = []
        for (i, plant) in store.garden.enumerated() {
            let bedIndex = i / pkg.setCapacity
            if bedIndex >= sets.count {
                sets.append(CollectibleSet(
                    id: "\(gid)-bed-\(bedIndex)",
                    templateID: "bed",
                    displayName: pkg.displayName(forSetIndex: bedIndex),
                    capacity: pkg.setCapacity
                ))
            }
            sets[bedIndex].members.append(Collectible(
                id: plant.id,
                packageID: gid,
                setID: sets[bedIndex].id,
                assetBase: plant.assetName ?? pkg.assetBase(forTier: CollectibleTier(gridSize: plant.difficulty)),
                emoji: plant.emoji,
                tier: CollectibleTier(gridSize: plant.difficulty),
                state: .complete,
                slot: i % pkg.setCapacity,
                earnedDate: plant.earnedDate,
                fromDaily: plant.fromDaily
            ))
        }
        store.collections[gid] = sets
        // Pre-existing migrated beds are already bloomed — mark them celebrated so the
        // first v2 launch doesn't fire a storm of sparkles.
        store.celebratedSetIDs.formUnion(sets.filter { $0.isComplete }.map { $0.id })
        store.schemaVersion = max(store.schemaVersion, 2)
    }

    /// Re-derive every bed's display name from its fill order, so renames in
    /// `GardenPackage` always take effect even for beds saved under the old names.
    private static func refreshBedNames(_ store: inout PlayerDataStore) {
        let pkg = GardenPackage.shared
        guard var sets = store.collections[pkg.id] else { return }
        for i in sets.indices {
            sets[i].displayName = pkg.displayName(forSetIndex: i)
        }
        store.collections[pkg.id] = sets
    }

    /// Swap any already-planted, now-retired plant art for a stable replacement from
    /// the current pool (keyed off the collectible's id so it doesn't change per launch).
    private static func replaceRetiredAssets(_ store: inout PlayerDataStore) {
        guard !PlantAsset.retired.isEmpty, !PlantAsset.hard.isEmpty else { return }
        for (pid, var sets) in store.collections {
            var changed = false
            for s in sets.indices {
                for m in sets[s].members.indices where PlantAsset.retired.contains(sets[s].members[m].assetBase) {
                    let pick = PlantAsset.hard[Int(sets[s].members[m].id.uuid.0) % PlantAsset.hard.count]
                    sets[s].members[m].assetBase = pick
                    changed = true
                }
            }
            if changed { store.collections[pid] = sets }
        }
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
        var store = PlayerDataStore()
        store.schemaVersion = 2
        store.stats = stats
        store.garden = garden
        store.collections = collections
        store.dailyHistory = dailyHistory
        store.lastPlayedDate = lastPlayedDate
        store.lastGrowthDate = lastGrowthDate
        store.lastTendedDate = lastTendedDate
        store.celebratedSetIDs = celebratedSetIDs
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
