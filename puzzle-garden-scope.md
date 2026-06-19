# Puzzle Garden — Project Scope

---

## Changelog

### Session 5 — 2026-06-12 (Win Detection Fix)

**Root-cause fix for win detection not recording stats/garden:**

Session 4 patches didn't fully resolve the issue. Two real bugs found:

1. **`withAnimation` from inside `@Observable` model is unreliable** — `GameState.checkWin()` was calling `withAnimation { showWin = true }`, but the animation transaction set inside a model class doesn't reliably propagate to the SwiftUI render cycle. Fixed: removed `withAnimation` from `checkWin()`; set `showWin = true` as a plain mutation; added `.animation(.spring(...), value: game.showWin)` on the ZStack in `GameView` so the transition is driven from the View layer.

2. **`.task(id: game.isSolved)` silently skips with `@Observable` + `@State` gesture mutations** — the `.task(id:)` mechanism depends on SwiftUI re-evaluating the modifier id during view diffing, which doesn't fire reliably when the state change originates from a gesture handler inside an `@Observable` model. `recordSolve` was never being called. Fixed: added `var onWin: (() -> Void)?` callback to `GameState`; `checkWin()` now calls `onWin?()` directly; `GameView` sets `game.onWin` in `.onAppear`. Removed `.task(id: game.isSolved)` entirely.

**Learnings (apply to future sessions):**
- Never call `withAnimation` from an `@Observable` model to drive transitions. Mutate the property plainly; use `.animation(value:)` on the View side.
- For "fire exactly once on win" side effects, use a callback closure on the model (set via `.onAppear`), not `.task(id:)` or `.onChange`. The callback is synchronous and immune to observation timing.

---

### Session 4 — 2026-06-12 (Learnings Phase)

**Win detection & celebration — discovered gaps, patched:**

These features existed in stub form but had two silent failure modes:

1. **No animation transaction around `showWin = true`** — `GameState.swift` only imported `Foundation`. Without `withAnimation`, the `.transition()` on the win overlay had no animation context, and SwiftUI may not reliably flush conditional view insertions without one. Fixed: added `import SwiftUI` to `GameState` and wrapped `showWin = true` in `withAnimation(.spring(...))`.

2. **`onChange(of: isSolved)` for recording solve** — replaced with `.task(id: game.isSolved)`, which is the more reliable SwiftUI idiom for side effects driven by observable state changes and avoids potential timing issues with `@Observable` + `onChange`.

3. **Win overlay** — redesigned with a warm sunshine (☀️) celebration theme: warm cream/yellow background, solve time in a capsule, plant earned badge. Previously had a dark semi-transparent overlay that felt like an error screen rather than a celebration.

**Learnings (apply to future sessions):**
- `GameState` (and any `@Observable` model that triggers SwiftUI animations) should import `SwiftUI` so `withAnimation` is available at the mutation site.
- Use `.task(id:)` over `.onChange(of:)` for side effects that should fire exactly once when a state flag transitions — it's more explicit and less prone to render-cycle edge cases.
- Win state features (overlay, stat recording, timer stop) are tightly coupled and easy to miss in scope planning. Define and test the full "happy path" (place last correct flower → clock stops → overlay appears → stats update) as its own explicit acceptance test during Phase 2.

---

### Session 1 — 2026-06-12

**Phase 1: Core Engine (complete)**
- `Models/Puzzle.swift` — `Puzzle` struct + `GridSize` enum (5×5, 6×6, 7×7)
- `Models/QueensSolver.swift` — backtracking solver with `solve()`, `isValid()`, `countSolutions()`; diagonal rule is adjacency-only (distance-1), matching LinkedIn Queens rules
- `Models/PuzzleGenerator.swift` — randomised flood-fill region generation, seeded xorshift64 RNG (`SeededRNG`), deterministic daily seed via `DailyPuzzleManager`
- `Puzzle GardenTests/Puzzle_GardenTests.swift` — 10 unit tests covering solver correctness, uniqueness, determinism, and generation performance

**Phase 2: Game UI (complete)**

### Session 3 — 2026-06-12

