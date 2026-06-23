import Foundation

// MARK: - Collection Package model (v2)
//
// The reusable spine behind the v2 garden and every future content package
// (Italian food, aquarium, …). See GARDEN_V2.md / ILLUSTRATION.md.
//
//   Scene  = a generic SceneView that renders a package's sets   (step 2)
//   Set    = a finishable group of collectibles (a bed / a recipe) — `CollectibleSet`
//   Item   = one earned reward with a growth state               — `Collectible`
//   Skin   = a `CollectionPackage` descriptor (palette, verb, ambient, naming)
//
// Step 1 ships the model + the garden descriptor + migration, dual-writing
// alongside the legacy `Plant`/`garden` array so nothing visual breaks yet.

/// Visual tier of a collectible, derived from puzzle difficulty.
/// The metaphor changes per package; the "small/common → large/prized" feel is constant.
enum CollectibleTier: Int, Codable {
    case sprig = 1   // 5×5  — herb / pantry staple
    case bloom        // 6×6  — flower / ingredient
    case specimen     // 7×7+ — tree·vine / finished dish

    init(gridSize: GridSize) {
        switch gridSize {
        case .five:                       self = .sprig
        case .six:                        self = .bloom
        case .seven, .eight, .nine:       self = .specimen
        }
    }
}

/// Growth state. Rewards arrive `.seed` and advance one step per calendar day the app opens.
enum CollectibleState: String, Codable, CaseIterable {
    case seed, growing, complete

    /// One step toward fully grown. `.complete` is terminal.
    var advanced: CollectibleState {
        switch self {
        case .seed:                  return .growing
        case .growing, .complete:    return .complete
        }
    }
}

/// One earned reward occupying a slot in a set's scene.
struct Collectible: Codable, Identifiable {
    var id: UUID = UUID()
    var packageID: String
    var setID: String
    /// Asset image-set base name, e.g. "Plants/flower_rose". State art is derived per
    /// ILLUSTRATION.md; for now the base resolves directly (no `_seed`/`_growing` suffix yet).
    var assetBase: String
    /// Emoji fallback for rendering before/without art (mirrors legacy `Plant.emoji`).
    var emoji: String
    var tier: CollectibleTier
    var state: CollectibleState
    /// Position within its set's scene. Replaces the unused `Plant.gardenRow/gardenCol`;
    /// this is what tap-to-rearrange edits.
    var slot: Int
    var earnedDate: String
    var fromDaily: Bool
}

/// A finishable group of collectibles — a flowerbed (garden) or a recipe (cucina).
struct CollectibleSet: Codable, Identifiable {
    var id: String
    var templateID: String
    var displayName: String
    var capacity: Int
    var members: [Collectible] = []

    var isFull: Bool { members.count >= capacity }
    var completedCount: Int { members.filter { $0.state == .complete }.count }
    /// True once every slot holds a fully-grown collectible — the celebration trigger.
    var isComplete: Bool { isFull && completedCount >= capacity }
}

// MARK: - Package descriptor (the Skin)

/// Look/feel tokens for a package. Mirrors hex tokens in ILLUSTRATION.md.
struct PackagePalette {
    var accentHex: String       // package accent (garden green, cucina coral)
    var stageHex: String        // bed/shelf fill
}

/// Ambient-life configuration. Fully fleshed out in step 3 (sun-by-time, breeze, critter).
struct AmbientConfig {
    var hasSun: Bool = true
    var hasBreeze: Bool = true
    /// Asset/identifier for the wandering critter (cat for garden).
    var critter: String = "cat"
}

/// A content package. Garden is the first instance; Italian food etc. are added by
/// supplying another descriptor — no new screens.
protocol CollectionPackage {
    var id: String { get }
    var displayName: String { get }
    /// Past-tense reward verb shown on award ("Planted", "Served").
    var rewardVerb: String { get }
    var palette: PackagePalette { get }
    var ambient: AmbientConfig { get }

    /// Capacity of an open set (a garden bed). Recipe-style packages override fill logic later.
    var setCapacity: Int { get }
    /// Human name for the Nth set in this package ("Wildflower bed", "Herb corner", …).
    func displayName(forSetIndex index: Int) -> String
    /// Asset base for a freshly earned collectible of the given tier.
    func assetBase(forTier tier: CollectibleTier) -> String
    /// Emoji fallback for the given tier.
    func emoji(forTier tier: CollectibleTier) -> String
}

// MARK: - Garden package

/// The garden: open beds of 5, filled by whatever you earn. Reuses the existing
/// `PlantAsset`/`PlantEmoji` pools so v1 art carries straight over.
struct GardenPackage: CollectionPackage {
    static let shared = GardenPackage()
    static let packageID = "garden"

    let id = GardenPackage.packageID
    let displayName = "My garden"
    let rewardVerb = "Planted"
    let palette = PackagePalette(accentHex: "#336135", stageHex: "#6B4A2E")
    let ambient = AmbientConfig(hasSun: true, hasBreeze: true, critter: "cat")
    let setCapacity = 5

    private let bedNames = [
        "Wildflower bed", "Herb corner", "Cottage border",
        "Orchard row", "Rose arbor", "Meadow patch",
    ]

    func displayName(forSetIndex index: Int) -> String {
        let name = bedNames[index % bedNames.count]
        let cycle = index / bedNames.count
        return cycle == 0 ? name : "\(name) \(cycle + 1)"
    }

    private func tierToGridSize(_ tier: CollectibleTier) -> GridSize {
        switch tier {
        case .sprig:    return .five
        case .bloom:    return .six
        case .specimen: return .seven
        }
    }

    func assetBase(forTier tier: CollectibleTier) -> String {
        PlantAsset.random(for: tierToGridSize(tier))
    }

    func emoji(forTier tier: CollectibleTier) -> String {
        PlantEmoji.random(for: tierToGridSize(tier))
    }
}
