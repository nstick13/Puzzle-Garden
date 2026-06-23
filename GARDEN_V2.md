# Garden v2 — Living Scene & the Collection Package Pattern

Branch: `v2.0-garden-redesign`. Companion: `ILLUSTRATION.md` (art token contract).

## Why

v1's garden is an **inventory**: a `LazyVGrid` filled left-to-right by index. Every reward
lands in the next identical box, plants never change, there's no goal beyond "more stickers,"
and nothing generalizes to future content. (`Plant.gardenRow/gardenCol` were added in v1 but
the layout ignores them — evidence the spatial idea was always wanted.)

v2 makes the garden a **place that lives and fills in**, and — more importantly — makes the
garden the *first instance of a reusable pattern* so packages (Italian food, aquarium, night
sky) are **data + assets, not new screens**.

---

## The pattern: Scene + Collectible + Set + Skin

Four parts. Every package is the same four; only the data and art change.

| Part | Garden | Italian food (La Cucina) |
|---|---|---|
| **Scene** — a place that visibly fills in | a plot with beds | a trattoria table / pantry |
| **Collectible** — earned per win, tiered by difficulty | herb → flower → tree | staple → ingredient → dish |
| **Set** — finishable group of collectibles → something bigger | a *bed* blooms when full | a *recipe* serves when complete |
| **Skin** — palette, reward verb, copy, ambient | "plant" 🌱, green/pink | "cook/serve" 🍅, coral/amber |

Two engagements the grid lacks, baked in for *all* packages:

1. **Growth over time** — a reward arrives as `.seed`, advances to `.growing`, and reaches
   `.complete` on a later visit. Reason to return tomorrow beyond the streak.
2. **Sets as goals** — a bed of 5 / recipe of 6 is a finishable dopamine chunk. A package
   ships as a *bundle of sets to complete*, which is also the natural unit to sell as IAP.

---

## Data model

Replaces `Plant`. Migration plan below (§Migration) keeps existing saved gardens intact.

```swift
enum CollectibleTier: Int, Codable { case sprig = 1, bloom, specimen }   // maps from GridSize
enum CollectibleState: String, Codable { case seed, growing, complete }

struct Collectible: Codable, Identifiable {
    var id = UUID()
    var packageID: String          // "garden", "cucina"
    var setID: String              // which Set it belongs to (a bed / a recipe)
    var assetBase: String          // e.g. "garden/flower_rose" → +"_seed/_growing/_complete"
    var tier: CollectibleTier
    var state: CollectibleState
    var slot: Int                  // position within its set's scene (replaces row/col)
    var earnedDate: String
    var fromDaily: Bool
}

struct CollectibleSet: Codable, Identifiable {       // a bed / a recipe
    var id: String
    var displayName: String        // "Wildflower bed", "Cacio e pepe"
    var capacity: Int              // 5, 6…
    var members: [Collectible]     // filled as you earn
    var isComplete: Bool { members.filter { $0.state == .complete }.count >= capacity }
}

// Package = static descriptor (the Skin), authored once, drives a generic SceneView.
protocol CollectionPackage {
    var id: String { get }
    var displayName: String { get }       // "My garden", "La cucina"
    var rewardVerb: String { get }        // "Planted", "Served"
    var palette: PackagePalette { get }   // accent ramp + stage tint (see ILLUSTRATION.md)
    var sets: [SetTemplate] { get }       // ordered sets the player fills
    var ambient: AmbientConfig { get }    // sun + breeze + critter (see §Ambient)
}
```

`PlayerData` gains `collections: [String: [CollectibleSet]]` keyed by packageID. `awardPlant`
becomes `award(into: activePackage)` — drop the new collectible into the first non-full set,
as `.seed`; a daily-tick advances states toward `.complete`.

### State progression (the "come back tomorrow")
- On award → `.seed`.
- On the **next calendar day the app opens** → each `.seed` → `.growing`, each `.growing` →
  `.complete` (drive off `lastPlayedDate`, which already exists). One step per day so a fresh
  reward is always visibly "young" and blooms on a return visit.
