# Puzzle Garden — Illustration Style Guide

The contract every illustrated asset must hit so that a flower, a sprig of thyme, and a
plate of cacio e pepe all read as **the same app**. This is what lets us ship new
collection packages (Italian food, aquarium, night sky…) without the art looking bolted on.

Treat this as the spec to "game against": any asset — hand-drawn, commissioned, or
generated — should pass the checklist at the bottom before it ships.

---

## 1. Visual language

| Axis | Decision |
|---|---|
| Geometric ↔ organic | **Organic.** Soft, hand-grown silhouettes. No hard geometry, no isometric. |
| Flat ↔ dimensional | **Flat with soft dimension (2.5D).** One soft drop shadow, gentle interior shading. Never a full 3D render. |
| Detailed ↔ minimal | **Minimal.** Readable as a 48–64pt silhouette first; detail is a bonus, never required to identify the thing. |
| Abstract ↔ representational | **Representational but simplified.** A rose is obviously a rose; it is not botanically accurate. |
| Mood | Cozy, storybook, warm. Calm over energetic. Nothing sharp, glossy, or "gamey." |

**Line style:** rounded everything. Consistent medium stroke, rounded caps and joins, no
sharp corners. Outlines are warm dark brown (`--ink`), never pure black.

---

## 2. Color (illustration subset of the product palette)

Illustrations draw from the product palette only. Hex tokens (already live in the app):

| Token | Hex | Use |
|---|---|---|
| `--cream` | `#F7F2E6` | The **stage** — the backdrop every collectible sits on. Same across all packages. |
| `--ink` | `#4D3824` | Outlines, primary illustration text. The "black" of the app. |
| `--ink-soft` | `#73594... (0.45,0.35,0.25)` | Secondary labels, captions. |
| `--garden-green` | `#336135` | Garden package accent (titles, beds). |
| `--soil` | `#6B4A2E` | Garden bed / planter fill. |

**Per-package accent ramps** (each package picks ONE warm + ONE cool from the product
ramp; everything else stays neutral cream/ink so packages feel sibling, not unrelated):

- **Garden:** green `#639922` + pink `#D4537E`, amber `#BA7517` accents.
- **Italian food (La Cucina):** coral `#993C1D` + amber `#BA7517`, terracotta stage tint.

**Rules**
- Max ~3 hues per individual asset. Cozy = restrained.
- Gradients: allowed only as a *very* subtle 1-stop interior shade for form. No background
  gradients, no neon, no glows.
- Shadow: a single soft contact shadow under the object. One direction app-wide (light
  comes from upper-left — see the ambient sun in `GARDEN_V2.md`).

**Dark mode:** the app currently ships a fixed warm light theme. Assets are authored on
`--cream`; if/when a dark scene is added, the **stage** darkens (`--soil`-family) but the
collectibles keep their hues — only their contact shadow and outline lighten one step.

---

## 3. Collectible tiers (shared across every package)

Difficulty (`GridSize`) maps to a visual tier. The *metaphor* changes per package; the
*tier feel* (small/common → large/prized) stays constant.

| Tier | Grid size | Garden | Italian food | Feel |
|---|---|---|---|---|
| 1 — sprig | 5×5 | herb | pantry staple (garlic, basil) | small, common, quick |
| 2 — bloom | 6×6 | flower | ingredient (tomato, cheese) | the everyday reward |
| 3 — specimen | 7×7+ | tree / vine | finished dish (pasta, pizza) | large, prized, rarer |

A **set** is a themed group of tier-1/2/3 collectibles that completes into something bigger
(a bloomed bed, a served recipe). See `GARDEN_V2.md` §Sets.

---

## 4. Growth / state variants (required per collectible)

Because v2 collectibles change over time, **each collectible needs 3 state arts**, sharing
one silhouette so the transition reads as growth, not replacement:

1. `.seed` — just placed. Muted, small (sprout / raw ingredient / sketch outline).
2. `.growing` — interim. Partial color, ~70% scale.
3. `.complete` — bloomed / cooked / served. Full color, full size, optional sparkle-once.

Authoring tip: draw `.complete` first, then derive `.seed`/`.growing` by desaturating +
scaling + simplifying. Keeps the three locked to one silhouette cheaply.

**Wilting is NOT a fourth art variant.** The lapse/wilt look (see `GARDEN_V2.md` §Wilting) is a
*uniform runtime modifier* applied over whatever state art is showing — a slight droop/skew,
one desaturation step, a cooler tint. Author it once as an effect, never per collectible. It is
always reversible (it's presentation, not a state), so no "dead plant" art is ever needed.

---

## 5. Illustration types & where they appear

- **Spot (48–64pt):** the collectibles in the scene. The bulk of the art.
- **Stage furniture:** beds, planters, shelves, tables — the per-package container the
  spots sit in/on. One soft rounded form, `--soil` family.
- **Ambient (decorative, animated):** sun, drifting leaves, the wandering cat. See
  `GARDEN_V2.md` §Ambient. These convey life, never information.
- **Empty state / onboarding:** reuse existing cozy 🌱 voice; a single hero spot on cream.

---

## 6. Application rules

- Minimum render size **44pt**; silhouette must survive it. Test at 48pt before shipping.
- Snap to the scene's plot grid; never free-floating except ambient elements.
- One contact shadow, never a glow. No outer borders on the stage (matches the
  border-dropped cozy cell look from v1, commit 17f5d01).
- **Accessibility:** never encode meaning in art alone. Every collectible carries a text
  label + `accessibilityLabel` ("Lavender — bloomed"). State must be conveyed by label too,
  not only by color/scale.
- Animation: ambient loops are slow (≥4s), ease-in-out, and pausable via Reduce Motion.

---

## 7. Ship checklist (gate every new asset on this)

- [ ] Reads as its subject at 48pt
- [ ] Outline = `--ink`, not black; rounded caps/joins
- [ ] ≤3 hues, drawn from the package's chosen ramp + cream/ink
- [ ] Single soft contact shadow, light from upper-left
- [ ] Ships all 3 states (`.seed` / `.growing` / `.complete`) on one silhouette
- [ ] Sits cleanly on the `--cream` stage with no extra border
- [ ] Has a text label for accessibility