**Phase 3: Garden + Daily + Stats (complete)**
- `Models/PlayerData.swift` — `@Observable` singleton with JSON file persistence; `PlayerStats` (streaks, totals, best times per difficulty), `Plant` (emoji, earned date, difficulty tier, garden position), `DailyResult`, `PlantEmoji` pools by difficulty tier (5×5=herbs, 6×6=flowers, 7×7=trees); `recordSolve()` handles streak logic, plant award, and auto-save
- `Views/Garden/GardenView.swift` — scrollable `LazyVGrid` (6 columns) showing earned plants; emoji per slot with difficulty-tinted background; daily plants show date badge; empty slots as faded placeholders; empty-state prompt
- `Views/Stats/StatsView.swift` — dashboard with current/longest streak cards, total solved, best times per grid size
- `Views/Stats/CalendarView.swift` — monthly calendar grid; days with daily solves show 🌿; today highlighted with ring; tap a solved day to see solve time; forward/back month navigation
- `ContentView.swift` — replaced single `HomeView` with `TabView` (Home / Garden / Stats) with botanical green tint
- `Puzzle_GardenApp.swift` — injects `PlayerData.shared` into `ContentView`
- `Views/Game/GameView.swift` — accepts `isDaily` flag + `PlayerData`; calls `recordSolve()` on win via `onChange(of: isSolved)`; win overlay shows awarded plant emoji + "Plant earned!" text
- `Views/Home/HomeView.swift` — streak badge below title (capsule with "N-day streak"); daily button shows checkmark + lighter green when already solved; passes `isDaily`/`playerData` through to `GameView`
- Deleted `Persistence.swift` (unused CoreData boilerplate from Xcode template)

### Session 2 — 2026-06-12

**Phase 2: Game UI polish**
- `Models/GameState.swift` — shake now triggers only on **wrong** placements (flower placed where `solution[r][c] != 1`), not on any conflict; added `wrongPlacement` toggle and `correctPlacement` coord tracking
- `Views/Game/CellView.swift` — correct flower placements get a spring "pop" scale animation (`1.0 → 1.4 → 1.0`); added `popAnimation` parameter + `@State scale`
- `Views/Game/GameView.swift` — added two-row rules bar below header: row 1 = "1 per row", "1 per column", "1 per color"; row 2 = "Plants can't touch — not even diagonally". Show/hide toggle (eye icon) in header bar, persisted via `@AppStorage("showRules")` (defaults to visible; same key can be read by a future Settings screen)
- `Models/GameState.swift` — `@Observable` state machine; cell states (empty/marked/flower), conflict detection, win check, timer
- `Views/Game/CellView.swift` — region-colored cells, dig mark (xmark), flower (🌿 emoji), real-time correct/wrong feedback (green 🌿 = correct, red xmark = wrong)
- `Views/Game/GameView.swift` — full grid, tap/long-press/drag-to-mark gestures, shake animation on conflict, win overlay with solve time
- `Views/Home/HomeView.swift` — home screen with daily puzzle + free play by difficulty; generation runs off main thread
- `ContentView.swift` — simplified to just render `HomeView`
- `Puzzle_GardenApp.swift` — removed unused CoreData wiring

---

## Product in One Sentence

A cozy, ad-free Queens/Star Battle puzzle game where solving puzzles grows a persistent garden — positioned as the premium alternative to Meowdoku and its clones.

---

## Concept

You're not placing tokens on a grid. You're planting flowers.

Each colored region is a garden plot. Each solved puzzle plants something new. Over days and weeks, the player's garden fills in — a visual record of every puzzle they've solved. The mechanic is identical to Star Battle/Queens. The framing turns a logic exercise into something that feels creative and alive.

This does three things the clone market doesn't:
- Gives players a reason to come back beyond streaks (watch the garden grow)
- Creates a shareable visual that's more interesting than an emoji grid
- Opens a natural path to theme packs without looking like a reskin factory

---

## Positioning

**Target user:** Anyone who downloaded Meowdoku, Starstruck, or Queens Battle and hit the ad wall at level 15. Secondarily: the cozy/cottagecore casual gaming audience.

**Core promise:** The logic puzzle you love, without the nonsense. Plant your garden one puzzle at a time.