- When a set hits `isComplete` → one-time celebration (sparkle + haptic + the set's "served/
  bloomed" hero state). This is the payoff moment.

### Wilting (lapse mechanic) — gentle, never punishing
If the player stops returning, the scene shows it — a soft "the garden misses you" rather than
loss. **Cozy app rule: wilting is fully reversible and destroys no progress.** (Project memory:
the hint engine was pulled for *scolding* — wilting must never scold.)

- **Trigger:** `daysSinceLastPlayed = today − lastPlayedDate` (both already tracked). At
  **≥5 days**, the package enters a `wilted` presentation. One threshold to start; optionally a
  second deeper droop at ~10 days. No notification nagging unless the user opted into reminders.
- **Wilting is a presentation layer, NOT a new growth state.** Each collectible keeps its real
  `state` (`seed/growing/complete`) and `slot` untouched. A package-level `isWilted` flag (derived,
  not persisted) drives a uniform visual modifier — see below. So nothing is "lost": a fully
  bloomed bed that wilts is still a bloomed bed underneath.
- **Recovery = the next solve.** Playing again clears the lapse: collectibles "perk up" with a
  quick water/revive animation (droop → upright, desaturate → full color) and the ambient sun
  brightens. The reward for coming back is seeing the garden spring back, plus the day's new
  collectible. Frame copy warmly: "Welcome back — your garden perked right up."
- **Ambient ties in:** while wilted, the breeze leaves thin out / drift slower and the cat curls
  up asleep instead of wandering; revival wakes it. Reinforces the mood without text.

Implementation: add `daysSinceLastPlayed` + `isWilted` (`>= wiltThresholdDays`) as computed
properties on the package; gate the wilt modifier on it. The revive animation fires once on the
solve that clears the lapse (use the existing `onWin` closure pattern, not `.onChange`).

---

## Scene & layout

`SceneView(package:)` is the generic renderer. Per package it stacks **set stages** (a bed,
a shelf, a table) in a `ScrollView`. Each stage:

- a rounded `--soil`-family container (no outer border, matching v1's cozy look);
- `capacity` plots laid out in the stage; filled plots render the collectible at its `state`
  art, empty plots render a dashed hole;
- header: set name + `x / capacity` progress;
- **tap a plot to rearrange** within the set (this is what `slot` is for) — light agency,
  no fail state.

Active set = first incomplete set; completed sets stay visible above as a filling scene.

---

## Ambient life (the part that makes it feel alive)

Decorative only — never encodes information; all of it respects `Reduce Motion` (falls back
to a static mid-state). Config per package via `AmbientConfig`.

1. **Sun by system time.** A sun/moon element whose **position and tint track the device
   clock**: low-warm at dawn (right), high-bright midday (center), amber low at dusk (left),
   a moon + cooler stage tint at night. Compute an `0…1` daylight phase from `Date()` +
   `Calendar` once on appear and on `scenePhase` → `.active`; animate position over the arc.
   Drives a subtle stage tint so the garden *feels* like the current time of day.
2. **Breeze leaves.** 2–4 small leaf sprites drift across on a slow looped path (`TimelineView`
   + `.animation`, 6–10s, random offsets), gentle sway. Tier-matched leaf art per package
   (leaves for garden; could be steam/flour wisps for cucina).
3. **Wandering critter.** The cat ambles between plots on a slow timer, pausing to sit
   (ties to the Meowdoku/cats ASO angle in project memory). Per-package critter is swappable
   via `AmbientConfig` (cat for garden; e.g. a mouse/sparrow for cucina).

Implementation note: use `TimelineView(.animation)` for continuous ambient motion so it's
driven by the render loop, not `Timer`; keep the per-package config declarative so a new
package just supplies sprites + a critter, no new animation code. Follow project memory:
`@Observable` models must NOT call `withAnimation` internally — put `.animation(_, value:)`
on the view side.

---

## Italian food (La Cucina) — proof the pattern holds

Same `SceneView`, different descriptor:
- **Scene:** a trattoria — stages are a pantry shelf (staples) and a served table (dishes).
- **Collectibles:** tier1 staples (garlic, basil) → tier2 ingredients (tomato, cheese) →
  tier3 dishes (pasta, pizza) — assets per `ILLUSTRATION.md` coral/amber ramp.
- **Sets = recipes:** "Cacio e pepe" needs its 6 ingredients; completing it *serves the dish*
  (the hero `.complete` payoff).
- **Skin:** verb "Served", terracotta stage tint, breeze = steam wisps, critter = a sparrow.
- **Commerce:** ships as a **second IAP** — mirrors the existing "10×10 as a separate premium
  drop" model in project memory. Garden stays the free retention core.

---

## Migration (don't break existing gardens)

`PlayerDataStore` currently persists `garden: [Plant]`. Plan:
1. Bump store with `collections: [String: [CollectibleSet]]`; keep decoding legacy `garden`.
2. On first v2 launch, if `collections` is empty and `garden` is non-empty: wrap legacy plants
   into a single `garden` package, all as `.complete`, chunked into beds of 5 by earn order
   (preserving `assetName`/`emoji` fallback). Old plants therefore appear as a finished,
   bloomed garden — no loss, instant "look how much you grew."
3. Keep the legacy `garden` array written for one version as a rollback safety net.

Note: this is additive to save format; verify decode of a real v1 save before shipping.

---

## Build order (after these docs)

1. Data layer: `Collectible`/`CollectibleSet`/`CollectionPackage` + `GardenPackage` descriptor
   + migration, behind the existing `PlayerData` API.
2. `SceneView` + `SetStageView` + `CollectibleView` (3 states) with placeholder art.
3. Ambient system (`AmbientConfig`, sun-by-time, breeze, cat) — feel it on device.
4. Real garden art per `ILLUSTRATION.md` (derive seed/growing from existing complete SVGs).
5. Wire awards + daily growth tick; set-complete celebration.
6. Stub `CucinaPackage` to prove the descriptor swap, then gate behind its IAP.
