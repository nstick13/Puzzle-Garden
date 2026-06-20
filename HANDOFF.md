# Puzzle Garden — Agent Handoff

_Last updated: 2026-06-20_

## What this is

**Puzzle Garden** is a cozy, ad-free **Queens / Star Battle** logic puzzle game for iOS.
Solving puzzles plants flowers in a persistent garden — the garden is the retention hook
and the core differentiator vs. the Meowdoku/Starstruck/Queens clone market.

- **Platform:** iOS 16+, SwiftUI, Swift 5.9+, iPhone + iPad
- **Dependencies:** none — all Apple-native (SwiftUI, StoreKit 2 planned, ImageRenderer planned)
- **Persistence:** Codable JSON to `player_data.json` in Documents (deliberately *not* SwiftData — chosen for migration-free iteration)
- **Positioning:** "The logic puzzle you love, without the nonsense." No ads, ever. Free daily puzzle + $2.99 one-time IAP for unlimited free play.
- **Full product spec:** see [`puzzle-garden-scope.md`](puzzle-garden-scope.md) — read this for product/monetization/UX detail.

## Where we are (build status)

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Core engine: puzzle model, generator, solver, uniqueness validation, unit tests | ✅ Complete |
| 2 | Game UI: grid, tap/long-press/drag gestures, conflict shake, win overlay, timer, home | ✅ Complete |
| 3 | Garden + daily + stats: garden grid, plant awards, streaks, stats dashboard, calendar | ✅ Complete |
| — | Session 5 win-detection root-cause fix (see learnings) | ✅ Complete |
| 4 | Share card (emoji + ImageRenderer) + StoreKit 2 IAP + paywall | ⏳ Next up |
| 5 | Polish: sound, haptics, settings, app icon, onboarding | ⏳ Pending |
| 6 | Ship: screenshots, ASO, privacy policy, TestFlight, App Review | ⏳ Pending |

## Code map (what's actually built)

```
Puzzle Garden/
├── Models/
│   ├── Puzzle.swift            // Puzzle struct + GridSize enum (5×5/6×6/7×7)
│   ├── QueensSolver.swift      // backtracking solve(), isValid(), countSolutions()
│   ├── PuzzleGenerator.swift   // flood-fill regions, SeededRNG (xorshift64), DailyPuzzleManager
│   ├── GameState.swift         // @Observable game state machine (current session)
│   └── PlayerData.swift        // @Observable singleton, JSON persistence, streaks/plants/daily
├── Views/
│   ├── Game/GameView.swift, CellView.swift
│   ├── Garden/GardenView.swift
│   ├── Home/HomeView.swift
│   └── Stats/StatsView.swift, CalendarView.swift
├── ContentView.swift           // TabView: Home / Garden / Stats
└── Puzzle_GardenApp.swift      // injects PlayerData.shared
```

## Critical gotchas (don't relearn these the hard way)

1. **`@Observable` + SwiftUI animation:** any `@Observable` model that drives a transition must `import SwiftUI`. But do **not** call `withAnimation` from inside the model — it doesn't reliably propagate. Mutate the property plainly and put `.animation(_, value:)` on the **View** side. (This bit us twice on win detection.)
2. **Fire-once side effects (e.g. record solve on win):** use a callback closure on the model (`var onWin: (() -> Void)?`, set in `.onAppear`), **not** `.task(id:)` or `.onChange(of:)`. Those silently skip when the state change originates from a gesture handler inside an `@Observable` model.
3. **Diagonal rule is adjacency-only** (`|Δr|==1 && |Δc|==1`), NOT the full N-Queens diagonal sweep. Matches LinkedIn Queens rules.
4. **New Swift files auto-register:** the project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 15+), so files dropped in `Puzzle Garden/` are picked up automatically — no `.pbxproj` edits.
5. **Daily seed:** `year*10000 + month*100 + day` → `UInt64`, deterministic per day, device-local (no server).
6. **Uniqueness validation** uses `countSolutions` with early exit at 2; expect ~30–60% discard rate on 7×7. Grid size is the primary difficulty lever.

## Git / repo status

- **GitHub repo:** [https://github.com/nstick13/Puzzle-Garden](https://github.com/nstick13/Puzzle-Garden) — public, all commits pushed.
- Local repo is clean and in sync with `origin/main`.
- `.gitignore` excludes `xcuserdata/` and `DerivedData/` — no Xcode user data tracked.

## Open product decisions

1. **Plant art** — commission illustrator, AI-generate, or minimal/geometric? (Currently emoji placeholders by difficulty tier: herbs/flowers/trees.)
2. **Garden layout at launch** — auto-place only, or allow rearranging? (Scope says keep v1 dead simple.)
3. **Sound direction** — naturalistic ambient vs. stylized.
4. **TestFlight beta timeline.**
5. **Name availability** — "Puzzle Garden" is generic; verify App Store / domain / handles before committing. Backups: Garden Logic, Bloom Puzzle, Plot & Plant.

## Suggested next task

Phase 4: start with the **text/emoji share card** (low-risk, high marketing value — every share is a free impression), then **StoreKit 2 full-access IAP** (`com.puzzlegarden.fullaccess`, non-consumable, verified via `Transaction.currentEntitlements`, no server). Daily puzzle must always stay free; only Free Play is gated.
