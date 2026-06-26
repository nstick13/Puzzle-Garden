# Puzzle Garden — Agent Handoff

_Last updated: 2026-06-26_

## What this is

**Puzzle Garden** is a cozy, ad-free **Queens / Star Battle** logic puzzle game for iOS.
Solving puzzles plants flowers in a persistent garden — the garden is the retention hook
and the core differentiator vs. the Meowdoku/Starstruck/Queens clone market.

- **Platform:** iOS 16+, SwiftUI, Swift 5.9+, iPhone + iPad
- **Dependencies:** none — all Apple-native (SwiftUI, StoreKit 2, ImageRenderer)
- **Persistence:** Codable JSON to `player_data.json` in Documents (deliberately *not* SwiftData — chosen for migration-free iteration)
- **Positioning:** "The logic puzzle you love, without the nonsense." No ads, ever. Free daily puzzle + $2.99 one-time IAP for unlimited free play.
- **Full product spec:** see [`puzzle-garden-scope.md`](puzzle-garden-scope.md) — read this for product/monetization/UX detail.

## Where we are (build status)

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Core engine: puzzle model, generator, solver, uniqueness validation, unit tests | ✅ Complete |
| 2 | Game UI: grid, tap/long-press/drag gestures, conflict shake, win overlay, timer, home | ✅ Complete |
| 3 | Garden + daily + stats: garden grid, plant awards, streaks, stats dashboard, calendar | ✅ Complete |
| 4 | Share card (emoji + ImageRenderer) + StoreKit 2 IAP + paywall | ✅ Complete |
| 5 | Polish: sound, haptics, settings, app icon, onboarding | ✅ Complete |
| 6 | Ship: screenshots, ASO, privacy policy, TestFlight, App Review | 🚧 v1.0 submitted to App Store (2026-06-26) |

## Current state (2026-06-26)

- **v1.0 submitted** to App Store review. This is the `main` branch.
  - Privacy Policy: `https://nstick13.github.io/Puzzle-Garden/privacy.html`
  - Support URL: `https://nstick13.github.io/Puzzle-Garden/support.html`
  - Both hosted via **GitHub Pages** (serving from `main` `/docs`). App Privacy = "Data Not Collected".
  - 13" iPad screenshots captured from the iPad Pro 13-inch (M5) simulator.
- **v2 garden redesign** in progress on the `v2` branch (zoom-out garden world: per-area flora/scenery, parcels, ambient life). Versioned **2.0**; `main` stays **1.0**.
- **TestFlight workflow for v2:** Xcode Cloud workflow scoped to the `v2` branch only → Archive →
  TestFlight *Internal Testing* (group "Dev"). Pushes to `main` never trigger it; build numbers
  auto-increment. App has zero dependencies, so no `ci_scripts/` needed.

## Code map (what's actually built)

```
Puzzle Garden/
├── Models/
│   ├── Puzzle.swift            // Puzzle struct + GridSize enum (5×5/6×6/7×7)
│   ├── QueensSolver.swift      // backtracking solve(), isValid(), countSolutions()
│   ├── PuzzleGenerator.swift   // flood-fill regions, SeededRNG (xorshift64), DailyPuzzleManager
│   ├── GameState.swift         // @Observable game state machine (current session)
│   ├── PlayerData.swift        // @Observable singleton, JSON persistence, streaks/plants/daily
│   └── StoreManager.swift      // @Observable singleton, StoreKit 2, com.puzzlegarden.fullaccess
├── Views/
│   ├── Game/GameView.swift, CellView.swift, ShareCard.swift
│   ├── Garden/GardenView.swift
│   ├── Home/HomeView.swift
│   ├── Paywall/PaywallView.swift
│   └── Stats/StatsView.swift, CalendarView.swift
├── ContentView.swift           // TabView: Home / Garden / Stats
├── Puzzle_GardenApp.swift      // injects PlayerData.shared
└── Puzzle Garden.storekit      // local StoreKit config for simulator testing (v5 format)
```

## Critical gotchas (don't relearn these the hard way)

1. **`@Observable` + SwiftUI animation:** any `@Observable` model that drives a transition must `import SwiftUI`. Do **not** call `withAnimation` from inside the model — put `.animation(_, value:)` on the **View** side.
2. **Fire-once side effects (e.g. record solve on win):** use a callback closure on the model (`var onWin: (() -> Void)?`, set in `.onAppear`), **not** `.task(id:)` or `.onChange(of:)`. Those silently skip when the state change originates from a gesture handler inside an `@Observable` model.
3. **Diagonal rule is adjacency-only** (`|Δr|==1 && |Δc|==1`), NOT the full N-Queens diagonal sweep. Matches LinkedIn Queens rules.
4. **New Swift files auto-register:** the project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 15+), so files dropped in `Puzzle Garden/` are picked up automatically — no `.pbxproj` edits.
5. **Daily seed:** `year*10000 + month*100 + day` → `UInt64`, deterministic per day, device-local (no server).
6. **Uniqueness validation** uses `countSolutions` with early exit at 2; expect ~30–60% discard rate on 7×7.
7. **StoreKit config file:** must be Xcode-generated (v5 format). Hand-crafted JSON (v2 format) silently returns empty products. Create via File → New → File from Template → StoreKit Configuration File. The working file is at `Puzzle Garden/Puzzle Garden.storekit`. To test purchases in the simulator: Edit Scheme → Run → Options → StoreKit Configuration → select it.
8. **StoreManager is `@MainActor @Observable`** — no deinit (singleton lives for app lifetime). `hasFullAccess` is checked in `HomeView` before launching Free Play; `PaywallView` auto-dismisses when it flips true.