**Differentiators:**
- No ads. Ever. Free daily puzzle, one-time purchase for full access.
- Persistent garden that grows with every solved puzzle — a visual collection mechanic.
- Drag-to-mark (the #1 missing feature in competitors).
- Clean, warm aesthetic — not a cat/dog reskin, not a sterile grid.
- No hearts, no energy, no timers, no gates.

**Price:** Free download. $2.99 one-time IAP for full access.

---

## Core Mechanic — Star Battle / Queens

The rules don't change. The language does.

1. Grid divided into N colored "plots" (typically 5×5 up to 7×7 at launch)
2. Plant exactly one flower per row, per column, per plot
3. No two flowers may be adjacent — including diagonally
4. Every puzzle has exactly one solution, reachable by pure logic (no guessing)

In-game, "X marks" become trowel/dig marks. Placing a flower gets a planting animation. Solving the puzzle triggers a bloom.

---

## The Garden — Persistent Collection

This is the feature that differentiates Puzzle Garden from every other Queens clone.

### How it works

- Player solves a puzzle → earns a plant
- Plant type scales with puzzle difficulty:
  - 5×5 (easy): herbs, grasses, ground cover
  - 6×6 (medium): flowers, shrubs
  - 7×7 (hard): trees, flowering vines
- Plants are placed into the player's garden — a scrollable, zoomable view
- The garden fills in over time, becoming a visual diary of puzzles solved
- Daily puzzle plants are visually distinct (marked with the date, slightly special)

### Garden layout

The garden is a fixed canvas (think a rectangular plot) divided into sections. Plants auto-place into the next available spot, or the player can rearrange. Keep it simple at launch — no Farmville drag-and-drop complexity. Just a growing visual collection.

### Why this works for retention

- Day 1: garden is empty, one flower planted
- Day 7: a small patch of green, starting to feel personal
- Day 30: a real garden, visually satisfying, worth showing someone
- The sunk-cost of a growing garden discourages churn

### Future theme packs (post-launch IAP)

- **Cottage Garden** (launch default): English wildflowers, soft pastels, stone paths
- **Japanese Garden**: cherry blossoms, moss, stone lanterns, water features
- **Mediterranean Garden**: lavender, olive trees, terracotta, sun-bleached walls
- **Desert Garden**: succulents, cacti, agave, sand and rock

Each theme is a $0.99–$1.99 IAP. Changes the plant art and garden backdrop. Does not affect gameplay.

---

## Technical Architecture

**Platform:** iOS (iPhone + iPad), SwiftUI
**Minimum target:** iOS 16.0
**Language:** Swift 5.9+
**Dependencies (all Apple-native):**
- SwiftUI — all UI
- StoreKit 2 — IAP
- SwiftData — local persistence (garden, streaks, stats)
- ShareLink + ImageRenderer — garden/result sharing
- No third-party dependencies at launch

**Project structure:**
```
PuzzleGarden/
├── Models/
│   ├── Puzzle.swift              // Grid, regions, solution
│   ├── PuzzleGenerator.swift     // Generation + validation
│   ├── GameState.swift           // Current game session state
│   ├── PlayerStats.swift         // Streaks, history, times
│   ├── Garden.swift              // Persistent garden state
│   └── Plant.swift               // Plant types, metadata, earned date
├── Views/
│   ├── Game/
│   │   ├── GameView.swift        // Main puzzle grid
│   │   ├── CellView.swift        // Individual cell (tap states)
│   │   └── PlotView.swift        // Colored region rendering
│   ├── Garden/
│   │   ├── GardenView.swift      // Persistent garden canvas
│   │   ├── PlantView.swift       // Individual plant rendering
│   │   └── GardenShareView.swift // Rendered garden image for sharing
│   ├── Home/
│   │   ├── HomeView.swift        // Daily puzzle + free play entry
│   │   ├── DailyView.swift       // Daily puzzle wrapper
│   │   └── FreePlayView.swift    // Infinite puzzles by difficulty
│   ├── Stats/
│   │   ├── StatsView.swift       // Streak, solve times, history
│   │   └── CalendarView.swift    // Daily history calendar
│   ├── Store/
│   │   └── StoreView.swift       // IAP unlock + theme packs
│   └── Settings/
│       └── SettingsView.swift    // Sound, haptics, theme
├── Utilities/
│   ├── HapticsManager.swift
│   ├── SoundManager.swift
│   └── DailyPuzzleManager.swift  // Deterministic daily seed
├── Assets.xcassets/
│   ├── Plants/                   // Plant illustrations per theme
│   ├── Garden/                   // Garden backdrop art
│   └── UI/                       // Icons, buttons, palette
└── PuzzleGardenApp.swift         // App entry point
```

---

## Puzzle Generator — The Hard Part

### Approach: Generate-then-validate

1. **Generate a random valid grid:**
   - Randomly partition an N×N grid into N contiguous regions (flood-fill or recursive split)
   - Use backtracking to place N tokens satisfying row/column/region/adjacency constraints
   - Store this as the solution

2. **Validate uniqueness:**
   - Run a constraint solver on the empty grid + regions
   - Confirm exactly one solution exists
   - If multiple solutions, discard and regenerate
   - This is the bottleneck — expect ~30-60% discard rate on larger grids

3. **Difficulty scaling:**
   - Grid size is the primary lever: 5×5 (easy), 6×6 (medium), 7×7 (hard)
   - Secondary: region shape complexity (irregular vs. blocky regions)
   - Tertiary: how many cells are "forced" early in the solve path

### Daily puzzle determinism

Use the date as a seed: `Calendar.current.startOfDay(for: Date())` hashed to a UInt64. Same seed → same puzzle worldwide. Generate on-device, no server needed.

### Performance target

Generation should complete in <500ms on an iPhone 12 or later. For 7×7 grids, consider pre-generating a bank of 100+ puzzles at build time and shipping them as bundled JSON, generating new ones lazily in the background.

---

## UI / Interaction Design

### Grid interaction
- **Single tap** on empty cell → place dig mark (X equivalent, themed as a trowel mark)
- **Double tap** or **long press** on empty cell → plant flower
- **Tap on planted flower** → uproot (remove)
- **Drag across cells** → paint dig marks (the #1 UX complaint about Meowdoku — implement this)

### Visual feedback
- Colored plot regions use earthy, botanical palette (not neon Meowdoku colors)
- Row/column/plot highlights on flower placement
- Conflict: gentle shake + wilting animation
- Solve: bloom animation — flowers open, color spreads, garden grows
- Subtle haptic on plant/uproot
- Satisfying chime progression: dig (soft), plant (medium), solve (full chord)

### Share card — two formats

**Text-based (Wordle-style, for iMessage/Twitter):**
```
🌿🌸🌻🌺🌼
⬜🌸⬜⬜⬜
⬜⬜⬜🌻⬜
🌺⬜⬜⬜⬜
⬜⬜⬜⬜🌼
⬜⬜🌿⬜⬜

🌱 Puzzle Garden — Day 47
6×6 — Planted in 2:14
🌳 12-day streak
```

**Visual (for Instagram/screenshot sharing):**
- Rendered image of the player's garden at current state
- "My garden after 30 days" — aspirational, personal, shareable
- Built with SwiftUI `ImageRenderer`

### Visual identity

**Palette:** warm greens, soft earth tones, cream/linen background, terracotta accents. Not pastel — grounded and slightly warm.

**Typography:** rounded sans-serif for UI (SF Rounded), something with character for the logo/headers.

**Personality:** the garden itself IS the personality. No mascot needed at launch. The plants growing, the garden filling in, the seasonal touches — that's the emotional hook.

**Sound:** naturalistic — birds on app open, soft dig sounds, a bloom chime on solve. Not chiptune, not orchestral. Think: morning in a garden.

---

## Monetization Model

### Freemium with IAP (recommended)

**Free tier:**
- Daily puzzle — one per day, forever, no limit
- Earns one plant per day for the garden
- Full stats and streak tracking
- Share card

**Full Access — $2.99 one-time IAP:**
- Unlimited Free Play puzzles at all difficulty levels
- Each solved puzzle earns a plant (unlimited garden growth)
- All grid sizes unlocked

**Theme Packs — $0.99–$1.99 each (post-launch):**
- Japanese Garden
- Mediterranean Garden
- Desert Garden
- Changes plant art + garden backdrop
- Purely cosmetic, no gameplay impact

### StoreKit 2 implementation
- One non-consumable product: `com.puzzlegarden.fullaccess`
- Theme packs: additional non-consumables per theme
- Verification via `Transaction.currentEntitlements`
- No server-side receipt validation needed
- ~3-4 hours of implementation including theme unlock logic

### Why no ads, ever
This is the positioning. Every competitor monetizes with ads. The App Store reviews for Meowdoku, Starstruck, and Queens Battle are full of people begging for an ad-free option. "No ads ever" is the first line of every screenshot, the subtitle, and the share card. It's the brand.

---

## Data Model (Local Only)

No server. Everything on-device via SwiftData.

```swift
// MARK: - Player

struct PlayerStats: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var totalSolved: Int
    var dailyHistory: [String: DailyResult]  // "2026-06-12": result
    var bestTimes: [GridSize: TimeInterval]
}

struct DailyResult: Codable {
    var date: String
    var gridSize: GridSize
    var solveTime: TimeInterval
    var completed: Bool
}

enum GridSize: String, Codable, CaseIterable {
    case five = "5×5"
    case six = "6×6"
    case seven = "7×7"
}

// MARK: - Garden

struct Garden: Codable {
    var plants: [Plant]
    var theme: GardenTheme
}

struct Plant: Codable, Identifiable {
    var id: UUID
    var type: PlantType          // herb, flower, shrub, tree
    var earnedDate: String       // "2026-06-12"
    var fromDaily: Bool          // daily plants get a subtle marker
    var difficulty: GridSize      // determines plant tier
    var position: GardenPosition // placement in the garden grid
}

enum PlantType: String, Codable, CaseIterable {
    case groundcover  // 5×5 reward
    case flower       // 6×6 reward
    case shrub        // 6×6 reward (variant)
    case tree         // 7×7 reward
}

enum GardenTheme: String, Codable, CaseIterable {
    case cottage       // default, free
    case japanese      // IAP
    case mediterranean // IAP
    case desert        // IAP
}

struct GardenPosition: Codable {
    var row: Int
    var column: Int
}
```

---

## Build Phases

### Phase 1 — Core engine (20-30 hours)
- [ ] Puzzle model (grid, regions, solution)
- [ ] Puzzle generator with backtracking solver
- [ ] Uniqueness validator
- [ ] Difficulty scaling (5×5, 6×6, 7×7)
- [ ] Unit tests: generation, validation, solve correctness

**Milestone: can generate and validate puzzles in a playground.**

### Phase 2 — Game UI (20-30 hours)
- [ ] Grid renderer in SwiftUI with botanical palette
- [ ] Cell tap/long-press interaction (dig marks + planting)
- [ ] Drag-to-mark gesture
- [ ] Plot region highlighting
- [ ] Conflict detection + wilt/shake animation
- [ ] Win detection + bloom animation
- [ ] Timer display
- [ ] Home screen (daily puzzle + free play entry points)

**Milestone: playable puzzle on device with garden-themed interaction.**

### Phase 3 — Garden + daily + stats (15-20 hours)
- [ ] Garden data model (plants, positions, themes)
- [ ] Garden view — scrollable canvas showing planted collection
- [ ] Plant placement logic (auto-place or simple arrangement)
- [ ] Plant art for cottage theme (can be simple/illustrated at launch)
- [ ] Daily puzzle seed system
- [ ] Streak tracking
- [ ] Stats view (current streak, longest, total solved, best times)
- [ ] Daily history calendar view

**Milestone: solving puzzles grows the garden. Daily streak works.**

### Phase 4 — Share + monetization (10-15 hours)
- [ ] Text-based share card (emoji grid + stats)
- [ ] Visual garden share card via ImageRenderer
- [ ] ShareLink integration
- [ ] StoreKit 2: full access IAP ($2.99)
- [ ] Paywall UI (Free Play locked, daily always free)
- [ ] Purchase restoration

**Milestone: can share results, can purchase full access.**

### Phase 5 — Polish (10-15 hours)
- [ ] Sound design (dig, plant, bloom, ambient bird on open)
- [ ] Haptics (place, uproot, solve)
- [ ] Settings (sound on/off, haptics on/off)
- [ ] App icon (flower/garden motif)
- [ ] Launch screen
- [ ] Onboarding — 1-2 screens explaining the mechanic + garden concept
- [ ] Final visual polish pass

**Milestone: feels like a finished, cohesive product.**

### Phase 6 — Ship (5-10 hours)
- [ ] App Store screenshots (6.7" and 6.1")
  - Screenshot 1: "No Ads. Ever." + puzzle in progress
  - Screenshot 2: Garden growing over time
  - Screenshot 3: Daily puzzle + streak
  - Screenshot 4: Share card example
  - Screenshot 5: Stats view
- [ ] App Store description + keywords
- [ ] Privacy policy (simple static page — no data collected)
- [ ] TestFlight beta (Cady + a few friends)
- [ ] App Review submission

**Total estimated: 80-120 hours**

At ~8 hours/week nights and weekends, that's roughly 2.5-4 months to ship.

---

## Launch + UA Strategy

### App Store Optimization (free)
- **Name:** Puzzle Garden
- **Subtitle:** "Daily Logic Puzzles — No Ads"
- **Keywords:** queens puzzle, star battle, logic puzzle, no ads, daily puzzle, garden game, brain training, meowdoku alternative
- **Screenshots:** lead with "No Ads Ever" and the garden collection view

### Apple Search Ads ($5-15/day to start)
- Bid on: meowdoku, queens puzzle, star battle, logic puzzle, starstruck, puzzle game no ads
- Start at $5/day, measure conversion rate for 2 weeks
- Target CPA: under $1.00 per install (at $2.99 IAP, Apple takes 30%, you net ~$2.09 per conversion — but not all free downloads convert, so track IAP conversion rate separately)

### Meta/Instagram ($10-20/day once validated)
- Short video ad: time-lapse of garden growing as puzzles are solved
- "Your garden after 30 days" — aspirational, personal
- Target interests: puzzle games, sudoku, gardening, cozy games, cottagecore
- Lookalike audience once you have 100+ purchasers

### Organic
- The garden share image IS the marketing — every screenshot is a free impression
- Post to r/puzzles, r/iosapps, r/indiegaming, r/CozyGamers
- The cottagecore/cozy gaming community on TikTok and Instagram is a real audience for this specific aesthetic

---

## Risks and Honest Unknowns

**Plant art quality.** The garden is the hook, so the plant illustrations need to feel good. Options: commission a small set from a freelance illustrator ($200-500), use a consistent AI-generated style, or go very minimal/geometric. The art doesn't need to be complex — it needs to be cohesive.

**Puzzle generation quality.** Generating puzzles that feel good to solve (not just technically valid) requires tuning. Early puzzles may feel either trivial or unfairly hard. Plan to iterate.

**Crowded market.** A dozen Queens clones exist. The garden concept and premium positioning differentiate, but you're still fighting for visibility against free apps.

**IAP conversion rate.** What percentage of free daily players convert to $2.99? Industry average for puzzle games is 2-5%. At 1,000 daily downloads and 3% conversion, that's ~$60/day revenue after Apple's cut. Modest but real.

**Garden scope creep.** The garden view can get complex fast if you let it. Keep v1 dead simple: a grid of plant slots that fill in. No drag-to-rearrange, no watering, no seasons. Those are v2 features if the app has traction.

**Name availability.** "Puzzle Garden" is generic — check App Store, domain, and social handles before committing. Have a backup: Garden Logic, Bloom Puzzle, Plot & Plant.

---

## Decisions Resolved

1. ~~Name~~ → Puzzle Garden (pending availability check)
2. ~~Visual identity~~ → Botanical/cottage garden, warm earth tones
3. ~~Monetization~~ → Freemium: free daily puzzle, $2.99 IAP for full access
4. ~~Mascot~~ → No mascot. The garden is the personality.
5. ~~Grid sizes~~ → 5×5, 6×6, 7×7 at launch

## Decisions Still Open

1. **Plant art approach** — commission illustrator, AI-generate, or minimal/geometric?
2. **Garden view complexity at launch** — auto-place only, or allow rearranging?
3. **Sound direction** — naturalistic ambient, or more stylized/musical?
4. **Beta timeline** — TestFlight target date?