## IAP details

- Product ID: `com.puzzlegarden.fullaccess`
- Type: Non-consumable, $2.99 one-time
- What it gates: Free Play only. Daily puzzle is always free.
- Verification: `Transaction.currentEntitlements` (no server)
- Still needed before ship: add **In-App Purchase capability** in Xcode (Signing & Capabilities tab) — this is a GUI-only step that adds the entitlement to the build.
- Bigger grids: **8×8 and 9×9 shipped** on branch `feature/bigger-puzzles` — generated on-device, ride the existing Free Play gate (part of the $2.99 Full Access, no new IAP).
- Planned value-adds (not yet built): daily archive, streak shield, garden themes

## Feature backlog (post-v1)

Captured 2026-06-26. Roughly ordered by user value / low effort.

1. **Daily share sheet** — a dedicated share for the *daily* puzzle that **hides the actual
   result/solution** and shows only (a) the solve time and (b) the current streak (# of days).
   Spoiler-free, brag-friendly — think Wordle-style. Distinct from the existing win-overlay
   `ShareCard` (which renders the emoji grid). Likely a new card layout in `Views/Game/`.
2. **Free Play "next game"** — after completing a Free Play puzzle, offer **"Next puzzle"** in the
   win overlay so the player can keep going at the same size without bouncing back to Home.
   (Daily stays one-per-day; this is Free-Play only.) Generate a fresh puzzle in place + reset
   `GameState`.
3. **Even better onboarding** — iterate on the first-launch tutorial. Current flow is the 4-page
   `OnboardingView` (rules → "you never have to guess" deduction → two-taps → plants-something-new).
   Open question: where it falls short — interactivity? a guided first solve? Worth a design pass.
4. **In-app brand = "SO MUCH DOKU"** — the App Store name is **SO MUCH DOKU** (because "Puzzle
   Garden" was taken), but the app still says "Puzzle Garden" internally. Align during a design
   pass. App-brand spots → "SO MUCH DOKU": `HomeView.swift:26` (hero), `LaunchScreenView.swift:15`,
   `ShareCard.swift:28` (share header), `GameView.swift:271-272` (share text). Keep
   `GardenView.swift:303` as a *feature* name → "My Garden" (not the app brand). Also set
   `CFBundleDisplayName` = "SO MUCH DOKU" (currently unset → on-device icon label defaults to the
   target name "Puzzle Garden").
5. **⚠️ Before v2 ships — drop the unused background mode.** `Puzzle Garden/Info.plist` declares
   `UIBackgroundModes → remote-notification`, but the app has no networking/push. Declaring an
   unused capability is a common App Review rejection reason — remove the `UIBackgroundModes` key
   (it's leftover boilerplate) before submitting v2.

## Backlog: 10×10 "weekly drop" (potential paid upgrade)

10×10 was deliberately **not** shipped on-device: worst-case generation runs multi-second (the uniqueness refiner blows up at that size). Idea for later:

- **Pre-generate** a curated batch of 10×10 puzzles *offline* (a CLI/script reusing `PuzzleGenerator` — slow generation is fine off-device), then bundle them as pre-configured puzzle data.
- Ship them as a **weekly drop** (a handful of fresh 10×10s each week) rather than infinite on-demand generation.
- Position as a **separate premium upgrade** (its own IAP, e.g. a subscription or one-time "Grandmaster" pack) on top of Full Access — not bundled into the $2.99.
- Engine already supports arbitrary N, so adding `.ten` to `GridSize` is a one-line change; the only real work is the offline generation pipeline + a puzzle-pack loader + the new entitlement.

## Share card details

- `Views/Game/ShareCard.swift` — `ShareCardView` renders emoji grid (colored squares per region, 🌸 on solution cells) + header + footer
- `ImageRenderer` at 3× scale, triggered via `.task(id: game.showWin)` in GameView
- `ShareLink` appears in win overlay once image is ready
- Footer says `puzzlegarden.app` — update when domain is confirmed

## Git / repo status

- **GitHub repo:** [https://github.com/nstick13/Puzzle-Garden](https://github.com/nstick13/Puzzle-Garden) — public.
- `main` = shipped v1.0; active feature work lives on `v2` (this branch).
- `.gitignore` excludes `xcuserdata/`, `DerivedData/`, `build/`, and local tooling (`.claude/`, `.agents/`, `skills-lock.json`).

## Open product decisions

1. **Plant art** — commission illustrator, AI-generate, or minimal/geometric? (Currently emoji placeholders.)
2. **Garden layout at launch** — auto-place only, or allow rearranging? (Scope says keep v1 dead simple.)
3. **Sound direction** — naturalistic ambient vs. stylized.
4. **Name availability** — "Puzzle Garden" is generic; verify App Store / domain / handles before committing. Backups: Garden Logic, Bloom Puzzle, Plot & Plant.
5. **TestFlight beta timeline.**

## Suggested next task

Phases 1–5 are done and v1.0 is in App Store review. Two tracks from here:

1. **Finish v2** on the `v2` branch (garden world redesign) and dogfood via TestFlight (Xcode Cloud → Internal).
2. **Pick from the Feature backlog** above — daily share sheet, Free Play "next game", onboarding polish.
