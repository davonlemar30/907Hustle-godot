# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-08-21. Living doc — update as screens land._

## What this is
907Hustle ("One Good Run") is a mobile-first (375×812), dark-theme street sim
being rebuilt from a React web app into **Godot 4.7.2** Control-node scenes,
driven through the **Godot AI MCP** (dlight plugin; server at
`http://127.0.0.1:8000/mcp`, configured in `~/.claude.json`).

- **Godot project:** `/Users/damusthadon/Documents/907HustleGodot/907-hustle-godot/`
- **GitHub:** https://github.com/davonlemar30/907Hustle-godot (PUBLIC, branch `main`)
- **Web source (historical parity reference, read-only):** `/Users/damusthadon/Documents/907HustleGame/907Hustle-game/` — useful for migration history and legacy formulas, but newer approved ClickUp/Godot decisions win.

## Design system  (`ui/theme/hustle_theme.tres`)
- **Palette:** black `#070707`, panels `#111`/`#181818`/`#202020`, line `#333`, muted `#9b9b9b`, white `#f2f0eb`, red `#d32920`, red2 `#ff4a3d`, green `#73b867`, amber `#e1a63a`, cyan `#79bbc1`, clean `#5fa9d8`. Crew-power purple `#9e80d9` (added; not in web).
- **Fonts:** Anton (brand/headings), Barlow Condensed 400/600/700 (UI), Share Tech Mono (numbers). In `assets/fonts/` as woff2.
- **Type variations (Label):** Brand, BrandAccent, H1, CardTitle, Kicker, Muted, Mono, MonoBig, NavLabel. (v-spacing pass: CardTitle 14, H1 20, Muted 12; Card inner padding 13. Screen rhythm: Pad margins 14, Content sep 12 — an 8px-ish grid.)
- **Brand logo:** `assets/textures/grungelogo1trans.png` (distressed 907HUSTLE wordmark + "ONE GOOD RUN" tagline, transparent, 1448×1086). Wired into every screen's TopBar as a TextureRect (`custom_minimum_size.y = 92`, keep-aspect-centered) replacing the old two-line font brand. The `Brand`/`BrandAccent`/`Kicker` font variations are now only used elsewhere, not the header.
- **Type variations (PanelContainer):** Card, OpCard, TopBar, NavBar, Inset. **(Button):** BtnPrimary, BtnSecondary.
- **Gradients:** StyleBoxFlat can't gradient, so gradient panels/buttons use **SVG 9-slice "skins"** in `assets/skins/` inside StyleBoxTexture (vertical light→dark + border + rounded corners).
- **Atmosphere (reusable):** `ui/components/atmosphere.tscn` — a CanvasLayer(layer=50) with a full-rect ColorRect running `ui/theme/atmosphere.gdshader` (screen-reading canvas shader). Three passes, all uniforms: (1) **material** — tiles `assets/textures/tex-card.png` (mid-gray concrete) as a **bipolar detail-add** (`material_strength` 0.55, `material_contrast` 1.6, `material_tiles` (2.4,5.1)) so worn fiber reads on near-black cards where a soft-light blend would crush; (2) animated per-pixel **film grain**; (3) soft radial **vignette**. Changing `material_strength` re-textures every screen at once.
- **Textures** (`assets/textures/`, from the ClickUp "Godot UI Texture Kit" doc): `tex-card` ✅ wired (global material). `bg-hustle.png` ✅ wired as Hustle's full-screen backdrop (dark industrial wall, 941×1672, cover-crop behind the cards). NOT yet wired (available for later polish): `tex-grain` (procedural grain still used), `tex-vignette` (procedural still used), `tex-noise-fine` (came opaque, no alpha), `tex-panel_grunge_01` (transparent grunge), `tex-red-scrape` (alert/heat accents), `tex-frost-edges` (winter edge overlay). Instanced into every screen (`instance=ExtResource("atmo")`) — replaces the old frozen NoiseTexture/GradientTexture overlays. Base BG is hued near-black `Color(0.043,0.039,0.055)` (#0b0a0e), never pure black. **Content-anchored** atmosphere (Home only): a bottom-edge alpha `Fade` on the hero photo so it bleeds into the content (no hard box edge), and an additive `NeonGlow` radial (red, modulate a=0.22) upper-left echoing the Spenard Liquor sign.
- **Icons:** 37 monochrome **white** SVGs in `assets/icons/{nav,hud,products,ui}/`. Tint per-state with `modulate`/`self_modulate` (active nav = red2, idle = grey `#6b6b6b`). `coke` & `cocaine` share `icon-coke.svg`.

## Status

## Cleanup Batch: Post-FS-001.5 deck clearing (added 2026-08-21)

- Baseline was established before edits with Godot 4.7.2 headless import and the
  parity scene: **7,123 checks / 0 failures**. Glyph coverage also passed. The
  two checks above the brief's 7,121 baseline were already present on the
  FS-001.6 worktree changes.
- `scripts/parity/gen_fixtures.mjs` and the generated FS-001 fixture now pin
  oracle commit `a7d9534`.
- Crew and More now read `GameState.crew_capacity()`. The fixture harness also
  pins the displayed capacity to that function's return value.
- 907List now uses canon's seeded Fisher-Yates shuffle and slice. This fixes the
  tier-1 day-3 under-fill and changes board composition for future days in
  existing saves. This is not save corruption and does not change the save
  schema; a loaded save will simply see different future boards. Golden boards
  were re-pinned in `tests/parity/parity_runner.gd`.
- Exposure and Curtis persisted-data mutators now assert and no-op outside an
  active `GameManager.dispatch()` context. The wider `seeded_int_range` sweep
  found no other small-range loop-index call sites requiring this fix: boost,
  stickup, jobs, and 907List value rolls use event-specific keys.

## Codex Hardening + Fixes Batch 01 (added 2026-08-21)

### Standing Policy — Build 5e divergences

These are permanent rulings, not historical notes. Future implementations must
preserve them unless a newer approved ClickUp specification explicitly replaces
one.

1. **`job_interview` has a household-tier clean observation and no catastrophic
   tier.** The clean row is the only action-shaped household observation
   (`growth / hired_on`), and the action intentionally cannot catastrophically
   fail: the worst result is not being hired. This is the Build 5e oracle
   ruling; future tables must not add a catastrophic row or remove that clean
   household row.
2. **`escape` catastrophic rides `neighborhood`, not `network`.** A botched
   escape is a local spectacle — the block sees you run — rather than a
   systemic signal. The network channel is reserved for organized criminal
   activity. This is the Build 5e oracle ruling.
3. **The tier-3 organized-hit counter increments on success.** An attempt is
   not organized work until it succeeds; a blown job must not advance the
   counter. This is the Build 5e oracle ruling and remains the success-side
   contract.

### Build Process — Divergence Protocol

When the build brief conflicts with the oracle (web behavior) or an approved
specification:

1. STOP implementation of the conflicting item.
2. Document what the brief says, what the oracle says, and which wins and why.
3. Treat the oracle as behavioral authority unless a newer approved ClickUp
   specification explicitly overrides it.
4. Record the resolution in the Design Decisions Log as standing policy.
5. Continue implementation only after the resolution is recorded.

Build 5e precedent: `job_interview` keeps the clean household observation and
has no catastrophic tier; `escape` catastrophic uses `neighborhood`; and the
tier-3 organized-hit counter increments on success. In each case the oracle
wins.

### Day-cross settlement ordering contract

The approved gameplay ordering is:

```text
Jobs → Obligations → Stickup reset → Shark → Crew wages/departures →
Territory income/heat → Exposure queue/heat propagation → Curtis decay →
Market evolve → Phone restoration → Autosave/UI notification
```

This order is load-bearing. Crew settles before Territory, so a departing crew
member does not reduce that night's territory heat. Exposure settles after
Jobs/Obligations/Shark, so observations created during the same cross can be
delivered that night. Any future listener sees pre-evolution markets and the
pre-restoration phone state. FS-002.2 may replace this list with named phases;
until then, the ordering is the gameplay contract.

The post-PR #45 base already contains a Claude-owned `systems/day_lifecycle.gd`
ordering seam, but its current declared phases do not yet spell out the
sequence above. This batch does not edit that Claude-owned file (nor
`systems/time_system.gd`); the owner must reconcile the in-code header and
phase trace in the follow-up branch. This handoff entry is the design-level
record of the required change.

### Runtime and ownership notes

- The requested post-PR #45 base is `5efcb1599b4ec0891b6f95cc76805c5379bc6286`.
- GitHub had no pushed `codex/fs003-arrest-pressure-retaliation` branch when
  this batch began.
- The `godot` CLI is available at `/opt/homebrew/bin/godot` and reports
  `4.7.2.stable.official.ed1daf0bf`. After the isolated toast fix was merged as
  PR #48, the parity scene baseline is **10,439 checks / 0 failures**.
- The exact `godot --headless --script tests/parity/parity_runner.gd` form does
  not exit in this project; the authoritative runnable form is the scene:
  `godot --headless --path . --scene tests/parity/parity_runner.tscn`.

### 907List keyed-shuffle update

The existing 907List shuffle was tightened to the requested forward keyed
Fisher–Yates shape: each swap uses `seeded_int_range(seed, "%d:%s" % [index,
key], index, pool.size() - 1)`, with the varying index at the FRONT of the
FNV-1a key. This changes
future board composition for existing saves, but not save schema or persisted
state; boards are regenerated from seed + day. Golden boards and the
post-`used_tv` board were regenerated accordingly.

The wider sweep found no other `seeded_int_range` call that appends a loop index
while sampling a small range. The remaining calls are event-specific value
rolls (`boost`, `stickup`, `jobs`, and 907List realised values), not sequential
small-range sampling loops.

### Nested save-shape findings — follow-up validation

PR #46's diagnostic fixtures established that the v8 loader accepted malformed
inner records and exposed them to `GameState`. The follow-up branch maps the
requested structures to the actual Godot fields (`shark_loans`,
`phone_inbox`/`phone_held_inbox`, `list_holdings`, and the three consequence
containers) and repairs them on `load_run()` only.

Repair behavior is safe-default rather than reject: malformed containers become
empty containers; malformed rows are dropped; malformed known fields receive
typed defaults; and unknown keys survive. Repaired payloads are not autosaved,
so the original malformed file remains diagnosable. `save_nested_shapes.json`
now records `repaired_with_safe_defaults`, and
`tests/save_validation/save_validation_runner.tscn` covers all ten requested
structures plus the migrate → validate seam. The standalone suite passes **47
checks / 0 failures**. The existing parity runner's direct diagnostic probe is
left unchanged because `tests/parity/parity_runner.gd` is owned by Claude for
the concurrent build; the new load-time suite is the repair assertion.

The validator runs after migration and before apply; it does not write repaired
payloads back or change the schema. The v9 additions are validated in place:
`arrest_record.cooldown_until_day` is an integer deadline (minimum `-1`, where
`-1` means no active cooldown), and `consequence_flags` validates the boolean
`retaliation_first_expiry_seen` and integer `retaliation_last_ambient_day`
(minimum `-1`) when those optional keys are present. Unknown consequence flags
survive. A v8 record may omit the cooldown key and a v8 payload may omit
`consequence_flags`; migration/GameState defaults handle those absences without
materializing keys that would change legacy round-trip shape. FS-003.13 added no
new keys inside `active_consequence` or `consequence_queue`.

The extended standalone suite passes **61 checks / 0 failures**. Its three new
v9 guards were sabotage-proven: changing the cooldown fallback, removing the
retaliation flag type repair, or removing the ambient-day lower bound made the
suite fail. The merged main baseline after PR #50 and PR #51 is **10,781 checks
/ 0 failures**; the rebased save-validation branch matches it. Glyph coverage
passes across all five theme fonts, and `git diff --check` is clean.

Repair warnings identify each changed path in the runtime log. The exact
`godot --headless --script tests/parity/parity_runner.gd` form still does not
exit in this project; the passing parity result above came from the equivalent
headless parity scene.
**DONE — Home screen** (`ui/screens/home.tscn`), verified via run + screenshot:
TopBar (DAY/EVENING, two-tone 907HUSTLE brand, SPENARD/AK, CASH), 6-stat HUD
with icons, real Spenard street photo (`assets/img/assest1home.png`), red
TONIGHT'S OPERATION card + 3-button action bar, Market/Turf two-column
(product + soldier icons), People card (Yalonda portrait), Activity feed, and
the 5-tab bottom nav (HOME active). Grain + vignette overlay on top.

**DONE — Market screen** (`ui/screens/market.tscn`), verified via run + screenshot:
Same TopBar + 6-stat HUD chrome as Home, then a TRADING BOARD card with a
3-district segmented selector (SPENARD active / DOWNTOWN / INDUSTRIAL) + a
context strip (blurb + RISK/POLICE/RIVAL pip meters). Below, 8 product rows
(icon, name+role+owned, price, route-hint, BUY/SELL) — Meth shown LOCKED
("NEEDS INDUSTRIAL TURF"). Footer CARGO VALUE + PLAN A ROUTE. NavBar MARKET active.
**All prices are canon** (see next section).

**DONE — Hustle screen** (`ui/screens/hustle.tscn`), verified via run + screenshot:
the income hub ("HUSTLE / All your money, one place"). TopBar+HUD+atmosphere+nav
(HUSTLE active). Content: a green **TODAY'S TAKE** hero card ($312 + Jobs/Market/
Stick source chips), then the **six income-surface rows** the web `HustleScreen`
lists, each color-coded with canon status:
- **JOBS** (green, `icon-cash`) — Night Owl · Rank 1 · $55–75
- **907LIST** (blue, `icon-external`) — 2/4 held · Flipper tier
- **STREET MARKET** (amber, `icon-market`) — 12 sold  (row → `market.tscn`)
- **BOOST** (cyan, `icon-cargo`) — Tier 1 · fence Downtown
- **STICKUP** (red, `icon-warning`) — Tier 1 · 2 successes
- **SHARK** (purple, `icon-debt`) — 1 open · $250 out
Plus the **RIVAL PRESSURE** card (Curtis attention 4/8). Fits one screen (no scroll).
Real data from `src/data/{jobs,districts,market}.js`; each row is a stub that will
open its own sub-screen later (Jobs list/detail, 907List grid, Boost, Rob, Shark).

**DONE — GameState autoload** (`autoload/game_state.gd`, registered in project.godot):
the state spine. Plain canon data (DAY 14 snapshot from web v1.35) — run clock, player
stats, `districts[]` (risk/police/rival/travel/accent), `spenard_venues[]`, contacts —
plus `district_by_id()`/`current_district()` helpers. Static now; the reducer port
(Phase 3) makes it mutate and every reader updates for free.

**DONE — Street screen** (`ui/screens/street.tscn` + `street.gd`), verified via run:
the exploration hub — STREET title, **3 district cards** (Spenard/Downtown/Industrial
with travel method + RISK/POLICE/RIVAL pips), **AROUND SPENARD** venues (North Star
Garage/Night Owl/Spenard Gym/The Nile), People contacts row. STREET active in nav.
**First live GameState consumer:** `street.gd._ready()` fills the top bar, HUD, district
cards (name+accent+pips computed via `_pips()`), venues, and contact count from the
autoload — no hardcoded game values in the screen. GDScript gotchas learned:
- Don't name a helper `_set(` — it collides with `Object._set(StringName,Variant)`.
- Reference the autoload as `get_node("/root/GameState")` (runtime), not the compile-time
  global `GameState`, so the script compiles before the editor reloads the autoload list.
  (Registered the autoload live via `autoload_manage(op=add)`.)

**DONE — UX pass 2** (`/ux-designer` follow-ups, verified via run):
- **Touch targets** — Market BUY/SELL bumped 42×26 → **48×44** (WCAG/HIG 44px floor).
- **Mini territory map** — Home Turf & Crew now has a 6×2 block grid (`.../Turf/V/Map`,
  12 ColorRects) with the 3 held blocks lit red in a stepped diagonal, matching the concept.
- Repo now has a root **`README.md`** (front-door doc; `HANDOFF.md` stays the deep log).

**DONE — GameState retrofit (Phase 2 chrome)**, verified via run:
`ui/screens/screen_base.gd` (extends Control) fills the shared chrome — top bar
(day/part/location/cash) + 6-stat HUD — from GameState in `_ready()`. **All four
screens now read the chrome from GameState**, none hardcode `$847`/`DAY 14`:
- Home/Market/Hustle attach `screen_base.gd` directly (`script = ExtResource("scr")`).
- `street.gd` now `extends "res://ui/screens/screen_base.gd"`, calls `super()` for the
  chrome, then adds its district/venue/people fills. Shared helpers (`_set_text`,
  `_pips`, `_commas`) live in the base.
Proven by temporarily setting GameState cash=1337/day=21 → all screens showed it, then
reverted to canon. NOTE: screen-specific content (market prices, Today's Take, activity
feed, turf counts) is still baked in the .tscn — extend GameState + bind those next.

**DONE — Market content binding**, verified via run + live eval:
`GameState.products` (8 canon products: name/role/color/price/hint/locked) added.
`ui/screens/market.gd` (extends `screen_base`) fills all 8 rows — icon tint, name+color,
role/owned, route hint, price — from `GameState.products` in `_ready()`. Proven by
mutating a product's price in the running instance → the row updated. The locked-row
(meth) hint wraps its label as `Hint/T`, handled in `_fill_products`.

**DONE — Home content binding + reactive architecture**, verified via run + live eval:
`screen_base.gd` now wires the reducer pattern — `_ready()` connects `refresh()` to
`GameState.state_changed` and calls it once; `refresh()` = `_fill_chrome()` + a
`_bind_content()` hook each screen overrides. **One `GameState.notify_changed()`
re-renders the whole screen** (no per-field signal wiring). `market.gd`/`street.gd`
moved to `_bind_content()`. `home.gd._bind_all()` binds every Home card from GameState:
Tonight's Operation (`active_operation`), Market Snapshot (`home_snapshot` → `products`),
Turf & Crew (`held_blocks`→count/mini-map/list, `soldiers`→count/pips, `eli_report`),
Activity Feed (`activity_log`), People (`pending_messages`). New GameState fields added
for all of these + `notify_changed()`/`product_by_id()`. Home snapshot now shows CANON
prices ($27/$176/$105), not the old placeholders. Proven: one eval mutating cash +
products[0].price + held_blocks + soldiers, then `notify_changed()`, updated header +
snapshot + mini-map + list in a single pass. (People portrait stays the static Yalonda
texture — per-npc portrait swap needs a portrait lookup, later.)

**DONE — Hustle content binding → Phase 2 complete for all existing screens.**
`ui/screens/hustle.gd` (extends `screen_base`, `_bind_content()`) fills Today's Take
(`todays_take` + `income_sources` chips), the 6 income surfaces (`hustle_surfaces` —
label/desc/status/detail + accent color kept as the existing per-row color), and the
Curtis card (`curtis_attention`/`_max`). The scene's placeholder value strings were
blanked (grep-clean). Proven: one eval (take=500, surface[0].status, curtis=7) +
`notify_changed()` updated Take + Jobs + Curtis in a single pass; other rows unchanged.
NOTE: per-surface colors kept the current design values (the build prompt's illustrative
hex would have recolored rows — skipped to honor "no visual change"). income_sources use
the prompt's split (jobs 180 / market 87 / stick 45).

**All four screens (Home, Market, Street, Hustle) are now fully GameState-driven** — one
`notify_changed()` re-renders the visible screen. Phase 2 (State Spine) done for existing
screens; Phase 3 is the reducer/logic port.

**DONE — Phase 3a: reducer foundation + Market transactions** (verified via run + eval):
- `autoload/rng_manager.gd` (RngManager) — FNV-1a `string_hash` ported from web `src/hash.js`,
  **golden-parity verified against 10 JS values (all match)**. `seeded_random(seed,ctx)`,
  `seeded_int_range()`. No `randf()/randi()` anywhere else (enforced).
- `autoload/game_manager.gd` (GameManager) — `dispatch(action, payload)` routes to registered
  systems; exactly one `GameState.notify_changed()` per success; `action_failed(action,reason)`
  signal on failure. UI never mutates GameState directly.
- `systems/economy.gd` — `market_buy`/`market_sell` (price×qty vs cash + inventory, cargo cap 10)
  + `market_evolve` (seeded ±20% walk off `base`, clamped min/max, keyed `market_evolve_day{d}_{id}`
  → deterministic). Simplified vs full web trade (no spread/plug/avgCost yet — 3b).
- `systems/time_system.gd` — MORNING→AFTERNOON→EVENING→NIGHT→(cross)→MORNING; each advance evolves
  the market; day-cross bumps `day` + emits `day_crossed`.
- `market.gd` — BUY/SELL buttons dispatch through GameManager; `action_failed` flashes the cash label.
- GameState: `inventory` (numeric, source of truth) + `cargo_used()`, `cargo_max=10`, `run_seed`,
  `time_slot`/`time_slots_today`, `day_crossed`; products gained `base/min/max`; pills owned 12→3
  (cargo-consistent). `bg-market.png` wired as the Market backdrop.
- **Verified:** buy weed→cash−27/cargo+1; buy at cap→rejected, state unchanged; sell→restored;
  broke buy→rejected; advance NIGHT→day-cross day 15 MORNING; evolve deterministic (same day→same price).
- NOTE: market_evolve is the prompt's simplified ±20% model, not the web's xorshift+reversion walk —
  exact market-walk parity is a Phase 5 harness goal. The `string_hash` primitive IS bit-exact.

**Open / next:** Phase 3b (Jobs / 907List / Stick / Boost / Shark reducers), 3c (Crew/Territory),
3d (Events/Exposure/Curtis); Phone → More screens; the Hustle sub-screens. Also:
1. Build **Crew**, **Travel**, **People** screens; wire remaining portraits.
2. Refresh Home's MARKET SNAPSHOT card to canon prices (currently placeholder:
   WEED $28/METH $61/PILLS $17 — real Spenard anchors are $27/$176/$105).
3. Extract shared TopBar+HUD+NavBar into a reusable component before data-wiring
   (currently duplicated inline in home.tscn and market.tscn).
4. Real 907HUSTLE logo (build in-engine from Anton + grunge) and Travel
   location photos (Spenard, Industrial — Downtown exists as downtownassest1.png).

## Market pricing canon (web v1.35.0, `src/data/{products,locations}.js`)
Drug price per district = `product.base × district.bias` (daily walk reverts to
this anchor, clamped to [min×0.72, max×1.2] — see `marketPrice` in game-core.js).
Bias only defined for weed/shrooms/cocaine/meth; all others 1.0 (flat citywide).
Anchors used on the Market screen (Spenard / Downtown / Industrial):
weed 27/37/38 · shrooms 72/108/97 · pills 105 flat · lean 155 flat ·
molly 215 flat · coke 290 flat · cocaine 296/423/383 · meth 176/200/300.
Access gates: weed+shrooms open · pills/lean/coke/molly need plug ·
cocaine needs supplier (Pherris / Downtown turf) · meth needs Industrial turf.
Heat per product: weed 0, shrooms 0, pills/lean/coke/molly/cocaine 1, meth 2.
NOTE: web source local checkout is now on `main` @ v1.35.0 (was 82 commits behind
on an old `codex/v1-11` branch — re-`git pull` origin/main before pulling data).

## Bottom nav — CANONICAL (web `ui.jsx:197`)
`NAV = [street, hustle, home, phone, more]` — **HOME is the raised center button**
(red circle FAB, `SB_fab` stylebox, sits above the bar via a `HomeFab` overlay
anchored bottom-center of the root). Side tabs: STREET · HUSTLE | (home) | PHONE · MORE.
**There is no top-level MARKET/CREW/TRAVEL/PEOPLE tab.** In the web IA:
- **Street** = exploration: district travel, local venues, encounters, robberies, People.
- **Hustle** = income hub, incl. the **Street Market** (drug trading). The market is a
  *sub-page of Hustle* once `hustle.visible` (true mid-game) — reached via the Hustle
  hub's "STREET MARKET" row — so **`market.tscn` shows HUSTLE active**, not STREET. (Web
  only shows it on Street in the *early* game before Hustle unlocks.) Also 907List flips + jobs.
- **Phone** = texts/contacts/bills (People & relationships live here).
- **More** = settings/status/menu (turf/crew likely surface here or on Home).
Icons (real art, wired in all four nav scenes): Street→`nav/icon-street.webp` (walking
figure), Hustle→`nav/icon-hustle.webp` (running figure), Phone→`nav/icon-phone.webp`
(handset). Home→`icon-home`, More→`icon-menu` unchanged.

## Canon (verified in web source — use for content, not guesses)
- **Primary travel areas:** Spenard, Downtown, **Industrial Service Roads**.
  (Midtown / U-Med / Mountain View are minor ambient only.)
- **8 products:** weed, meth, pills, coke, cocaine, molly, shrooms, lean.
- **Character bios live in ClickUp** (ClickUp MCP is connected). **Pull a
  character's bio before generating/using their portrait.** e.g. Yalonda
  Hernandez = Dominican (Villa Mella → NY → Anchorage), raises son Juan (18,
  warehouse dock) alone; Eli Ward = organizer w/ a second phone; Curtis = boss.
- Portrait priority: Yalonda, Juan, Goodie, Tasha, Malik, Eli, Pherris, Tone,
  Deshawn, Curtis, then Cal, Nia. See `assets/PROMPT_GUIDE.md` for the
  generation spines (portrait 85mm vs environment 35mm) and `ASSET_MANIFEST.md`
  for the full asset list.

## Web build / phone testing  (added 2026-08-20)

Live build, rebuilt on every push to `main`:
**https://davonlemar30.github.io/907Hustle-godot/**

- Workflow: `.github/workflows/web-deploy.yml`, builds in the `barichello/godot-ci:4.7.2`
  container, deploys via `actions/deploy-pages`. Pages source is set to **GitHub Actions**
  (not branch), so do not switch it back to branch/root or the deploy stops publishing.
- Preset: `export_presets.cfg`, one `Web` preset. **`variant/thread_support=false`** is the
  load-bearing setting — threads would require `SharedArrayBuffer`, which requires COOP/COEP
  headers, which GitHub Pages cannot send. Leave it off. (If it ever must be on, turn on
  `progressive_web_app/enabled` for the service-worker workaround.)
- Web export requires the **Compatibility** renderer. The project already uses
  `gl_compatibility` — earlier notes calling this the "mobile renderer" were wrong.
- The build strips the `godot_ai` autoload and addon (`sed` on `project.godot` plus an
  `exclude_filter`). Its autoload opens a WebSocket to the local MCP server, which does not
  exist in a browser.
- PRs build but do not deploy (`if: github.ref == 'refs/heads/main'`).
- Measured payload: `index.wasm` 38MB raw / **~9.8MB gzipped** (Pages gzips on the fly),
  `index.pck` 3.2MB. ~13MB total on first load, cached after.
- Verified: loads and renders correctly in a 375×812 mobile viewport, console clean,
  single-threaded WebGL 2.0. Touch input was *not* verified through automation (the tooling
  could not drive Godot's canvas) — check taps on a real device.

## Assets: the 750px / WebP rule  (added 2026-08-20)

`assets/` went **64MB → 2.5MB (-96%)**. Run `scripts/optimize_assets.py` after adding art.

- Cap is **750px wide** — 2x the 375pt viewport, and nothing renders wider than the screen.
  Nav icons cap at 128px lossless. Source art was arriving at 1254px+ (one 2.1MB portrait
  fed a 52pt avatar).
- **Shrinking source files alone does nothing to the shipped build.** Godot re-encodes every
  texture on import; the default `compress/mode=0` (Lossless) turned 2.5MB of WebP back into
  a 12MB `.pck`. The script pins `compress/mode=1` at quality 0.9 on `.webp.import` files —
  that is the setting that governs download size. SVGs stay lossless (lossy blurs edges).
- Renaming `.png` → `.webp` invalidates the `uid` in `.tscn` files. The script strips the
  stale `uid` and leaves `path=`; Godot re-resolves by path and re-adds a uid on next save.
- The script is idempotent — re-running skips anything already within budget.
- **Nav icons must be white-on-alpha, not black-on-white.** The bar tints them with
  `self_modulate`, which multiplies — so the glyph has to live in the alpha channel with
  white RGB, or it renders as a square (opaque background) or a black smudge (dark RGB).
  `scripts/icon_to_mask.py in.webp out.webp` does the conversion: it sniffs the background
  from the corners, derives alpha from luminance, repaints RGB white, and rescales the glyph
  to ~80% of the canvas so it matches the hand-authored SVG icons optically.
- Lossless rules now carry through to import. `enforce_import_settings` used to pin
  `compress/mode=1` on *every* `.webp.import`; it now honours the `RULES` lossless flag, so
  `assets/icons/**` imports lossless. Lossy rings around hard edges, and on an icon's alpha
  that reads as a halo once the nav bar tints it.

## Known issues (not yet fixed)

_None recorded._

## Missing font glyphs — fixed, and now guarded  (2026-08-20)

**Eight** characters were being drawn by fonts that cannot draw them, not the four first
recorded. Re-checked with `Font.has_char()` across all five font files (Anton, Barlow
Condensed 400/600/700, Share Tech Mono); the whole Geometric Shapes and Arrows blocks are
absent from every one of them:

| | | was | now |
|---|---|---|---|
| U+2197 | north-east arrow | `LIVE UPDATE ↗`, market hints | `icon-external` / `icon-arrow-up` |
| U+25B2 | up triangle | market trend hints | `icon-arrow-up` |
| U+26A0 | warning | `⚠ RIVAL PRESSURE` | `icon-warning` |
| U+265B | chess queen | `♛ TURF & CREW` | `icon-crew` |
| U+265F | chess pawn | `♟ PEOPLE` | `icon-people` |
| U+25CE | bullseye | `◎ TONIGHT'S OPERATION` | `icon-target` |
| U+25CF / U+25CB | filled / hollow circle | **every RISK/POLICE/RIVAL meter** | `icon-pip` dots |

The two circles were the widest miss: 12 meters across Street and Market, plus every meter
`screen_base.gd` generated at runtime. They are `TextureRect` dots now (`_set_pips()`), lit
with the meter's accent or dimmed to `PIP_DIM`.

Still safe, and deliberately left as text — present in all five fonts: `·` `–` `—` `•` `›`.

**Why the editor can never catch this:** macOS lends the editor a system font for any glyph
the theme fonts lack, so the character looks perfect locally. The web export has no system
font to borrow and draws a tofu box. An editor screenshot is not evidence.

So `scripts/check_glyph_coverage.py` reads the fonts' cmap tables and fails on any shipped
character outside them; CI runs it as its own job on every push and PR. It skips comments,
and intersects the fonts rather than unioning them — a string can be styled with any type
variation, so a character is only safe if all five can draw it.

- Trend arrows moved out of `GameState.products[].hint` into a `trend` field ("up"/"flat")
  so the string stays plain text and the arrow is an icon the row shows or hides.
- Adding a fallback font to the theme was the alternative. Not taken: the project already
  owned a matching SVG for every glyph but the meter dots, and a fallback font would have
  put another file in the `.pck` to draw seven characters.

## App flow: Title → Name Entry → Home  (added 2026-08-20)

`main_scene` is `title.tscn`. The chain is Title → Name Entry → Home, then the bottom nav
moves between the four game screens.

- **`ScreenManager`** (`autoload/screen_manager.gd`) is the only thing that swaps screens.
  Screens call `nav.go_to(path)`, never `change_scene_to_file()` directly. The change is
  deferred: a nav button is mid-signal when it calls, and freeing the scene that owns that
  button inside its own handler crashes.
- **Title and Name Entry do NOT extend `screen_base.gd`.** They have no chrome, no HUD and
  no nav. Nav visibility therefore needs no logic — those scenes just have no NavBar.
- **The nav bar is now real.** Each cell is a flat `Button` (48px, clearing the 44px tap
  floor) wrapping a full-rect `VBoxContainer` with `mouse_filter = 2` that holds the old
  Ind/Ico/L. The raised HOME FAB has a transparent `HomeBtn` over it. Connections are made
  once in `screen_base.gd::_wire_nav()` from `_ready()` — never `_bind_content()`, which
  re-runs on every state change.
- **Every nav cell has a screen** as of Phase 5b part 3. The empty-route branch
  in `_wire_nav()` stays: a cell added ahead of its screen must be inert, never
  a failed load.
- **New-run state is canon.** `GameState.reset_to_new_game()` mirrors the web reducer's
  START_RUN branch: `$100`, heat 0, health 100, debt 0, Spenard, Day 1 MORNING. Not the
  CHOOSE_BACKGROUND branch ($375 + a $620 note from Dre, `run.premise = legacy_established`)
  — that is a different opening this build has no screen for. `sanitize_street_name()` is a
  port of `sanitizeStreetName` (`game-core.js:83-86`), 16-char cap, and an empty result
  blocks the run exactly as canon does.
- **CONTINUE RUN and the LAST RUN line are live** (Phase 4), gated on `title.gd::_has_save()`,
  which now reads `SaveSystem.inspect()`. See the Phase 4 section for the whole flow.

## Touch input on mobile — there was never a bug  (2026-08-20)

Recorded because it cost real time and looks like a bug from the outside.

The report was "nothing responds to taps on the phone." The actual cause: **Home has no
functional controls at all.** `home.gd`, `hustle.gd` and `street.gd` contain zero
`connect()` calls; only `market.gd` wires anything (buy/sell). The app booted onto Home, and
the nav that would have reached Market had no Buttons in it. Nothing was tappable, so
nothing responded.

Touch itself was fine, and was proven so before any fix was attempted: dispatching a
synthetic touch-drag at the deployed canvas scrolled Godot's ScrollContainer. Canvas
geometry was already correct too (375x812 CSS against 750x1624 render at DPR 2), and
Godot's own shell already ships `touch-action: none` on `<body>` plus a correct viewport
meta. **Check whether a control is actually connected before suspecting the web layer.**

The one genuine weakness found: `touch-action` does not inherit, so the canvas computed to
`auto`. `html/head_include` now pins `#canvas{touch-action:none}`. That is hardening, not
the fix.

## Phase 3b: interactive screens  (added 2026-08-20)

Every screen responds now. Home, Street and Hustle had zero connected controls
before this.

- **`make_tappable(path, handler)`** in `screen_base.gd` is how a card becomes
  tappable. The cards are `PanelContainer`s, which size every child to the panel
  rect and take their minimum size from the largest child — so a flat `Button`
  added as a second child covers the card exactly, adds nothing to its height, and
  draws last. **Do not** reach for `gui_input` on the card instead: Buttons already
  coexist with drag-scrolling inside the `ScrollContainer` (Market's BUY/SELL prove
  it), and a card consuming `InputEventMouseButton` would fight the scroll.
- **`systems/travel.gd`** handles the `travel` action: flat **$5** fare plus one
  slot, in either direction. That is canon — `TRAVEL` and `BUS_TRAVEL` both spend
  `access.cashCost` and log `" for $5" : " on your pass"` (`game-core.js:8718-8760`),
  and both run through `advanceRun`, which costs a slot. Rejection uses canon's own
  string, "Need $5 fare." Not modelled: transit passes (`transitCovered`), `WALK_HOME`
  (no fare, two slots, 3 health), Downtown arrival events.
- **`ScreenManager.show_toast(text)`** — one `ui/components/toast.tscn` lives under
  `/root` for the session, so a message survives a screen change instead of being
  freed mid-fade. Layer 100 (above atmosphere's 50); every node in it is
  `mouse_filter = IGNORE` so a toast can never eat a tap.
- **`districts[]` no longer carries `here` or a baked `travel` string.** Both went
  stale the moment travel worked. `GameState.travel_label_for(id)` derives the label.
- **`economy.evolve()` now keys on day + slot + product.** Keyed on day alone, every
  advance within a day produced identical prices — the market only moved at
  midnight. Canon keys its own rolls the same way (`${seed}:meetup:${day}:${slot}:${nonce}`,
  `game-core.js:3128`). Still the simplified ±VARIANCE model; parity is Phase 5.

## Mobile virtual keyboard — Godot already ships the fix  (2026-08-20)

The LineEdit did not raise the keyboard on mobile. No custom HTML shell and no
hidden-`<input>` workaround were needed: **Godot already implements exactly that**,
and the preset had it switched off.

`html/experimental_virtual_keyboard` becomes `experimentalVK` in the engine config
(`platform/web/export/export_plugin.cpp`). In the engine JS, `GodotDisplayVK` creates
a hidden `<input>` and `<textarea>`, inserts them before the canvas, and pipes their
`input` events into the LineEdit. Its availability guard is:

```js
available: function(){ return GodotConfig.virtual_keyboard && "ontouchstart" in window }
```

So enabling it cannot affect desktop — the `ontouchstart` half of that guard is
false there. The preset now sets it to `true`. Godot's `LineEdit` calls
`virtual_keyboard_show()` on focus by itself, so no GDScript change was required.

**The preset was written by hand, and defaults copied into it are decisions.** This
one sat as `false` for two builds because it looked like boilerplate.

## Phase 3c: jobs + obligations  (added 2026-08-20)

The run now has expenses. Rent and the phone bill arrive on their own clocks,
jobs are the way to cover them, and failing to is the first way to lose.

**Canon differed from the brief on almost every number.** Verified against
`src/data/jobs.js` and `game-core.js`; the oracle won each time:

| | brief said | canon says |
| --- | --- | --- |
| job list | North Star Garage, Gym, Night Owl, Day Labor | the nine in `src/data/jobs.js` — North Star Garage is the player's base, the Gym a training venue, neither is a job |
| pay | flat rate | a `[min,max]` band, scaled by rank then by approach |
| firing | 2 misses | **3 CONSECUTIVE** days; working resets the ladder |
| rent | $75 / 7 days, auto-deduct | **$150** / 7 days, paid deliberately; a due day that passes is a miss |
| phone | $25 / 5 days, auto-deduct | **$75**, due day 7, past-due counter, line dies after 2 days grace |
| game over | 3 missed rents | 3 household **warnings**; 2 missed rent weeks earn one |

- **`systems/jobs.gd`** — `apply_job`, `work_shift`, `quit_job`, plus an
  attendance settle on `day_crossed`. Pay is seeded on day+slot+job, so a run
  replays identically. `shift_blocker()` is public: the Jobs screen asks it for
  the button label so the label and the dispatch rejection can never disagree.
- **`systems/obligations.gd`** — `pay_rent`, `pay_phone_bill`, plus rent and
  phone settlement on `day_crossed`.
- **Settlement is scoped to the day that just ENDED**, not the one starting.
  Canon gates it behind a `dayEndPending` step for exactly this reason: a bill
  due on day 7 has to be payable *during* day 7. Comparing against `gs.day`
  marks it missed the instant the day begins. `jobs.gd` does the same with
  `ended_day`.
- **`ui/screens/jobs.tscn`** was generated from `hustle.tscn` with the content
  nodes stripped, so the chrome (top bar, HUD, nav, FAB, atmosphere) is
  inherited verbatim rather than re-authored. The board and current-job card are
  built in `jobs.gd` from GameState — the board's length depends on what has been
  discovered, so it cannot be laid out in the scene.
- **`ui/screens/game_over.tscn`** is standalone (no chrome), like the title.
  `screen_base.refresh()` routes to it from one place, so whichever screen is
  open when the third warning lands is the one that leaves.
- **Job discovery**: canon seeds a Week Zero shuffle over `STARTER_JOB_IDS`.
  Here the four starters plus day labour are known from Day 1; `night_owl`,
  `juan_warehouse` and `ship_creek` exist in the data but are not discoverable
  yet, and applying to them is correctly refused.

Not ported, each its own feature: coworkers and their relationships, shift
dialogue, `learn_job` workplace details, Deshawn's rent grace, contraband and
danger-brought-home as warning sources, Exposure broadcasts, Dre's lending.

## Scrolling: nothing inside the scroll may be MOUSE_FILTER_STOP  (2026-08-20)

**Found in playtesting: the screen only scrolled when the finger landed on bare
background.** Touch a card and the screen was stuck.

`make_tappable()` covered each card with a full-size flat Button at
`MOUSE_FILTER_STOP`. A STOP control swallows the press, so the ScrollContainer
never sees the gesture start — and since the cards tile most of every screen,
almost nowhere was draggable. Measured on Home: content 853px in a 580px
viewport, with `Tap` Buttons of 145×179, 134×179 and 313×65 sitting over it.

The Phase 3b PR justified that Button with "Buttons already coexist with
drag-scrolling inside the ScrollContainer — Market's BUY/SELL prove it".
**That was wrong at the scale it was applied.** Market's buttons are small, so
there was always background left to drag from; a full-card Button leaves none.

### The rule

Anything inside `Shell/Scroll` that responds to touch must be
**`MOUSE_FILTER_PASS`** and use `screen_base.tap_connect()`. Never `pressed`, and
never STOP.

PASS lets the control handle the event *and* lets it continue up to the
ScrollContainer. Because the gesture still reaches the control on release, a
plain `pressed` connection would fire at the end of every scroll drag — so
`tap_connect` measures it: a release more than `TAP_SLOP` (12px) from where the
finger landed was a scroll, not a tap, and the handler does not run.

Verified: 2px travel fires the handler, 160px travel does not, card taps still
navigate.

### Where the exceptions are, and why they are fine

`title.gd`, `name_entry.gd` and `game_over.gd` use `pressed` because those
screens have no ScrollContainer at all. The bottom nav uses `pressed` because
`Shell/NavBar` is a sibling of `Shell/Scroll`, not inside it. **Check whether a
control is inside the scroll before choosing.**

## PROCESS: documentation ships with the PR  (adopted 2026-08-20)

**Standing rule. Not a suggestion.**

1. The relevant ClickUp doc section is updated **in the same session as the PR**,
   before merge — Current Godot Build State, Design Decisions Log, and the Migration
   Status block where the phase moves.
2. A `HANDOFF.md` entry ships **inside the PR**, not after.
3. A PR that introduces a new system carries its doc update in the same commit range.
4. **No retro-documentation passes.**

Phases 3c-3f were written up retroactively and this rule exists to stop that repeating.
Retro-documentation loses the reasoning that was live at the time — the near-miss, the
alternative that was discarded and why, the exact reason a number is what it is — and
that reasoning is most of the value. The Build State page can be reconstructed from
`git log`; the Decisions Log cannot.

### What "documented" means for a new system

- The file header names what was ported, from which canon source, and **what was not**.
- Any term pinned at a canon neutral is named, with the system that will unpin it.
- Any deliberate divergence from canon is named with the reason.
- Any canon oddity found is recorded rather than silently corrected.

## Hardening pass 01: save isolation + presentation purity  (added 2026-08-21)

Independent review branch `codex/godot-hardening-pass-01`, based on `main` at
`c5e88af` (PR #35). No Claude branch was present locally or remotely, so the
pass stayed narrow in state/save/presentation plumbing.

- **Legacy loads no longer inherit the live run.** `SaveSystem._apply()` now
  starts from a fresh `GameState` template and overlays the saved fields. A v1
  save missing markets rebuilds its own deterministic opening board instead of
  retaining whichever board was in memory; v2-v4 additive fields likewise use
  their declared defaults.
- **Autosaves replace atomically.** The complete payload is written and flushed
  to `907hustle_run.save.tmp`, then renamed over the final path. An interrupted
  write no longer truncates the last valid run first.
- **Recovery's persistent latch settles before autosave.** The More screen is a
  pure reader again. `GameManager` reconciles the latch before `state_changed`,
  and load reconciles legacy saves before exposing them to screens.
- **Exposure reads are pure.** Asking for an empty ledger, disposition, or the
  People summary no longer inserts persistent empty arrays into `GameState`.
- **Malformed top-level saves fail closed.** Invalid version and required-field
  types are refused without applying partial state.

Save schema remains **v5**: no persisted field or existing payload shape changed.
Parity is **6641 checks / 0 failures** (13 hardening regressions added), glyph
coverage passes, and headless import/startup remain clean. Full findings and the
system map are in `HARDENING_PASS_01.md`.

## FS-003.13: the loop stops being monotone  (added 2026-08-22)

A balance pass, not a redesign. Every system in the consequence layer worked;
FS-003.12's long-run simulations said what they *felt* like, which was one note
held for a month. District Pressure saturated on day three and stayed there.
Arrests landed on activity rather than on aggression — fifteen in twenty-nine
days for the aggressive profile, with no gap between booking periods. Financial
Pressure never fired for two of three profiles. And the retaliation queue's only
counterplay, leaving the district, was invisible: eleven threats across three
profiles, zero avoided, because nothing ever suggested there was anything to
avoid.

**Parity: 10,439 → 10,611 checks, 0 failures. Save schema v8 → v9.**

### The harness came first, deliberately

The three inherited profiles each committed to ONE response for a whole run and
none of them ever travelled, which measures the consequence layer against a
player who does not exist. Tuning against that would have been tuning against an
artefact. Two profiles were added before a single constant moved:

- **mixed strategy** answers a Caught by reading `choice_summaries()` and taking
  the highest projected success chance — the same number the screen shows, read
  the same way, so a drift between projection and outcome would move the SIM
  too instead of hiding behind it.
- **travelling** rotates Spenard → Downtown → Industrial every four days, works
  district-appropriate targets, and pays the fare and the slot each time.

Both print a `simulation-metrics:` JSON line alongside the prose, which is what
the before/after table below is built from rather than re-read out of paragraphs.

### What moved

| Constant | Was | Now | Why |
| --- | --- | --- | --- |
| `PRESSURE_QUIET_GRACE_DAYS` | 1 | 0 | Laying off a district should show the next morning, not the one after |
| `PRESSURE_QUIET_RECOVERY` | 1.0 | 1.5 | Three quiet days should clear a band, not three points of nine |
| `PRESSURE_ACCELERATED_RECOVERY` | — | 2.0 at HOT | The band you most need a way out of was the hardest to leave |
| `STICK_FAILURE_ARREST_HEAT` | 10 / 8 / 6 | 12 / 10 / 8 | The gate was authored before Pressure existed; the working Heat band moved up under it |
| `ARREST_COOLDOWN_DAYS` | — | 2 | The same precinct does not pick you up on the way out of its own parking lot |
| `FINANCIAL_PRESSURE_FREE_DIRTY` | $400 | $200 | A transaction had to move >$450 of street money to register one point |
| `FINANCIAL_PRESSURE_PER_DOLLAR` | 0.01 | 0.015 | Against a decay of 1/day, the old rate could not out-climb its own decay |
| `FINANCIAL_PRESSURE_FOLD_AT` | 6 | 4 | Reachable from two bails in a week, which is the authored scenario |

### The post-arrest cooldown, and why it needed no field of its own

Counted from the day the booking **committed**, not from release. Release time
varies with the lane the player chose, so tying the cooldown to it would quietly
reward SERVE IT over posting bail with extra immunity — a balance decision
nobody made, hiding inside a fiction.

It is stamped on `arrest_record.cooldown_until_day`, beside `last_arrest_day`
and behind the same receipt. `arrest_record` is already persisted whole, so the
cooldown survives a save with no manifest entry and no migration arm, and a
pre-FS-003.13 save comes back with the key simply absent —
`ArrestSystem.cooldown_until_day()` reads that as -1, which is the correct
history for arrests that predate the mechanic. Arming a cooldown from
`last_arrest_day` during migration would have been worse than doing nothing: it
would suppress arrests on a loaded run for a booking the mechanic did not exist
during.

Both source systems apply it **after** their own authored gate, never inside it.
That order is the point: the gate keeps answering "were you already hot when you
tried this", and the cooldown answers the separate question of whether the same
precinct is picking you up two days running. A cooldown folded into the gate's
own table would have made the gate's tests depend on the arrest record.

### PX-003 §8's ambient signals

The activity feed carries at most one line a day while a threat is queued in the
district the player is standing in, starting the day after it was scheduled. The
line is chosen by seeded RNG keyed on `(queue_id, day)`, so a reload shows the
same feed rather than rerolling the atmosphere.

Hiding the window is **structural**, not careful. Nothing in
`push_ambient_warnings` reads `trigger_day` or `expires_end_day` for anything
except deciding whether a row is still live; the copy never varies with how much
time is left; and the parity suite audits every authored line for digits, timing
words and the actor's name. A warning that intensified as the window closed
would be a countdown with adjectives.

The first time a run ever avoids a threat into expiry, the Phone carries a
one-time callback. Once per RUN rather than once per threat: it exists to teach
that leaving works, and a lesson repeated every time it applies stops being a
lesson. The flag lives in `consequence_flags`, which is the one field v9 adds —
a Dictionary rather than a field per flag, so the next one-shot callback is a key
rather than a schema decision.

`day_lifecycle.gd` gained a third `DAY_START_ORDER` step, `retaliation_ambient`,
appended after `surface_delayed`. Nothing above it moved. It runs LAST for the
same reason expiry runs first: a threat that already expired must not whisper,
and one that just walked through the door in person is not something the feed
then hints at.

### The check floor was documentation, and now it is a check

`MIN_CHECKS` has carried a careful paragraph per slice since FS-003.1 and
**nothing has ever read it**. A suite that lost half its checks to an aborted
section would still have printed PASS — precisely the failure the constant was
written to catch. `_finish()` now compares against it. Sabotaging the floor to
20,000 fails one check, which is the whole proof.

The floor also explains the 10,439 in the parity line above: the Codex hardening
batch (PR #46) carried the suite from 10,211 to 10,439 without moving `MIN_CHECKS`.
The new floor is 10,600 and covers both.

### Before and after

Five profiles, same seeds, same days, run before and after the constants moved.
Bold is the value that changed.

| Profile | Days | Arrests | Booking slots | Worst-family HOT days | FP days at fold | Threats queued | Avoided into expiry | Ambient warnings |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| frequent crime, fights everything | 29 | 15 → **8** | 58 → **30** | 19 | 0 → **3** | 4 → **10** | 0 | 0 → **11** |
| frequent crime, yields everything | 29 | 12 → **8** | 50 → **30** | 19 | 4 → **8** | 8 → **9** | 0 | 0 → **8** |
| cautious, crime every third day | 26 | 5 → **4** | 19 → **15** | 0 | 0 | 1 | 0 | 0 → **1** |
| mixed strategy, plays the odds | 29 | 13 → **8** | 52 → **36** | 14 → **16** | 0 | 3 → **7** | 0 | 0 → **9** |
| travelling, rotates districts | 29 | 12 → **8** | 50 → **34** | 13 → **11** | 0 → **6** | 2 → **4** | 1 → **2** | 0 → **6** |

### Two acceptance targets the tuning brief set that this build does not hit

Both are reported rather than papered over, and both have the same root: the
brief's Task 2 and Task 3 targets were measured in isolation and they interact.

**The aggressive profile still spends 19 of 29 days at HOT (target: ≤12).** With
Task 2 alone it dropped to 12; Task 3 put it back to 19, and the reason is worth
stating plainly because it is a design finding rather than a tuning miss.
Pressure only recovers on a QUIET day — a day the family took no gain — and the
aggressive profile boosts twice and robs once in the same district *every single
day*. It has no quiet days at all. The ones it used to have were days it spent
in booking. **Before this build, District Pressure's counterplay was being
delivered by jail time rather than by player choice**, and cutting arrests in
half removed it.

That is the mechanic working as designed, against a profile that never lets up.
The counterplay it was meant to have is visible in the profiles that use it: the
travelling profile went 13 → 11 worst-family HOT days and holds Downtown and
Industrial at QUIET/KNOWN throughout, and the cautious profile never reaches HOT
at all. A player who works one block three times a day for a month *should* be
permanently recognisable there. Filed as a follow-up — the honest lever is on the
gain side (`PRESSURE_BOOST_SUCCESS`, `PRESSURE_BY_TIER`) or a per-family daily
gain cap like the one Market already has, and neither is in this brief's scope.

**The cautious profile lands at 4 arrests over 26 days (target: ≤3).** Down from
5. The cooldown barely bites a profile that only commits crime every third day —
an arrest on day 3 covers days 3–5, and day 6 is exposed again. The dominant
arrest source for that profile is not the Stick Heat gate this build raised: it
is Boost's `RUN_FAILURE_ARREST_TIER`, which arrests *unconditionally* on a failed
Run at tier 3 regardless of Heat. That constant is not one of the levers the
brief named. Filed as a follow-up.

### A stated inconsistency in the brief, resolved toward the constants

FS-003.13's Task 4 asks for `FINANCIAL_PRESSURE_FREE_DIRTY` = $200 and also says
"Rent ($150) paid from dirty should contribute". Those cannot both be true: $150
is under a $200 free band. The numbered constants are the tuning decision and the
acceptance criteria agree with them ("routine small dirty spends under $200 still
produce zero pressure"), so the constants won and a check pins the rent case
explicitly — a week's rent in street money is deliberately quiet. If the intent
was for rent to register, the free band wants to be $100, and that is a decision
rather than a fix.

### Sabotage results

Every new constant and both new behaviours, reverted one at a time against the
full suite:

| Sabotage | Result |
| --- | --- |
| `PRESSURE_QUIET_RECOVERY` back to 1.0 | RED — 14 failures |
| `PRESSURE_QUIET_GRACE_DAYS` back to 1 | RED — 14 failures |
| `PRESSURE_ACCELERATED_RECOVERY` down to 1.5 | RED — 8 failures |
| `STICK_FAILURE_ARREST_HEAT` back to 10/8/6 | RED — 3 failures |
| `arrest_suppressed()` never suppresses | RED — 9 failures |
| Stick gate ignores the cooldown | RED — 2 failures |
| Boost gate ignores the cooldown | RED — 1 failure |
| Booking commit never stamps the deadline | RED — 4 failures |
| `FINANCIAL_PRESSURE_FREE_DIRTY` back to $400 | RED — 8 failures |
| `FINANCIAL_PRESSURE_PER_DOLLAR` back to 0.01 | RED — 8 failures |
| `FINANCIAL_PRESSURE_FOLD_AT` back to 6 | RED — 4 failures |
| Ambient warning never writes to the feed | RED — 2 failures |
| Ambient warning ignores the district gate | RED — 2 failures |
| Ambient warning ignores row status | RED — 3 failures |
| First-expiry flag never set | RED — 3 failures |
| `consequence_flags` dropped from `PERSIST_FIELDS` | RED — 2 failures, total drops by 1 |
| `retaliation_ambient` dropped from `DAY_START_ORDER` | RED — 5 failures |
| `MIN_CHECKS` raised to 20,000 | RED — 1 failure (the floor itself) |
## FS-001.9 + .10: the delegation starts talking back, and FS-001 closes  (added 2026-08-22)

Pherris's day worked and said almost nothing. The player could learn she runs the
board only by opening the 907List screen and reading a panel; they found out how
her day went by noticing the cash total had moved. FS-001.9 gives the feature a
voice. FS-001.10 is the milestone's exit gate.

**Parity: 10,439 → 10,609 checks, 0 failures on the branch. Save schema stays v8.**

> **Merge note, written after the fact.** This landed minutes after FS-003.13
> (PR #50), so both figures above are true of this build measured alone and
> neither describes `main`. On `main` the suite runs **10,781** checks —
> 10,439 + 172 from .13 + 170 from here, which is the arithmetic saying neither
> merge lost anything — and the schema is **v9**, because .13 bumped it. This
> build needed no bump and still does not: its callback flags nest inside
> `crew_operation_state`.
>
> Both builds also wired `MIN_CHECKS` in independently and both set it to 10600
> from their own branch's count, which left the floor 181 short once they were
> both in. Corrected to 10770 in a follow-up.

### FS-001.9 — four callbacks, no new machinery

Every line goes out through a channel that already exists: `phone.push_message()`
for anything she says, `GameState.activity_log` for anything the day records.
There is no notification system and no tutorial layer.

*   **Discovery.** One Phone message the first time she is capable of it, keyed on
    its own `discovery_notified` flag rather than on the `discovered` latch. That
    separation is the point: a save written before this build can already carry a
    discovered operation and has never seen the text, and keying the message on
    its own flag means that run gets the offer once instead of never.
*   **Assignment.** The activity line reports what she actually picked up and what
    it cost — logged AFTER `select()` rather than before, since neither number
    exists until she has shopped. Three shapes: a budget the player set, a spend
    they left open, and a board with nothing on it.
*   **Settlement.** One Phone message per night, never per item, inside
    `day_ending` so the clock still reads the day it is reporting on. **Four
    cases, not the three the brief names.** Sold at a profit, sold thin, bought
    nothing — and bought stock that has not turned over, which is reachable
    because discovery is one-way: a player who reached Broker and fell back to
    Flipper can still assign her (the assignment requirements never mention the
    tier) into a one-day sell delay. "Nothing worth touching, kept your money
    where it is" would be a lie about money that has already left the wallet.
*   **Loyalty.** One complaint per EPISODE, not per run. The flag clears the
    moment she recovers, so a second slump months later is heard again — the
    difference between a character with a mood and a tutorial that fires once.

The two texts are evaluated in `reconcile()` rather than hung off the events that
cause them. Loyalty is written by four different paths (wages, proofs, decay,
dismissal); hooking each would put the same two `if`s in four files and would
still miss the fifth.

Home's operation card and Hustle's 907List row read two new `operation_summary()`
fields — `active_today` and `last_night` — and work nothing out for themselves.
The card sits **below** rent and **below** the shift, because both of those have
a deadline attached and this does not, and **above** the scripted
`active_operation` copy, which is UI scaffold nothing writes. So delegation only
ever displaces a placeholder, never a fact.

Callback flags nest inside `crew_operation_state`, already persisted under v8.
**No schema bump.**

### FS-001.10 — the exit gate

*   **Migration chain.** A v5 payload walked all the way to current in one test,
    rather than four arms each proven in isolation: the v6 arm rebuilds today's
    consumption record from the holdings it can see, the v7 arm stamps ownership
    while it is still unambiguous, the v8 arm splits the wallet clean. Then it is
    **loaded**, because a migrator returning a dictionary and `apply()` producing
    a playable run are two different claims. A qualifying legacy run discovers on
    load and is offered the operation exactly once.
*   **Deterministic replay, two ways.** Same seed, same board, same morning →
    identical selection, spend, stop reason, gross, profit and end cash. And the
    stronger version: the same morning **replayed from a save** settles
    identically. Two fresh setups make the same calls in the same order, so
    anything merely call-order-dependent still agrees; a reload does not.
*   **One dispatch, one refresh.** Measured on `assign_crew_operation`, which
    claims the day, buys through the wallet, consumes listings, logs the feed line
    and reconciles callbacks inside a single action. A refused claim refreshes
    nothing at all.
*   **Ordering.** Crew settles before territory; her settlement runs on
    `day_ending` while the clock still reads the ending day, which is what lets
    her report on it. If it ran after the increment, `last_night` would be off by
    one forever — a bug that looks like a rendering glitch.
*   **UI regression at 375×812.** Every delegation screen built, bound and
    measured. Nothing declares a width past the phone.

### The economy simulation: thirty days, delegated and not

The question is not whether delegation makes money — she buys under value and
sells at it. It is whether delegation makes personal play pointless. Two runs,
same seed, same board, same thirty days, wages paid every morning they could be
afforded:

| Metric | Delegated every morning | Never delegated |
| --- | --- | --- |
| End cash | 1898 | 100 |
| Cash delta | -602 | -2400 |
| Delegated cycles | 60 | 0 |
| Her gross | 6768 | 0 |
| Her profit | 2878 | 0 |
| Wages paid | 3480 | 2400 |
| Wages still owed | 120 | 1200 |
| Loyalty at day 30 | 10 | 2 |
| Player slots spent | 120 | 120 |
| Locked capital (holdings) | 0 | 0 |
| Player flips | 0 | 0 |
| Player 907List tier | 3 | 3 |
| Player Intelligence | 1 | 1 |
| Exposure rows added | 13 | 2 |
| Curtis delta | 0 | 0 |
| Missed obligations | 0 | 0 |

**Delegation does not pay for itself at rank 2.** Sixty cycles produced $2,878 of
profit against $3,480 of wages actually paid. Employing her and using her is
$1,798 better than employing her and not using her — but it is still $602 of cash
down over thirty days, and the reason to keep her is the sixty cycles of
*throughput* the player never spent a slot on rather than the margin. Filed as a
follow-up; this gate does not retune.

**Personal play is not obsolete, and the leakage rules are why.** Sixty delegated
cycles produced zero flips, zero Intelligence and zero tier progress, identical to
the run that never delegated. Every point of Broker standing is still earned by
hand. And her sales are as visible as the player's would be — thirteen Exposure
rows against two — so delegation is not a way to launder visibility either.

The solo run ends broke ($100) with $1,200 of wages outstanding and her loyalty
down to 2, which is the honest shape of employing somebody and giving them nothing
to do.

### Three sabotages that passed, and what each one bought

*   **A settlement template whose `profit > 0` could not be falsified.** Every
    night the suite drove was profitable, so flipping it to `>= 0` changed nothing
    observable. Fixed by driving a night that breaks EXACTLY even — a $100 buy
    against a `true_value` band of [100, 100] — because zero is the only place the
    two templates differ and "cleared $0 after what I paid" is a sentence nobody
    would write on purpose.
*   **A branch nothing reached.** The bought-but-unsold case needed a Flipper-tier
    sell delay, which the suite never constructed. Fixed by discovering at Broker
    and dropping the tier before assigning — which is also the proof that the
    branch is reachable in play rather than defensive.
*   **An `active_today` guard whose `settled` clause was never the deciding
    term.** Four `advance_time` dispatches cross the day, so `assigned_today` goes
    false on its own. Fixed by emitting `day_ending` directly, which is the real
    state the lifecycle produces between PRE_SETTLE and INCREMENT.

### Two sabotages that stayed green on purpose

**The re-settle guard is redundant, deliberately.** Removing the coordinator's
`if settled: continue` leaves the suite green, and so does removing the adapter's
`if settled and result != null: return result`. Removing **both** goes red on four
checks. That is defence in depth on a double-payment path, and it is worth
recording that each guard alone is sufficient — so a future reader who deletes one
as dead code has this note rather than a green suite as their evidence.

### A finding the gate turned up, filed rather than fixed

Sabotaging `realised_value`'s key with an unseeded component stayed green, and the
reason is not a hole in the checks. `RngManager.seeded_random` is FNV-1a over
`seed + ":" + context`, normalised by dividing the 32-bit hash by 2^32 — so it
reads the HIGH bits, and FNV-1a's high bits barely move when a small counter is
appended to the tail. Measured directly:

```
seeded_int_range(seed, "…:3:%d" % i, 42, 58) for i in 0..7  ->  49 49 48 49 49 49 49 49
seeded_int_range(seed, "k%d" % i, 0, 1000)   for i in 0..7  -> 443 439 451 447 459 455 467 463
```

Eight distinct keys, eight nearly identical rolls. `seeded_shuffle` already knows
this and documents it — it puts the varying index at the FRONT of the key for
exactly this reason — but nothing has ever audited the other call sites. The
907List value key is the clearest instance: `"907list:value:%s:%d"` varies the day
at the tail, so the same item bought on consecutive days is worth nearly the same.
The bands are narrow enough that the effect is small, and the hash is
oracle-locked to the web build, so this is a key-composition audit rather than a
hash change. Filed.

## FS-003.12: the integration gate, and what FS-003 leaves behind  (added 2026-08-22)

The milestone gate. Everything above proves one slice; this proves they are one
LAYER — that TI-003 §23's named scenarios run end to end, that every save path
arrives somewhere coherent, and that thirty days of heavy criminal activity move
the market stream exactly as far as thirty quiet days do.

**Parity: 10,044 → 10,211 checks, 0 failures. Save schema stays v8.**

### The schema did not need to move, and that is worth stating

FS-003.8 through .11 persist an arrest record with charge history, District
Pressure ledgers with their daily market caps, a bleed queue, a delayed
retaliation queue, booking quotes and arrest warnings — and **not one of them
needed a new field.** Everything rides in structures FS-003.4 allocated: the
booking block and the arrest warnings live inside `active_consequence`, which is
persisted whole.

A version bump with no new field is a migration arm nobody can test, so the
schema stayed at v8 and the suite now asserts both halves: that `SAVE_VERSION`
is 8, and that every field these four slices depend on is in `PERSIST_FIELDS`.
The second assertion is the one with teeth — dropping `district_pressure` from
the manifest fails three checks and drops the total by 38.

### Two verification bugs the gate found in its own tests

Both are the same species as FS-003.8's provenance hole, and both are worth
recording because neither was in the product.

**`str(capture())` is not a state digest.** A freshly-built state carries its
Dictionary keys in insertion order; one reconstructed from the save file carries
them in the order the JSON parser produced, which is sorted. The two are
byte-for-byte different and semantically identical — so the first version of the
stage round-trip matrix reported *every* stage as a mismatch, on states that were
in fact perfect. `_canonical()` sorts recursively and normalises whole-valued
floats, which is what makes the comparison mean "the same facts" rather than "the
same typing order".

**A round trip cannot be compared against an unreconciled wallet.** The setups
reach their stages through `_frozen_ready`, which sets `gs.cash` directly — one
of TI-003 §6's named test exceptions. `SaveSystem` reconciles on load, so an
unreconciled save comes back reconciled and the digest reports a difference that
is really the harness's own shortcut. The matrix now reconciles first and asserts
`cash == clean + dirty` before capturing, so both sides are states the game can
actually be in.

### The market non-drift check, and why it is sampled by day

TI-003 §21's headline claim is that TI-003 adds zero market-stream draws. The
check is two runs from one seed to day 39. One does nothing but sleep. The other
lifts, robs Goodie's stash, gets caught, answers, gets booked, serves time, and
takes the retaliation that robbery scheduled.

Sampled **by day**, not by dispatch count — the only comparison that means
anything, because a booking advances several slots at once and the two runs reach
day 39 after very different numbers of calls. What must be equal is the number of
nightly evolves, and that is one per day either way.

Result: **30 days compared, 0 cursor mismatches, 0 board mismatches.**

Two things had to be equalised for the comparison to be about the stream rather
than about survival. Rent and the phone bill are pushed out of range in both arms
— the loud arm is the one that spends slots inside bookings, so it is the one
that would reach eviction first, and comparing a thirty-day run against a
nineteen-day one proves nothing. And neither arm buys or sells product: market
transactions consume availability, which the nightly walk reads.

### Simulation findings

Three seeded profiles, reported rather than asserted. FS-003.12's brief is
explicit that balance findings become follow-up tasks rather than in-flight
fixes, so the only assertions here are invariants that would be bugs at any
balance: the wallet balances, Pressure stays inside 0–9, Heat inside 0–15,
Financial Pressure inside 0–10, priors never outrun arrests, and every reload
checkpoint matches.

| Profile | Days | Arrests | Booking slots | Retaliation queued / surfaced | FP days ≥6 |
| --- | --- | --- | --- | --- | --- |
| Frequent crime, fights everything | 29 | 15 | 58 | 4 / 3 | 0 |
| Frequent crime, yields everything | 29 | 12 | 50 | 8 / 4 | 4 |
| Cautious, crime every third day | 26 | 5 | 19 | 1 / 1 | 0 |

Pressure band distribution, home district, aggressive profile:

    north_star_lot/boost   QUIET 1 · KNOWN 5 · WATCHED 2 · HOT 19
    north_star_lot/stick   QUIET 4 · KNOWN 7 · WATCHED 4 · HOT 12

**Four findings, filed rather than fixed:**

1. **Arrest frequency.** A player committing crime every slot is arrested roughly
   every other day and spends 58 of 29 days' worth of slots in booking. That may
   be the intended cost of that playstyle; it is worth a designer looking at,
   because it is close to the point where the arrest loop *is* the game.
2. **Pressure saturates and stays saturated.** The home district sits at HOT for
   19 of 29 days on the aggressive profile. Recovery is −1/day after a grace day,
   and a single messy outcome is +1.0 — so any player working one district daily
   outruns the decay permanently. The bands function; whether the top one should
   be that easy to live in is a balance question.
3. **The Financial Pressure fold almost never fires.** Zero days at the fold
   threshold on two of three profiles. Bail is the main high-visibility spend in
   these runs and most quotes are under the $400 free band, so the dirty portion
   rarely clears it. The mechanic is correct and currently near-dormant.
4. **Retaliation never expires when the player does not travel.** Expired count
   is 0 across all three profiles, because none of them leaves the district. That
   is the mechanic working — avoidance is the counterplay — but it means the
   *avoidance* path gets no exercise in an ordinary aggressive run.

`game over` in two profiles is eviction and is a property of the PROFILE rather
than of the consequence layer: none of them ever works a shift or pays rent.

### Sabotage results

| # | Injected fault | Result |
| --- | --- | --- |
| 1 | A consequence roll draws from the market stream | **caught** — 1 failure |
| 2 | v7 saves migrate cash to Dirty (canon's rule, not TI-003's) | **caught** — 6 failures |
| 3 | `district_pressure` dropped from `PERSIST_FIELDS` | **caught** — 3 failures, and the total fell by 38 |

Sabotage 1 exposed a gap in the drift check itself and was fixed rather than
noted: the loud arm was robbing `washgo_regular`, which has no retaliation row,
so the 30-day comparison never exercised the schedule roll at all. It robs
Goodie's stash now, which schedules at 1.00 — so the arm covers the delayed path
as well as Caught and Booking, and the check asserts it reached both.

### The full TI-003 picture

**Ownership, as shipped.** `GameManager` is the mutation boundary. `GameState`
owns persisted facts. `ConsequenceEngine` owns the active chain, Cause receipts,
the delayed queue and District Pressure. `ArrestSystem` owns booking quotes and
the arrest record. `RetaliationSystem` owns the delayed path. `WalletSystem` and
`HeatSystem` own every runtime Cash and Heat write, enforced by an audit that
scans the source. `DayLifecycle` owns the ordered rollover. `OutcomeResolver`
remains the tier authority and the odds projection. Source systems own their own
state, tables and observations — and nothing else.

**Known weaknesses, named.**

- The Boost/Stickup surfaces still show a raw percentage for the ACTION's own
  odds, while the consequence screen shows bands. Two vocabularies for the same
  kind of number. FS-003.11 changed only what the brief scoped; unifying them is
  a design call, not an implementation one.
- The simulator answers chains with a fixed policy, so the metrics describe three
  specific playstyles rather than a distribution. A profile that picks responses
  by the odds it is shown would measure something closer to real play.
- The retaliation `:injury` RNG key TI-003 reserves is unused, because §16 gives
  Health as a flat number rather than a band. If a later pass makes it a band,
  the key is already named.
- District Pressure and Global Heat now BOTH scale by district — Pressure through
  the difficulty penalty, Heat through the §7 multiplier table. They are separate
  systems with separate storage, but a player experiences them as one "this
  district is worse" and may not be able to tell them apart.

**Migration path from a pre-TI-003 save.** A v7 save loads. Its aggregate cash
enters Clean (TI-003 §20, a deliberate divergence from canon, which classifies
its own pre-split saves Dirty). Every consequence structure defaults empty, and
empty is the only true answer — a v7 save cannot hold an unfinished consequence,
because none of these systems existed while it was being played. Nothing is
inferred and no active chain is created.

## FS-003.11: numbers underneath, situations on top  (added 2026-08-22)

The consequence layer becomes a player experience. The engine could already
hold a chain across a reload; what it could not do was explain itself.

**Parity: 9,905 → 10,044 checks, 0 failures.**

### The suite builds screens now

This is the first section that instantiates real scenes against real state and
reads back what they rendered. It matters because TI-003 §19 and PX-003 §11 are
a list of values that must NOT reach the player, and a screen is exactly where
one of them leaks. A rule enforced only in a system is a rule the presentation
layer has never been asked about.

The audit is blunt on purpose: **no Label on the consequence screen may contain
a `%` character.** Nothing legitimate on that screen does, and a percent sign is
precisely what a well-meaning edit reintroduces — showing the number is easier
than choosing a word for it.

Two mechanical things had to be right before any of that worked, and both are
worth writing down:

**`queue_free()` is wrong in this harness.** The runner does its whole job inside
one `_ready()` and never yields a frame, so a queued node is never actually
freed — and every instantiated screen stays connected to
`GameState.state_changed` while it waits. Twenty leaked screens later, every
dispatch in every section *below* re-renders all of them. The suite went from
ninety seconds to not finishing at all. `free()` disconnects on the spot.
`_free_screen()` is that, and the pre-existing `people.tscn` instantiation was
leaking the same way and now goes through it too.

**A screen that is not the current scene must not change scenes.** The
consequence screen routes away when its chain clears, which is the fix for a real
dead end (see below) and a catastrophe inside a harness that instantiates it
alongside twenty others. `_is_live()` — `get_tree().current_scene == self` — is
the guard.

### The dead end this slice removes

Before it, pressing CONTINUE cleared the chain and left the player on the
consequence screen rendering "The moment has passed." — with no bottom
navigation, because that is the whole point of the scene. `screen_base.refresh()`
routes TO a blocking screen and has never had a reason to route away from one.

`consequence.gd` now overrides `refresh()` and leaves for the chain's own
`return_route`, so a blown Boost puts the player back on Boost rather than
generically at Home. Losing your place is a small cost the game had no reason to
charge.

The scene also lost its `HomeFab` — a red circular HOME control, wired to
nothing, sitting on a screen the player cannot leave. It looked like the way out
and was not one.

### Odds became words, which is a divergence from PX-003

FS-003.11's brief: *"Use qualitative labels derived from exact probability. Do
NOT show raw percentages. The numbers exist underneath; the player reads
situations."* Verification checklist item 9 repeats it, and the acceptance
criteria repeat it again.

**PX-003 §4 and §19 point 6 say the opposite**, sketching `[chance]%` on the
response cards and arguing from the existing Boost and Stickup surfaces, which
do show percentages.

Implemented per the build brief — qualitative bands — and recorded here and in
the design log rather than silently chosen. Three reasons it is the better
reading even setting authority aside: the brief is the later and more specific
instruction; PX-003's own §11 already keeps "raw probability percentages" on the
hidden list, so the document is not internally consistent; and the odds shown on
a consequence card are a projection through advantage and catastrophe immunity,
which is a genuinely different kind of number from the flat chance a Boost target
displays. Precision the player cannot act on is not information, it is noise
with a decimal point.

The bands are uneven, deliberately. The gap between 70% and 60% changes what a
player does; the gap between 20% and 10% does not — both are "this is going to
hurt". So the top of the range is described more finely than the bottom.

### Arrest warnings are derived, never restated

PX-003 §19 point 8: a player must not discover a booking gate after choosing Run.
So each response carries a risk CODE, snapshotted with its odds when the decision
opens, and the scene turns codes into copy.

`caught_arrest_risk()` derives the code from the authored effect table rather
than duplicating it, so a balance edit to `CAUGHT_EFFECTS` moves the warning with
it. A warning kept in sync by hand would eventually tell the player the wrong
thing, which is worse than telling them nothing.

Run gets two different warnings because its failure row is the one conditional
one, and the player deserves to know **which** condition made it true: "this
target" is something they chose and can choose differently, "your Heat" is
something they carry. Both are surfaced without the threshold — `HIGH HEAT: A
FAILED RUN CAN BOOK YOU`, never `above 6`.

### The Market strip was never bound at all

Binding Local Attention onto the Market context strip turned up a hole in
non-negotiable rule 4 ("no hardcoded game values in .tscn files"): the blurb and
all three pip meters were editor previews baked into the scene, so they showed
**Spenard's** numbers wherever the player actually was. Nothing bound them.

They bind now. The first meter reads the Market family's Pressure band rather
than the district's static risk — FS-003.11 asks for exactly that swap, and
Pressure is the one of the three the player's own behaviour moves. Four dots
carrying a 0-to-3 band cannot leak a 0-to-9 score, which is part of why pips are
the right control for it.

### Sabotage results

| # | Injected fault | Result |
| --- | --- | --- |
| 1 | Odds render as `62%` again | **caught** — 3 failures |
| 2 | Arrest risk dropped from the projection | **caught** — 2 failures |
| 3 | Run/failure blames Heat when the target is the cause | **caught** — 2 failures |
| 4 | A HOME button added to the blocking scene | **caught** — 5 failures |
| 5 | KNOWN odds band swallows RISKY | **caught** — 4 failures |

Sabotage 2 is worth a note on process rather than on the code: the first attempt
targeted the wrong file, the anchor did not match, and the run came back green.
A green run after a sabotage that never applied looks identical to a sabotage
that was not caught. The injector now asserts its anchor exists and fails loudly,
which is why the second attempt found the two failures it should have.

### Art and audio the consequence screen does not have

Required by PX-003 but not blocking, using placeholder tints and labels today:

| Asset | Where | What is used instead |
| --- | --- | --- |
| Consequence background plate | Blocking scene backdrop | `bg-street.webp`, shared with Hustle |
| Per-tier opponent portraits (Clerk, Store Security, Armed Guard) | Decision stage | Text only |
| Retaliation actor art | Retaliation decision stage | The actor's label |
| Booking / procedural iconography | Booking and release stages | Theme `Kicker` text |
| Impact audio for a committed choice | On commit | Silent |
| Band icons for QUIET/KNOWN/WATCHED/HOT | Boost, Stickup, Market | Coloured text label |

None of them is load-bearing: PX-003 §16 requires colour to travel with text and
it does, so every one of these is additive rather than a gap in comprehension.

### What FS-003.12 inherits

A suite that can build a screen and read it back, which is what a hidden-
information audit needs. And an interaction surface where every action is 46px
and every terminal stage has exactly one control — both now asserted rather than
inspected.

## FS-003.10: the one consequence that waits  (added 2026-08-22)

`systems/retaliation.gd`. Everything else in the consequence layer happens inside
the dispatch that caused it. This is the one thing that does not: you rob a
register on Tuesday, and on Thursday the people who own it find you standing in
the same district.

**Parity: 9,637 → 9,905 checks, 0 failures.**

### It is a system, not an adapter on Stick

Stick creates the debt; it does not collect it. By the time a retaliation
surfaces the robbery is two days gone, and what resolves it is a completely
different table from the one that resolved the robbery. Hanging it off
`stickup.gd` would put two unrelated encounters in one file and make Stick the
owner of a queue it never reads.

It registers through the same runtime source-adapter registry Boost uses.
"Source adapter" there really means *whoever resolves this chain*, and a delayed
consequence resolves itself — the chain's `action_id` is `"retaliation"`, which
the registry turns back into a system on every boot including after a load.

### Presence is the design, and it needed a second activation point

TI-003 §15 gates activation on four things, all of which live on the engine
because "may this surface" is a question about the queue: the blocking slot is
free (regression #27), the daily allowance is unspent (#28), the row is inside
its window, and **the player is standing in the district** (#29).

TI-003 §9 puts activation in the day-start lifecycle, and that alone would have
made the presence rule almost decorative. `current_district_id` persists across
days, so a day-start-only check catches exactly one player: the one who *slept*
in the threatened district. Somebody who works Spenard every afternoon and ends
each day at home would never meet anybody, and "avoid the district" would quietly
degrade to "avoid sleeping in the district".

So activation is asked at two moments — the declared day-start step, and after a
completed travel. The engine still owns every gate; travel only asks the question
again now that the answer can have changed. Named here because it is an addition
to §9's list rather than something it says.

### DAY_START became a declared list too

`DAY_START_ORDER = [expire_retaliation, surface_delayed]`, run inside
`run_night_transition` rather than registered as a `day_start_hook`. Two reasons:
the hooks are somebody else's extension point and the ordering tests assert they
ship empty, and `clear_hooks()` must not be able to remove the game.

Expiry runs before activation, which is not arbitrary — a row that ran out
overnight has to be gone before anything asks what is eligible, or the day's one
delayed slot could be spent on an encounter that had already expired.

### Scheduling happens before the arrest gate, not instead of it

A catastrophic hit on Goodie's stash both schedules at 1.00 *and* books at every
tier, so one robbery produces both halves. The row is queued when the robbery
resolves and cleared when the booking commits (TI-003 §13 step 7).

Skipping the schedule on an arrest would have been simpler and is wrong: it would
make the queue depend on a decision the player has not made yet. A save taken
between the robbery and the booking choice legitimately carries a row that is
about to be cleared, because the arrest has not happened yet.

### Cash reads the Dirty bucket, and that is the split finally doing something

TI-003 §16 and regression #39. They take what you took. The loss is computed
against the live dirty balance — a player who spent the take between the robbery
and the reckoning genuinely has less to lose — and it is bounded by that balance
before it reaches the wallet, so Clean is unreachable by arithmetic as well as by
policy.

The test that matters most is the empty one: a player holding $5,000 of wage
money and nothing dirty loses **nothing**. Until this slice, the provenance split
was information the wallet kept for later. This is the first thing in the build
that reads it to decide something a player can feel.

### `source_time_owed()` had to learn about zero

A delayed consequence owes no source slot: the robbery paid its slot two days
ago, which satisfies TI-003 §26's "one source action pays its normal time cost
once". But `source_time_owed()` was `not settled`, so a chain carrying zero slots
still answered "owed" — and the booking projection would have told the player
they were about to lose time they were not.

It now reads `remaining > 0 and not settled`, and `_continue` stamps the settled
flag either way so a zero-slot chain closes the same way a one-slot chain does.

### Values authored here rather than found in the spec

TI-003 §15 gives schedule chances by target and names only Goodie's `actor_id`.
The other three are derived from the target — `till_crew_spenard`,
`till_crew_downtown`, `dice_crew` — with labels to match. Deriving them from the
target is what makes "the same crew cannot come twice for the same night" true
without a lookup table nobody maintains.

TI-003's key list reserves `retaliation:<cause>:<actor>:<choice>:injury`, but §16
gives Health as one flat number per row rather than a band. **Nothing rolls for
damage**, and that key is deliberately unused: rolling a band the design does not
have would be inventing a value.

### Sabotage results

| # | Injected fault | Result |
| --- | --- | --- |
| 1 | Plain Failure becomes a qualifying tier | **caught** — 5 failures |
| 2 | District gate removed from `eligible_queued` | **caught** — 7 failures |
| 3 | Cash loss spends `HIGH_VISIBILITY_CLEAN_FIRST` | **caught** — 14 failures |
| 4 | Trigger delay 2 → 1 day | **caught** — 3 failures |
| 5 | Daily delayed cap never claimed | **caught** — 2 failures |
| 6 | Arrest stops suppressing same-Cause rows | **caught** — 3 failures |
| 7 | Yield removed from the deterministic list | **caught** — 3 failures |
| 8 | Street crew gains a Talk lane | **caught** — 4 failures |

### What FS-003.11 inherits

Three chain kinds that all reach the same scene, and the two projections it will
render: `choice_summaries()` already carries `deterministic`, `has_odds` and a
persisted `disabled`, and `local_attention_summary()` is waiting for the Boost
and Stickup status cards. The consequence screen currently prints raw
percentages, which is what .11 replaces.

## FS-003.9: the city starts recognising the routine  (added 2026-08-22)

Two systems that share a slice because they share a rollover. District Pressure
is local memory of a criminal pattern; Financial Pressure is what happens when
street money moves through a formal bill. Neither is a number the player ever
sees, which is exactly why both needed testing at the level of what they do.

**Parity: 9,440 → 9,637 checks, 0 failures.**

### Pressure lives on the engine, not on the sources

TI-003 §8 puts it there and the reason is structural rather than tidy: a Boost, a
Stick and a Market sale all write into the same district ledger under different
families, and the score a lift reads back may have been raised by a robbery two
days ago. No single source system can own a number every other source writes to.
So `boost.gd`'s FS-003.7 ledger write is now a two-line forward to
`engine.add_pressure()`, and the bleed those gains schedule is the engine's
business.

### Three rules that are easy to state and easy to get subtly wrong

**Bleed carries the new gain, never the stored score.** FS-003 §6: "Bleed uses
the new gain from the cause. The entire stored score never copies outward
again." Bleeding the score compounds — Spenard's 4 puts 2 into Downtown, whose 2
puts 1 back into Spenard the day after, forever. So a bled gain is applied to the
destination row directly rather than through `add_pressure()`, which is what
stops it scheduling a bleed of its own. It still resets the destination's quiet
count, because §6 names a bled gain alongside a direct one.

**The first full quiet day holds.** Regression #18 is "First quiet day decays
Pressure early", an off-by-one nobody would ever notice in play — the score just
falls a day sooner than designed, permanently. The recovery test walks the ramp
night by night rather than sampling the end: gain on day 9, hold on 10, hold on
11 (day 10 was the first quiet day), −1 on 12, −1 every day after, floor at 0.

**The market cap's memory is persisted.** Regression #19 is "Market exceeds its
+1/day Pressure cap". A counter held in memory is exactly how that happens, so
`market_gain_day` / `market_gain_today` live on the ledger row. Four sales in a
district reach the cap, the fifth is free, and tomorrow starts over.

### The lifecycle grew a ROLLOVER phase, and Exposure and Curtis moved into it

TI-003 §9's post-increment sequence is now a declared list:

    ROLLOVER_ORDER = [
        pressure_bleed, pressure_recovery,
        financial_decay, financial_fold,
        exposure, curtis,
    ]

Two of those six positions are regressions in their own right. #25 is the
Financial Pressure fold running before the decay; #26 is Exposure propagating
morning Heat before the fold. Both produce plausible numbers, neither crashes,
and both are one moved line away at all times.

`Exposure` and `Curtis` used to hang off the `day_crossed` signal — which put
them at whatever position their `connect()` call happened to occupy, the exact
problem `day_lifecycle.gd` exists to remove, surviving in the two places it
mattered most. TI-003 §2 asks for explicit rollover methods and they now have
them. Their scoring math is untouched; only who calls them changed.

The #26 test is worth describing because it took a second attempt to make it
capable of failing. Exposure broadcasts past 10.0 on the `neighborhood` channel
and past 8.0 on `household`. Starting the morning at Heat 9.6 with Financial
Pressure 7, the fold's +1 carries the meter to 10.6 — a neighborhood broadcast.
Run Exposure first and it sees 9.6 and broadcasts to the household instead: a
different set of people find out, one day late, forever. Nothing about the final
state differs. Only who heard.

### District Heat scaling went live, and it moved shipped numbers

FS-003.3 authored TI-003 §7's district × family multiplier table, tested it as a
pure function, and deliberately did not consult it — applying it inside a
refactor whose acceptance criterion was "current source outcomes preserve
inherited totals" would have been a balance change smuggled into a no-op. This
is the slice it belongs to, and `_district_scaling_enabled` is now `true`.

Every criminal Heat gain is scaled by where it happened and what kind of crime it
was. The numbers that moved, named here rather than left for whoever next reads a
changed assertion:

| What | Was | Now | Why |
| --- | --- | --- | --- |
| Boost tier 1 success in Spenard | 0.5 | **0.45** | Spenard Boost ×0.9 |
| Boost tier 2 / 3 in Spenard | 1.0 / 2.0 | **0.9 / 1.8** | ×0.9 |
| Stickup clean, Spenard tier 1 | 1.0 | **1.3** | Spenard Stick ×1.3 |
| Stickup messy | 2.0 | **2.6** | ×1.3 |
| Stickup catastrophic | 3.0 | **3.9** | ×1.3 |
| Caught Fight/clean in Spenard | 1.0 | **0.9** | ×0.9 |

Relief and direct changes still bypass it, which grew a second half worth
asserting: laying low in Spenard must not be scaled by 1.3 either, or going quiet
would work differently depending on where you slept. The Financial Pressure fold
is +1 in every district for the same reason.

Every Deshawn check moved to a district the table does not name. "Applies once"
asserted against a figure two multipliers produced is a claim about neither of
them — if the product is wrong, either could be the cause.

### A ruling the build brief and TI-003 disagree on

The brief's Task 2 says *"Deshawn interaction: Heat fold goes through HeatSystem
(Deshawn applies)"*. TI-003 §7 routes the fold through `apply_direct`, and
`apply_direct` — shipped in FS-003.3 — bypasses the gain multipliers entirely.

**Ruled in favour of TI-003 and the shipped behaviour: the fold is +1 flat.**
Non-negotiable rule 8 makes TI-003 the authority for these systems, §7 lists
Deshawn under the *criminal gain pipeline* and names `apply_direct` separately
for the fold, and the fiction agrees — Financial Pressure Heat is not heat a
crime generated, it is the paper trail catching up, and Deshawn has nothing to
damp. The acceptance criterion that IS satisfied either way is the one that
matters architecturally: the fold routes through HeatSystem rather than writing
`gs.heat`, so the writer audit still holds. Asserted across all three districts
with Deshawn at rank 3.

### A band table the build brief states differently from the spec

The brief summarises the bands as QUIET (0–1.9), KNOWN (2–4.9), WATCHED (5–7.9),
HOT (8+). TI-003 §8 and FS-003 §6 both give QUIET 0–2.99, KNOWN 3–5.99, WATCHED
6–8.99, HOT at exactly 9, with penalties of 0.00 / 0.08 / 0.16 / 0.24.

**Implemented per TI-003/FS-003**, which non-negotiable rule 8 makes the
authority. The two specs agree with each other; the brief's summary is the
outlier. Worth flagging because it changes when a district starts biting: under
the brief's numbers a single messy Boost (+1.0) would put a fresh district a
fifth of the way to WATCHED, and under the approved numbers it does not reach
KNOWN until the third incident.

### Sabotage results

| # | Injected fault | Result |
| --- | --- | --- |
| 1 | KNOWN band starts at 2.0 | **caught** — 3 failures |
| 2 | `PRESSURE_QUIET_GRACE_DAYS` 1 → 0 | **caught** — 6 failures |
| 3 | Exposure moved before the fold | **caught** — trace + the #26 behavioural check |
| 4 | Fold moved before the decay | **caught** — trace + "five does not fold" |
| 5 | Bleed carries the full gain | **caught** — 3 failures |
| 6 | Market daily cap 1.0 → 10.0 | **caught** — 2 failures |
| 7 | Bleed due on the source day | **caught** — 2 failures |
| 8 | Boost stops subtracting the penalty | **caught** — 3 failures |
| 9 | Recovery counts the gain day as quiet | **caught** — 10 failures |

Sabotage 6 was initially caught for the wrong reason: several Market assertions
compared against `rules.PRESSURE_MARKET_DAILY_CAP` rather than against the
authored `1.0`, so raising the constant moved both sides of the comparison. Every
Pressure assertion now carries FS-003 §6's literal instead of the module's own
answer to the same question. Same class of mistake as FS-003.8's provenance hole:
a check that agrees with the code rather than with the design document.

### What FS-003.10 inherits

A declared ROLLOVER phase with a DAY_START after it, which is where retaliation
expiry and activation belong (TI-003 §9 step 6). `add_pressure` with a
`cause_id`, which retaliation resolution will use for its own Pressure rows.
And `local_attention_summary()`, which FS-003.11 renders.

## FS-003.8: what it costs when they actually have you  (added 2026-08-22)

`systems/arrest.gd`. Boost could already decide that a Caught result ended in
cuffs; Stick could not, and neither of them could say what happened next. Now
both hand the same system one fact — *this is what I am and this is how big it
was* — and everything after that is one owner's problem.

**Parity: 9,100 → 9,440 checks, 0 failures.**

### The two things a source system is not allowed to know

`attach_booking(chain, {family, tier, target_id, cause_id})` is the whole
interface. Boost passes `boost` and a tier; Stick passes `stick` and a tier.
Neither knows the severity table exists, that Boost tier 3 shares tier 2's
booking row, that a second arrest costs half again as much, or that four priors
add a slot. If they did, the second source would have to reproduce all of it,
and the two copies would drift the first time a balance pass touched one.

### The quote is frozen at arrest, but the release point is not

This looked like one rule and is two.

The **price** — bail, priors, multiplier, processing slots, Heat relief — is
computed once when the arrest is decided and stored on the chain. Recomputing it
at render time would reproduce the same number today and would start lying the
moment anything it reads moved. The live example is not hypothetical: the priors
count increments during the commit, so a quote recomputed after payment prices
the arrest the player is currently standing in as if it had already happened.

The **release point** is projected from the live clock instead. Both are stable
across reload — `day` and `time_slots_today` persist like everything else — but
only the live clock agrees with what the commit itself computes. An earlier
version projected from the quote's stamped position and disagreed with its own
receipt the moment a test moved the clock between the arrest and the decision;
in ordinary play nothing can, which is exactly the kind of agreement that holds
until it does not.

### The source slot and the booking slots are different time

TI-003 §13 separates them into steps 8 and 9, and it matters:

    8. settle the source action's one slot once;
    9. advance additional booking slots one by one;

The source slot is what the lift or the robbery costs, owed whether or not it
ended badly. The booking slots are what the arrest costs on top. The release
receipt counts them separately (`source_slots_settled`, `slots_served`) because
folding them together would quietly make the second arrest of a run cheaper in
wall-clock terms than the first, and nobody would have decided that.

Every one of those slots runs the ordinary night one at a time. The day-boundary
check parks the clock at NIGHT with rent due and somebody on the payroll, serves
the booking out, and asserts the run landed exactly where the projection
promised, that rent was **missed** rather than skipped, that a wage accrued for
each night inside, and that the market cursor moved. TI-003 regression #13 is
"Booking jumps days and skips obligations"; jail gets its weight from the
simulation that was already running.

### The arrest waits at `result`, and Continue is what books you

Behaviour change to shipped code, and a fix rather than an addition. FS-003.7
advanced an arrested Caught chain straight to `booking`, so the bail quote
rendered over a result the player never read. PX-003 §5 shows the arrested
result as a screen with a `BOOKING` action under it — the outcome first, then
the procedure. `_continue` now moves a `result` stage with a pending booking to
`booking` and settles nothing on the way, because §13 step 8 makes settling the
source slot part of the commit.

`open_chain` also gained an `initial_stage`. A Stick arrest has no decision — the
robbery already resolved through the source system's own tier roll — so its chain
opens at `result` rather than opening a decision with an empty choice list and
walking past it. The stage is validated against the same transition table every
later move is.

### The sabotage that passed, and why it is the most useful result here

Four of five planned sabotages failed the suite as intended. The fifth did not:

| # | Injected fault | Result |
| --- | --- | --- |
| 1 | Prior bail multiplier 1.50 → 1.25 | **caught** — 8 failures |
| 2 | Bail spends `ROUTINE_DIRTY_FIRST` | **PASSED — hole found** |
| 3 | Heat relief through `apply_gain` | **caught** — 5 failures |
| 4 | `settle_source_time()` deleted | **caught** — 3 failures |
| 5 | Stick gate `>` → `>=` | **caught** — 6 failures |
| 6 | Four-slot total cap removed | **caught** — 3 failures |
| 7 | Same-Cause suppression removed | **caught** — 2 failures |
| 2b | Bail spends `ROUTINE_DIRTY_FIRST` (after fix) | **caught** — 6 failures |

Sabotage 2 is the one worth writing down. The provenance check paid a bail out of
a wallet holding exactly the bail — clean $150, dirty $0, bill $150. Clean-first
and dirty-first move identical money in that situation, so the policy could be
swapped and nothing could see it. The check was not weak; it was **incapable**.

The fix is a wallet larger than the bill and mixed: $400 clean and $800 dirty
against an $875 quote. Clean-first takes $400 then $475; dirty-first takes $800
then $75. The Financial Pressure that falls out differs too (1 versus 4), so the
same setup carries the slice's Financial-Pressure-feedback requirement instead of
needing a second scenario.

The general lesson, worth more than the specific bug: **a check whose two
outcomes are indistinguishable under the fault it is meant to catch is not a weak
check, it is a decoration.** Rule 9 of this build ("every new verification check
must be sabotage-tested before being trusted") is what surfaced it, and it would
not have been found by reading the test.

### Decisions taken, and where they came from

- **Total time is capped at 4 slots, shortfall included.** TI-003 §13 says "cap
  base + prior adjustment at 4 slots" and lists the shortfall conversion
  separately; FS-003 §7 says "Maximum total booking/serving time from one arrest
  is 4 time slots" and repeats "Total time remains capped at 4 slots" under both
  shortfall lanes. The total reading satisfies both documents and is what makes
  TI-003 regression #14 ("a broke player loses every legal Booking option")
  false in practice: SERVE IT is always offered, always $0, and never longer
  than a day. Without it, serving a $1,000 bail at four priors is eleven slots.
- **The arrest observation is authored here.** FS-003 §7 says an arrest writes an
  Exposure observation "only where an authored observer/channel qualifies" and
  never names the row. It is `heat_exposure` / `neighborhood`: the category whose
  existing weights already price "you brought police into my life" correctly
  (Yalonda −3.0, Mina −1.5), on the one-day channel the household and the block
  actually hear things through. Curtis is not on `neighborhood`, and
  `heat_exposure` does not clear his network filter either — an arrest is not how
  he finds out, which the suite asserts rather than assumes.
- **`all_cash` is hidden when full bail is affordable, and at $0.** FS-003 §7's
  own availability rule. Offering "put up what you have" beside "post full bail"
  at the same price is two buttons for one action; offering it at $0 is Serve
  with extra steps.
- **Stick allocates a Cause on every attempt, not only on an arrest.** TI-003 §4:
  "Every qualifying risky source action gets one stable Cause ID." Two consumers
  need it and neither is knowable at allocation time — the arrest gate, and
  FS-003.10's retaliation scheduler, which keys its schedule roll on the Cause.
  Allocation is a counter bump that writes no history row, so an attempt nothing
  ever answers costs one integer.

### What FS-003.9 inherits

A booking that settles time through the ordinary lifecycle, which is the seam
Pressure bleed and the Financial Pressure fold will run inside. `district_pressure`
already has real history in it from FS-003.7's Caught gains — .9 starts from a
ledger with entries rather than from zero. And `heat.gd`'s `_district_scaling_enabled`
is still `false`: that one line is .9's, and flipping it changes what every
existing crime costs in Heat.

## Doc drift cleanup: making the baseline honest before layering on it  (added 2026-08-22)

The first commit of the FS-003.8-.12 branch changes no behaviour. It fixes three
places where the written record had drifted from the merged one, because every
statement made after this point is layered on top of these.

**1. `README.md` claimed the engine was the next gap.** It said *"The consequence
encounter engine is the next real gap"* — written before FS-003.3 through .7 and
true when it was written. PR #45 merged all five. The section now says what
actually shipped (one blocking chain with exactly-once receipts, Wallet/Heat as
sole writers, pure odds projection, and Failed Boost -> Caught end to end) and
carries a table of the five slices that genuinely remain. A README that
overstates what is missing is the same failure as one that overstates what is
done: the next person cannot tell which sentences to trust.

**2. The ClickUp `Current Godot Build State` callout was three merges stale.**
It named PR #34 and 2,399 parity checks as the current baseline. Merged `main` is
PR #45, save schema v8, 9,100 parity checks. A new authoritative callout now sits
at the top of that document.

The old callout is **retained directly beneath it rather than deleted**, and the
new one says so explicitly. That is a tooling decision, not an editorial one: the
page is ~150,000 characters and the available update path is whole-page replace or
prepend. Re-emitting 150,000 characters to change one paragraph risks a
transcription error somewhere in the other 149,800, and a corrupted living doc is
a worse outcome than a superseded paragraph that is labelled as superseded. The
"BASELINE UPDATE" sections further down were already audit-trail by convention;
this one joins them.

**3. ClickUp slice statuses were checked against the merge, not assumed.**
FS-003.1 through FS-003.7 all read `shipped`, which is correct — PR #45 is merged
to `main`, and `shipped` means exactly that. FS-003.8 through FS-003.12 read `not
started`, which is also correct at the time of this commit. No status was moved on
trust; each was read back from the API. The rule this branch inherits and keeps:
a slice reads `shipped` when the PR carrying its work is merged, never when the
code is written.

### Baseline verified before any of it

Godot 4.7.2 headless, `main` at `5efcb15`:

```
parity: PASS — 9100 checks, 0 failures
```

That number is the floor `MIN_CHECKS` enforces, and it is what the four feature
commits after this one have to move up rather than down.

## FS-003.7: the first thing that answers back  (added 2026-08-21)

A failed Boost no longer ends in a toast. It opens a Caught encounter, holds the
take in dispute, and waits. **Parity 8785 → 9100 checks, 0 failures. No schema
change** — .4 already persists everything this writes.

### Three deliberate removals from the source path

TI-003 §11: *"The failed branch removes its current immediate terminal
Heat/log/time behavior because Caught now owns those consequence effects."*

- **No immediate +1.0 Heat.** Regression #3 is a failed Boost keeping its old
  Heat and then adding Caught's on top.
- **No empty-handed toast.**
- **No `advance_time`.** The slot stays owed until Continue — a blown lift must
  not cost the player time before they have answered for it.

FS-003.1's freeze caught all three the moment they changed, which is exactly
what it was built for. Those assertions are updated rather than deleted, each
saying what it now protects and why it moved.

### The frozen Boost pattern moved, and the reason is worth reading

`BOOST_FROZEN_PATTERN` is re-pinned — two bits, `spenard_fuel` on days 4 and 6,
both following a `night_owl` miss.

Nothing about the roll changed. The key is `boost:<day>:<slot>:<target>`, and
before this slice a failed lift settled its slot immediately, so the next target
in the same day rolled at slot+1. Now the slot stays owed, so it rolls at the
**same slot** and therefore against a different key.

The derived check (`resolves binary`, which reads the live key) passed
throughout. What moved is *when the clock advances*, which is the point of the
slice — and which is separately asserted by "a failed lift costs no slot yet".

### `data/consequence_rules.gd`

TI-003 §3's static module. Every value from FS-003 §5 or TI-003 §8, no state, no
RNG, no judgement calls made while coding. A balance change is an edit there and
nowhere else.

**Two shorthand forms FS-003 uses are resolved in one place.** The document
writes Fight/Failure as "Tier 1 +2, Tier 2 +3, Tier 3 +4" and Run/Failure as
"Tier +1" — the same rule, enumerated once and patterned once. `raw_heat()`
resolves both, and a sabotage breaking the pattern form produces 13 failures.

**One interpretation is stated rather than buried.** Fight/Clean takes "the lower
half of the tier's successful-fight injury band". Halved at the midpoint rounded
DOWN, both ends inclusive — tier 1's 4-9 becomes 4-6. Rounding up would make
"the lower half" of 4-9 reach 7, which is more than half of it. The alternatives
differ by one point of damage and the choice is on the record.

**One ambiguity resolved in TI-003's favour.** FS-003 §5 says a ban lasts "the
current Boost ban duration used by the source system" — there was no ban system
to inherit a duration from. TI-003 §5 rules bans "persistent by target ID", which
is later, more specific, and implementable. Bans are permanent.

### Two layers of test, neither deriving from the other

**The authored rows** are checked as data, against FS-003 §5 transcribed a
*second* time into the parity runner. Two transcriptions of one document, typed
from the source rather than from each other — a slip in either is a failure
rather than a shared mistake. That layer catches a heat value off by one, which
no integration test would find because it would apply the wrong number correctly.

**The applied effects** are checked through `gm.dispatch`, on chains opened by
real failed lifts. That layer catches the right table read into the wrong field.

### The bug that made 39 encounters identical

The first draft reset the run before every sweep attempt. The consequence roll is
keyed on `consequence:<cause_id>:boost_caught:<choice>:outcome`, and
`reset_to_new_game()` resets `next_cause_sequence` — so **39 consecutive chains
all got `cause:00000001` and all resolved the same way.** The sweep read as "Run
never keeps the take".

The sequence is carried across sweeps now, which is also the truthful model: in
play the counter only goes up. And a new check pins the property directly —
cause ids are unique and sequential within a run, **and distinct causes resolve
to more than one tier.**

That last assertion is the one that matters. Cause-id uniqueness is load-bearing
for outcome VARIETY: if allocation ever stopped advancing, every encounter in a
run would resolve identically and nothing about the resolver or the effect tables
would look wrong. It is why TI-003 §4 makes allocation sequential and persisted.

### Three sabotages passed, and all three were real coverage gaps

- **`arrest-gate-reads-live-heat`.** Swapping the pre-encounter snapshot for the
  live meter changed nothing, because every case the sweep reached arrested
  unconditionally. Now driven at the exact boundary: pre-encounter Heat 6.0
  (which does not arrest, the rule is strictly greater) while Run/Failure adds +2
  raw, so the live meter reads 8.0 by the time the gate runs. If the adapter
  passed `gs.heat`, it flips. **2 failures.**
- **`contested-take-rerolled-on-key`.** Moving the take key from `:take` to
  `:contested` passed, because "in band" is true for any key. Now asserted as the
  exact keyed value. **3 failures.**
- **`odds-use-compat-not-raw`.** TI-003 regression #9. Passed because the sweep
  ran at combat 1, where raw 1 and `compat(1) = 2` are *both* below the advantage
  threshold and project identically. Now measured at **combat 2 specifically** —
  raw 2 is below advantage, `compat(2) = 3` is at it, and the odds differ.
  **3 failures.**

Sixth build running. Still never once has a first-attempt sabotage pass meant the
code was fine.

### And the parse-error-as-hang trap, twice in one session

A GDScript parse error means `_ready` never runs, so `quit()` is never called and
the headless process sits forever — indistinguishable from an infinite loop. It
cost time in FS-003.5 (`:=` off an untyped return) and again here (a probe
counter declared against `var _checks: int = 0` when the source reads
`var _checks := 0`, so the edit silently did not apply).

**Read the first ten lines of the log before hunting for a loop.**

### Verification

- Parity **9100 / 0**, deterministic across three consecutive runs.
  `MIN_CHECKS` 8785 → 9100.
- **27 sabotages**, all red after the three above were corrected.
- Glyph coverage passes; **21/21** screens headless with zero script errors.
- Dispatch-guard warnings still **2**; zero parse errors.
- Market RNG non-drift asserted around chain opening and all four responses.

## FS-003.6: the odds the player is deciding on  (added 2026-08-21)

`success_probability()` and `tier_probabilities()` on the outcome resolver.
Pure, exact, zero RNG. **Parity 8267 → 8785 checks, 0 failures. No schema
change.**

### Derived, not sampled

The obvious implementation runs the resolver a thousand times and counts. That
consumes no stream, but it is slow on a hot path and — worse — **approximate on
a screen that shows an exact percentage.**

So the pipeline is inverted analytically. Every step has a closed form:

1. `build_outcome_pool` splits `chance` across the shape's tier weights;
2. at level ≥ 6 the catastrophic entries leave and the rest renormalise, which
   *raises* the odds — the weight that fed the worst tier is redistributed;
3. below level 3 the answer is the success share of that pool;
4. at level ≥ 3 two independent keyed picks are taken and the better wins, so
   the action fails only when **both** picks land on a losing tier:

```
P(success | advantage) = 1 - (1 - p)²
```

Two identities fall out and are pinned as literals, because a sampled matrix can
only ever be approximate:

- **Below both thresholds, the projection IS the base chance.** Every shape's
  `success` half sums to 1.0 and its `failure` half sums to 1.0, so splitting a
  chance across them cannot change how often you win — only what winning looks
  like.
- **With advantage at 0.5, exactly 0.75.**

### Proved against the resolver actually running

A check that recomputed the shape table and compared would be the implementation
written twice; it would agree with a broken projection as readily as a correct
one.

So `_measured_success_rate` calls **`resolve_action` over 4000 distinct keys per
cell** and counts how often the tier came back a success. Nothing about that
measurement knows the shape table exists. The matrix covers 4 action types × 3
chances × 6 attributes, spanning both thresholds and the ceiling.

### The finding: FNV-1a is biased by its LAST characters

The first run produced **four failures that were the harness, not the code.**

`seeded_random` is canon's `stringHash(key) / 2^32` — an FNV-1a whose
multiplication propagates low bits upward. A character near the **end** of the
key barely moves the **high** bits, and the high bits are exactly what dividing
by 2³² reads.

Measured directly, 4000 keys, same indices:

| index position | mean | P(< 0.25) |
| --- | --- | --- |
| tail — `confrontation:250:0:<i>` | **0.531** | **0.188** |
| front — `<i>:confrontation:250:0` | 0.502 | 0.252 |

True values are 0.5 and 0.25. **Sweeping a keyed roll with a trailing counter
does not sample a uniform distribution at all.**

This is canon's hash, bias and all — `game-core.js` uses the same `stringHash`,
so it is not a defect to correct here and correcting it would diverge from the
oracle. It is a **trap to avoid in every future check**: any sweep that varies
the tail of a key is measuring a skewed distribution, and will produce false
failures or, far worse, false passes.

`_check_projection_harness_is_uniform()` now measures the sweep's own key family
before any projection assertion runs. A failure there says *"the sweep is
broken"* — a much more useful message than fifty mismatched probabilities. It is
sabotage-proven by moving the index back onto the tail: 6 failures.

**Worth carrying to the real game:** keys shaped `family:<int>:<small int>` are
the biased shape. `shark:%d:%d` (loan id, due day) is one. Canon has the same
behaviour so nothing is diverging, but it is filed rather than unnoticed.

### Three sabotages passed, and one of them stays passing

- **`immunity-drops-guard`** — removing canon's "only drop catastrophic when
  something survives" fallback changed nothing, because no authored shape is
  all-catastrophic. Now exercised on a **synthetic pool** through
  `_immunity_filtered` directly, the same way FS-003.4's migration arm is
  exercised at its own boundary rather than through a path that hides it.
  Sabotage now: 2 failures.
- **`projection-draws-rng`** — the sabotage multiplied by
  `1.0 if randf() >= 0.0 else 0.5`, which is identity. Replaced with a call
  counter that perturbs the answer (132 failures) and a version that genuinely
  moves `rng_state` (1 failure).
- **`bonus-not-clamped` — still passes, and that is correct.** Both thresholds
  are one-sided, so an unclamped effective level of 17 lands in the same band as
  a clamped 12, and −5 in the same band as 0. The clamp stays for symmetry with
  `resolve_action`, which needs it. The checks that used to claim "the clamp
  works" now claim what they actually prove — that the projection is **flat**
  past the ceiling and below the floor, and **monotonic** in effective level
  across −3..15. A check should not claim more than it can fail on.

### Verification

- Parity **8785 / 0**, `MIN_CHECKS` 8267 → 8785.
- **14 sabotages**, 13 red; the fourteenth documented above as correctly inert.
- Glyph coverage passes; 21/21 screens headless, zero script errors.
- Projection asserted to draw nothing from the market stream **and** to be
  referentially transparent — a helper drawing from a keyed hash would leave
  `rng_state` alone while still returning a different answer each call.

## FS-003.5: something to hold the moment open  (added 2026-08-21)

`systems/consequence_engine.gd` and `ui/screens/consequence.tscn`. When a risky
action goes wrong, something has to hold the situation open across a save, a
reload, and a player who put the phone down mid-decision. **Parity 8036 → 8267
checks, 0 failures. No schema change** — .4 already persists everything this
writes.

### Orchestration, not content

The engine can open a chain, carry it through four stages, refuse a bad
transition, keep an exactly-once ledger, arbitrate a queue, and hand the UI a
projection. It knows nothing about what being caught costs, what bail runs, how
Pressure accrues, or who retaliates. Those are .7, .8, .9 and .10.

Everything is written to be **filled in rather than replaced**: `open_chain`
takes an authored shape, the stage machine is a declared table, and the
projections read whatever the chain carries. A later slice adds a chain kind and
authored effects without touching this file's control flow.

### Receipts, not flags

TI-003 §4 wants the effect and its receipt in the same dispatch. The failure that
prevents is ordinary: apply Caught's heat, autosave, player reloads before
pressing Continue — without a receipt the chain reopens at the same stage and
applies that heat again.

`record_receipt` **returns false when the key is already claimed**, so the call
site reads:

```gdscript
if engine.record_receipt(cause_id, "boost_caught:heat"):
    heat.apply_gain(...)
```

Written that way round deliberately. `if not has_receipt(): apply(); record()` is
three lines that can be reordered wrongly; this is one that cannot.

### Committed buttons stay committed after a reload

TI-003 §18's sharpest requirement, and the reason `disabled` comes from
`choice_summaries()` rather than from a `_pressed` handler. **A flag set on click
lives in the scene, and the scene dies on reload.** The commit lives in the chain,
and the chain is in the save.

The check asserts it the way the button does — through the projection, after an
actual save/load round trip.

### The route guard is one function, not twenty

TI-003 §18's priority is game over → active consequence → ordinary screen.
`ScreenManager.resolved_route()` is pure and applies it, and `go_to()` runs
everything through it. That matters because *"ordinary navigation cannot bypass
it"* has to hold for navigation nobody has written yet.

The check walks **every ordinary route from ScreenManager's own constants**
rather than a list kept in the test — a screen added without a route guard is
exactly the gap this catches, and a hand-maintained list would not see it.

`go_to_game()` is the boot and CONTINUE RUN path, so a save loaded mid-chain
lands on the consequence rather than on Home and correcting — §18 requires that
to happen without an ordinary screen being exposed for an interactive frame.

### Two sabotages passed. Both were the check's fault.

**The stage guard was never being measured.** The test advanced past `decision`
and asserted a commit was refused — but a choice had already been committed on
that chain, so the committed-choice *receipt* refused it whether or not the stage
was ever checked. Deleting the stage guard outright went green.

Measured now on a chain with **no prior commit**, plus assertions that the
refusal recorded no receipt and committed nothing. Same sabotage: 3 failures.

**Nothing proved the copying projections were copies.** `choice_summaries` builds
its rows fresh, so aliasing is not reachable there and the check could not fail.
The realistic edit is dropping `.duplicate(true)` from `booking_summary`,
`result_summary` or `queue_snapshot` — where a screen could then write into
persisted state without a dispatch and without anything saving it. Three checks
added, three sabotages, all red.

**Fifth build running.** A first-attempt sabotage pass has still never once meant
the code was fine.

### A parse error reads as a hang

Worth writing down because it cost real time: a GDScript **parse** error in the
runner means `_ready` never runs, which means `get_tree().quit()` is never
called, and the headless process sits there forever. It looks exactly like an
infinite loop in a new check.

The cause was `:=` inferring off an untyped `RefCounted` return. Three
declarations needed explicit `: String`.

**If a parity run hangs, read the first ten lines of the log before hunting for
a loop.**

### The scene

Generated from `hustle.tscn` through `scripts/make_surface_screen.py`, then the
`NavBar` subtree and the floating HOME button stripped — TI-003 §18 keeps the
TopBar and six-stat HUD and omits bottom navigation, because there is nowhere
else to be until this resolves.

Four stages in **one** scene. Separate scenes would duplicate the chrome four
times and would make the stage a navigation fact, when stage is a state fact that
has to survive a reload.

A deterministic response shows **CERTAIN**, not 0% — showing a Yield that always
resolves as zero percent would read as impossible when it means the opposite.

### The container needed an import pass

A brand-new `.tscn` will not load until Godot has imported it, and this repo's
`.gd.uid` companions are tracked (176 of them). `--headless --import` generates
both. It also produced the asset import cache, which **cleared all 22
long-standing `Parse Error: referenced non-existent resource` lines** from the
run — those were an artifact of a fresh clone, not a repo problem.

Three `.uid` files from FS-003.3 and .4 are committed here because Godot had not
imported when those landed.

### Verification

- Parity **8267 / 0**, `MIN_CHECKS` 8036 → 8267.
- **27 sabotages**, all red after the two above were corrected.
- Glyph coverage passes.
- **21/21** screens instantiate and bind headless with zero script errors — the
  consequence scene included.
- Dispatch-guard warnings still **2**.
- Engine RNG non-drift asserted, with `consequence_continue`'s time advance
  measured separately so the claim stays the narrow true one.

## FS-003.4: the engine gets somewhere to live  (added 2026-08-21)

Save schema **v7 → v8**. Everything TI-003 §5 declares now persists, and a v7
save migrates into it deterministically. **Parity 7889 → 8036 checks, 0
failures.** Nothing writes the new state yet — FS-003.5 is the engine that does.

### The arm has one transform, and only one

Thirteen fields are added and twelve of them simply default in. That is not
laziness: a v7 save **cannot** contain an unfinished consequence, a prior arrest,
a Boost ban or a Pressure score, because none of those systems existed while it
was being played. Empty is the true history, not a fallback — the same argument
the v3 → v4 attributes arm makes. TI-003 §20 says it too: *"A pre-TI-003 Godot
save contains no unfinished consequence, so migration creates no inferred active
chain."*

The wallet is the exception, and it is the v6 → v7 `source: "player"` case again:
**stamp what is knowable while it is still knowable.** A v7 save records one
aggregate `cash` and nothing about where it came from. Every day it stays
un-migrated is a day that number could be split by a rule nobody wrote down.

TI-003 §20/§26 rules the whole aggregate **clean**, deliberately diverging from
canon (game-core.js:2060, which rules dirty). The arm follows TI-003.

### A sabotage that passed, and the dead code it found

Deleting the arm's wallet transform outright — replacing both lines with `pass`
— left the suite **green at 8036 / 0**.

The reason: `_apply` fills the absent bucket fields from GameState's defaults,
and the load-time classifier then sees no carried provenance and applies TI-003's
rule anyway. Two independent paths, same answer, so neither is individually
observable. Defence in depth that had quietly made the arm untestable.

The fix is to test the arm where it actually lives: `_migrate()` is called
directly and its **returned payload** inspected, before a byte reaches
GameState. Nine checks now sit on that boundary, and the same sabotage produces
4 failures.

**Carry forward:** two mechanisms that agree are two mechanisms neither of which
is tested. If a sabotage on one passes, look for the other one first.

### Two more sabotages passed because the sabotages were no-ops

Both are the `make_stream(cursor).state` mistake in a new costume:

- **"Pressure score coerced to int"** added an unused variable, which changes
  nothing. The real fault is rounding floats *inside* persisted Dictionaries —
  the shape a "normalise save data" change actually takes. Rewritten that way it
  produces 5 failures, and it matters because Pressure **bands** are keyed on
  the fractional score: a 6.5 WATCHED rounds into a different band.
- **"Objects in save"** added a `NodePath` field to GameState that was not in
  `PERSIST_FIELDS`, so it never reached the payload. Adding it to the manifest is
  the real regression (TI-003 #38) and produces 1 failure.

Third build running where a first-attempt sabotage pass meant a bad sabotage
rather than good code. Never once has it meant the code was fine.

### The round-trips

TI-003 §20's twelve required shapes are each staged, saved, **scrambled**, and
reloaded. The scramble is what stops a "restored" assertion from passing on state
the test never removed — `_roundtrip()` wipes every consequence field to a
sentinel before the reload.

The queue is an **Array**, and its restored order is asserted as a whole id
sequence rather than one element: TI-003 regression #32 is "queue order depends
on Dictionary iteration order", so ordering has to be a property of the storage.

Two shapes are asserted that the brief did not ask for and that later slices
would have been hurt by:

- **The empty case.** Round-tripping only populated shapes misses a default that
  fails to serialise — and every save before FS-003.7 is the empty one.
- **A v8 reload does not launder.** A mixed wallet reloads with its dirty money
  still dirty. This is exactly what breaks if the load-time classifier runs
  unconditionally rather than only where provenance is absent, and that sabotage
  produces 5 failures.

Boost bans are checked against **both** halves of regression #11 — reload *and*
day-cross, the latter through a real `advance_time` dispatch.

### Verification

- Parity **8036 / 0**, `MIN_CHECKS` 7889 → 8036. Thirteen of those came free:
  the round-trip section walks `PERSIST_FIELDS` by name.
- **15 sabotages**, all red after the three above were corrected.
- Glyph coverage passes; 20/20 screens headless with zero script errors.
- Save payload asserted to contain no `Object(` and no `NodePath(` — checked
  against the serialised text, not the live Dictionary, because a payload that
  writes a handle and reads back as something else would never show in memory.

## FS-003.3: cash and heat get owners  (added 2026-08-21)

Twenty-one lines across eleven systems wrote `gs.cash`. Five wrote `gs.heat`,
and two of those five were the same function copied into two files. Both fields
are now owned. **Parity 7726 → 7889 checks, 0 failures. No schema change.**

### The audit that started this was wrong, and the correction is the point

The brief counted **20** direct cash writers across 10 systems. The real number
at `72128b2` is **21 across 11** — `systems/list_adapter.gd:207` was missing from
the list, which is Pherris spending the player's money on a delegated 907List
pickup. It is exactly the kind of writer an audit misses: it does not live in
the system that owns the surface, it lives in the adapter that drives it.

That one line is the argument for the automated audit in this slice. A count in
a document is right on the day it is written; a check that fails the build is
right every day after.

### What each source's money now is

TI-003 §6 classifies income, and canon backs every row of it. The two
`addCleanCash` call sites in the entire web build are `WORK_JOB`
(game-core.js:7311) and `recordMarketFlip` (3160) — legal wages and a resale on
a public board. Everything else is dirty.

| source | bucket | why |
| --- | --- | --- |
| job shift | **clean** | canon `addCleanCash` |
| 907List flip | **clean** | canon `addCleanCash` |
| stickup take | dirty | canon `addDirtyCash` |
| boost take / fence payout | dirty | canon `addDirtyCash` |
| market sale | dirty | TI-003 "Market criminal sales" |
| territory corner income | dirty | TI-003, once its payout caller migrated |
| shark note returned / enforced | dirty | canon `addDirtyCash` (6569, 7997) |

Spends carry a policy rather than a bucket. Rent and the phone bill are
`HIGH_VISIBILITY_CLEAN_FIRST` because TI-003 §6 names them; the clinic is too,
because §6 delegates "formal Recovery spending" to Recovery to declare and a
clinic bills you. First aid and the No-Questions Doctor are routine — the second
one is *named* for not generating a record, which is what dirty money is for.

### Deshawn applies once, and it is grep-checkable

The real risk in this migration: if `HeatSystem` scales by the crew multiplier
and a migrated caller still scales by it too, Deshawn double-counts and nothing
obviously breaks — 10 raw heat becomes 6.4 instead of 8.0.

So every caller had its own lookup **deleted** rather than left alone. Both
`_apply_heat` copies are gone, and `shark.gd` and `territory.gd` no longer fetch
a multiplier at all. `systems/heat.gd` is now the only file in the codebase that
calls `crew.heat_multiplier()` to apply it, and a parity check asserts the caller
list is exactly `{crew.gd, heat.gd, ui/screens/crew.gd}` — the owner, the one
consumer, and the screen that displays it as a number.

The numeric coverage runs ranks 1, 2, 3, **4 and 7**. Above rank 3 the curve
holds rank 3's 0.40 rather than falling back to neutral, which is a bug crew.gd
already fixed once: a promotion must not silently remove the reduction he earned.

### Relief bypasses the gain pipeline

`apply_relief` does not call `_gain_multiplier()` — not "multiplies by 1.0", does
not call it. If relief went through Deshawn, having him on the crew would make
Lay Low work *less well*, which inverts his whole purpose. TI-003 lists this at
regression #15 and the check measures the identical relief with him present and
absent.

### The district table ships as data and is deliberately not wired

TI-003 §7 authors a district × family heat multiplier table. It is in
`systems/heat.gd`, complete, and covered by nine pinned checks — and
`apply_gain` does not consult it. Wiring it would change what every stickup and
boost costs, which is a balance change to a shipped formula inside a refactor
whose acceptance criterion is that current source outcomes are preserved. The
multipliers also only mean anything beside District Pressure (§8), which is
FS-003.9. `_district_scaling_enabled` is the one line that slice flips, and a
check asserts it is still inert today.

### A bug in FS-003.2's tests: six checks that never ran

`post_settle_hooks` is declared `Array[Callable]`. FS-003.2's own tests
registered hooks by assigning an untyped array literal — `lifecycle.post_settle_hooks = [probe]`
— which does not convert, raises at runtime, and **aborts the enclosing check
function**. The suite reported 7726 checks and 0 failures while six of its checks
had never once executed, including every assertion that a hook runs at all.

This slice depends on those hooks, so the trap is closed rather than worked
around: registration is `add_post_settle_hook()` / `add_day_start_hook()` /
`clear_hooks()`, the typing stays, and no caller has to know why the literal form
fails. The recovered checks are why the floor rises by 163 while the section
adds 157.

This is `MIN_CHECKS` doing precisely the job it was added for — the floor moving
up by *more* than the checks added is the tell.

### The reload window, named rather than discovered later

The buckets are **not persisted this slice** — that is FS-003.4, with the schema
bump and the migration arm. So a save/load round trip reclassifies the whole
balance as clean, which in provenance terms is a laundromat.

It ships that way because nothing reads provenance to make a decision yet:
Financial Pressure accumulates but is not consumed until FS-003.9, and no system
asks which bucket a dollar came from. Unobservable in play, closed by the next
slice, and written down here rather than found later.

### The migration rule diverges from canon, deliberately

Canon classifies its own pre-split saves as **dirty** (game-core.js:2060-2066):
*"nothing in pre-v1.0 gameplay ever laundered anything, so this is the
narratively honest default."*

TI-003 §20 and §26 rule the opposite for this port: *"Old Godot saves enter with
prior aggregate Cash classified Clean."* TI-003 is the approved implementation
contract and wins, so `WalletSystem.classify_legacy_total()` sets clean and
zeroes dirty. Both readings are in that function's docstring, in one place, so
the divergence is a decision on the record rather than an accident.

### Verification

- Parity **7889 / 0**, `MIN_CHECKS` 7726 → 7889.
- **28 sabotages, all red**, every one reverted — writer audits, policy matrices,
  Deshawn double-application, relief through the multipliers, clamp reporting,
  reconcile direction, legacy classification, per-source provenance, RNG drift,
  and the hook-registration fix itself.
- Glyph coverage passes.
- All **20 screens** instantiate and bind headless with **zero** script errors
  (`tests/smoke/screen_smoke.tscn`, added here because this checklist item
  previously needed the editor MCP and could not be run headless).
- Dispatch-guard warnings unchanged at **2**. (The brief expected 4; the
  ownership test exercises Exposure's two mutators only. Curtis's three are
  guarded but untested — filed, not fixed here.)
- `rng_state` non-drift asserted around both owners, and the market walk asserted
  to still move it so the check cannot pass on a field that never changes.

## FS-003.2: the night gets an order  (added 2026-08-21)

Two things: the Boost heat divergence FS-003.1 froze is corrected, and night
settlement stops being an accident of signal-connection order. **Parity 7665 →
7726 checks, 0 failures. No schema change.**

### The freeze paid off immediately — and caught its own bug

FS-003.1 pinned Boost's tier-1 heat at the port's 1.0 and named it a known
divergence from canon's 0.5, so the correction could not land quietly. It did not
land quietly: flipping the constant turned the assertion red on the first run,
exactly as designed.

**But the assertion was measuring the wrong thing.** It ran on a fixed probe day
that happens to be a MISS — and a miss costs 1.0 at any tier — so it read 1.0 for
the wrong reason and would have stayed green even if tier-1 *success* heat had
been correct all along. The freeze it claimed to hold never held anything.

The day is derived now: walk until the lift lands, then assert, and cover the
miss branch separately with each saying which branch it is. Worth remembering
that **a check on a fixed seed can be measuring a branch you did not intend** —
and that a green freeze is not proof the frozen thing was ever observed.

The fix itself: `_apply_heat` takes a `float`, the call site passes canon's
`0.5 / 1.0 / 2.0`. The int signature was what forced the divergence — 0.5
truncated to nothing, so the call site rounded up.

### What was actually wrong with the old ordering

Five systems connected to `day_crossed` in whatever order GameManager's
`_ready()` happened to construct them. That is an ordering contract expressed as
a side effect of construction order: invisible in review, untestable, and
silently rewritten by moving a line in an unrelated file.

`systems/day_lifecycle.gd` makes it a list:

```
PRE_SETTLE → SETTLE(crew · territory · shark · jobs · obligations)
           → POST_SETTLE → INCREMENT → MARKET(evolve · day_crossed) → DAY_START
```

The trace is asserted as a literal. Reordering a phase is now a deliberate edit
that breaks a test, which is the contract FS-003.3 through .12 inherit.

### Hooks are Callables, not signals

`post_settle_hooks` and `day_start_hooks` are Arrays of Callables running in
index order. Signals have exactly the ordering problem this file exists to
remove — the order handlers run in is the order they connected, which nothing
declares and nothing tests.

### `ended_day` is a parameter now

Jobs and obligations derived `gs.day - 1`, which only worked because their
handler happened to run after the increment. Canon passes the day explicitly for
the same reason (`applyAttendance(state, oldDay)` carries the comment). That
arithmetic is gone.

### A second divergence found, and deliberately NOT fixed

Canon's `confirmDayEnd` settles crew and shark **above** the increment, so both
see the ending day. This port has always settled them below it, seeing the new
day — so `crew.settle_night` and `shark.settle_night` now compute against
`ended_day + 1` to keep their behaviour byte-identical.

That is on purpose. This build creates the seam; moving when wages bite or a note
comes due is a timing change with real consequences for a live save — the crew
wage sentinel persists and is read by `payroll_not_delinquent`, so shifting it
moves an eligibility gate that has already shipped. Filed as its own slice.

The `+ 1` is commented at both call sites and, more importantly, **asserted**:
a note due on the settling day comes due tonight, one due after it does not.
Claiming a divergence is preserved is worth nothing if nothing checks it — that
gap is what sabotage 8 found.

### The refactor proved itself

All 7665 inherited checks stayed green through the migration of five systems off
`day_crossed`. That is the strongest thing a seam refactor can demonstrate, and
it is only possible because FS-003.1 pinned the behaviour first. The freeze pass
paid for itself one build later.

### Sabotage log — 11 faults, all confirmed red

| # | fault | result |
|---|---|---|
| 1 | crew and obligations swapped in `SETTLE_ORDER` | 2 failures |
| 2 | `day_ending` never emitted | 8 |
| 3 | `economy.evolve()` called twice | 1 |
| 4 | `day_crossed` emitted before the increment | 2 |
| 5 | boost tier-1 heat reverted to 1.0 | 1 |
| 6 | jobs settles against the new day again | 1 |
| 7 | crew wage clock shifted to the ending day | 1 |
| 8 | shark note settlement shifted to the ending day | 0 → **1** |
| 9 | a settler dropped from `SETTLE_ORDER` | 20 |
| 10 | POST_SETTLE hooks moved after the increment | 1 |
| 11 | obligations settles the new day | 10 |

Number 8 escaped first time: nothing covered shark's settlement day, which is
precisely the divergence this build claims to preserve. An untested claim.

### And the tests were on the wrong path again

The "settlement consumes no market RNG" check called the settlers directly,
which tripped the dispatch-ownership guard twice and measured the right thing on
a stack the game never produces. It measures from inside a **POST_SETTLE hook**
now — the exact moment after every settler and before the market walk, on the
real dispatch path. Back to the 4 baseline warnings, all from the ownership test
that deliberately calls outside a dispatch to prove refusal.

Fourth build running. The new hook turned out to be the right instrument for
testing the thing it was added for, which is a good sign about the seam.

## FS-003.1: the freeze pass  (added 2026-08-21)

Regression protection before the Consequence-Encounter Engine starts moving
shared seams. **Parity 7400 → 7665 checks, 0 failures. Test-only — one file
changed.** The floor is now 7665 and that is the contract FS-003.2 through .12
inherit.

### What this did NOT do, and why that matters

The brief named ten areas to pin. An audit found most of them already pinned,
several heavily: the Outcome Resolver's pools and thresholds and its whole
resolution grid, stickup's four tiers and their consequence spread, `day_ending`
ordering, market cursor isolation, Curtis's volume filter, the save round-trip
and the v6 → v7 arm.

**A second copy of an existing assertion raises the count and protects nothing** —
and this suite has already learned that a green result is only as good as the
checks behind it. So the work went where the audit found actual holes:

| area | state before | done |
|---|---|---|
| Boost behaviour | only `chance_for()` | full: roll, take, heat, technique, daily gate, tier gates, tier-3 merchandise |
| The fence | **zero assertions** | rate table, payout, standing clamp, household-only broadcast |
| Heat write path | per-tier figures only | fractional, clamped, multiplier re-read fresh |
| Cash on refused actions | implicit everywhere | every blocker asserted not to move the wallet |
| Dispatch-ownership guard | **untested** | refuses outside dispatch, lands inside |

### Two bugs in the suite itself

**A check that could pass vacuously.** Build 5e's market-cursor check dispatched
a robbery and asserted the cursor had not moved — without asserting the robbery
happened. A blocked robbery moves nothing, so it was true for the wrong reason,
and a stickup that genuinely drew from the market stream would have gone
unnoticed. It asserts the dispatch now.

**A check that was a tautology.** The Boost binary rule was verified by
recomputing `roll < chance` in the test — so inverting the operator flipped both
sides and stayed green. Replaced with a golden literal of the sweep's win/loss
pattern, which moves if the key, the chance formula, the take band or the
comparison observably changes.

Worth stating plainly, because it is the kind of thing that looks like a gap:
**`<` versus `<=` is measure-zero against a hash.** No roll ever equals the
chance exactly, so the two are not separately observable and no honest check can
distinguish them. Claiming otherwise would be the tautology again in costume.

### A canon divergence, frozen rather than fixed

Canon scales Boost heat **0.5 / 1 / 2** by tier (game-core.js:2260). This build's
`_apply_heat` takes an `int`, so the call site passes **1 / 1 / 2** — a tier-1
lift makes double canon's heat — and the comment above that call still says 0.5.

A freeze pass pins what is. The assertion names it as a known divergence, so the
day somebody corrects it the suite says why it changed rather than going quietly
red. Fixing it is a balance change and belongs in its own slice.

### My own tests were on the wrong path again

First run of the new section produced **320** `_require_dispatch` warnings: the
fixtures called `boost.handle()` and `stickup.handle()` directly, and those
systems write to Curtis, whose mutators refuse outside a dispatch. So the tests
were exercising a stack the game never produces **and silently skipping the very
writes being frozen** — a freeze pass that froze nothing.

Converted to `gm.dispatch()`, reading outcomes off state rather than returned
dictionaries, which is the more honest question anyway: a win is a win because
the money moved. Down to **4** warnings, all from the ownership test that
deliberately calls outside a dispatch to prove refusal.

This is the third build in a row where that rule earned its keep. It is worth
treating "did my test take the path the game takes" as a standing checklist item
rather than a lesson already learned.

### Sabotage log — 16 faults, all confirmed red

| # | fault | result |
|---|---|---|
| 1 | boost key changed (observable rule drift) | 55 failures |
| 2 | boost skips `mark_criminal_activity` | 2 |
| 3 | fence rate table broken | 4 |
| 4 | outcome pool order reversed | 2385 |
| 5 | `ADVANTAGE_THRESHOLD` 3 → 4 | 231 |
| 6 | `CATASTROPHE_IMMUNITY_THRESHOLD` 6 → 7 | 15 |
| 7 | stickup drops `broadcast_outcome` | 10 |
| 8 | heat rounded to int | 1 |
| 9 | heat clamp removed | 1 |
| 10 | cash added on stickup failure | 23 |
| 11 | `crew_assignments` dropped from `PERSIST_FIELDS` | 6 |
| 12 | `SAVE_VERSION` bumped with no migration arm | 10 |
| 13 | `clears_curtis_filter` removed | 4 |
| 14 | dispatch-ownership guard removed | 1 |
| 15 | `day_ending` emitted after the increment | 8 |
| 16 | stickup draws from the market stream | 10 + completeness floor |

Three needed the checks fixed first (1, 2, 16). One sabotage was itself a no-op
before it was corrected: `make_stream(cursor).state` is identity for a nonzero
cursor, so the first attempt at 16 never drew from the stream at all. **A
sabotage that fails to break anything is not evidence the check works** — it has
to be verified as a real fault before its result means anything.

## FS-001.8: the slice becomes playable  (added 2026-08-21)

Presentation only — no new mechanic, no new screen. What changed is that the
delegation slice can now be reached, understood and used from the screens that
already existed. **Parity 7308 → 7400 checks, 0 failures.**

### A preview that cannot lie

FS-001.6 declared `spend_limit` / `stop_reason` on `operation_summary()` and left
them null; FS-001.7 filled two of them and left cash/storage preview open,
because the substrate had no business knowing what "storage" meant. This is where
it gets answered, and it is answered by **asking the adapter** rather than by the
screen working it out.

The mechanism matters more than the fields. `select()` used to decide and buy in
one pass. It is now split: `plan()` decides, `select()` executes what `plan()`
returned, and `preview()` is `plan()` with the cash context attached. **The
preview and the purchase are the same code path**, so they cannot drift. A
preview that re-derives its answer is a second implementation, and the day it
disagrees the player is shown a number the game does not honour.

The suite holds them to each other directly, at every budget the player can pick.

### The spend control is derived, not authored

Rather than offering round numbers, the screen asks the adapter for
`spend_options()` — the running total of taking 1, 2, … up to her rank cap,
computed off the real board. Every button shows a budget that buys exactly what
it says, and the fixtures check the boundary in both directions: a dollar less
buys one fewer.

That also keeps the rule intact. The UI is choosing between answers the systems
layer produced; it is not inventing prices.

### Consumption had made itself invisible

FS-001.2 filters consumed listings out of the POOL before generation, which is
canon. The consequence nobody had looked at until there was a second buyer: a
taken listing does not grey out, it *vanishes*, and the board reshuffles around
it. Two people working one board would have watched items evaporate.

The screen now renders an `ALREADY GONE TODAY` section from the consumption
record — the board cannot answer this, because as far as it is concerned those
items were never generated. Each row is attributed: **PHERRIS PICKED THIS UP** or
**YOU PICKED THIS UP**, derived by matching `taken_today()` against her selection.

### Her holdings show no sell button at all

Not a disabled one. A greyed-out SELL implies something you could do if a
condition changed; nothing changes this before tonight and the system refuses it
outright. The row reads **WITH PHERRIS · SETTLES AT NIGHT** and offers nothing.
Same rule the Crew screen already follows at the top of the rank ladder.

### The night result was disappearing

Once the day rolls over the assignment is yesterday's, the panel correctly goes
back to offering her, and the settlement existed only as two lines in an activity
feed that was already scrolling away. **The money arrived while the player was
asleep and they had no way to see what it was.** `last_assignment()` is a
separate reader — deliberately not a relaxation of the day-scoped
`assignment_for()`, because the day scope is load-bearing — and the panel now
carries a `LAST RUN · 2 moved for $128 · +$68` line.

### A live bug on `main`, found by rendering a screen

PR #40 split Exposure's private ledger accessor into `_ledger_for_write` as part
of making Exposure read-only during observation. `ui/screens/people.gd` kept
calling `_ledger`. **Every NPC row on the People screen has been erroring since
that merge** — ten script errors per render — and the screen silently fell
through to "Knows nothing about you yet." for everyone.

Nothing caught it because nothing in the suite had ever rendered a screen. Every
check tested the reads a screen is built on; none tested that a screen could
consume them.

So the suite renders one now. It is not a layout test — the interactive pass at
375×812 covers that — but it asserts that a screen fed real state produces the
content that state implies. Sabotage 11 puts the old accessor back and it fails.

### Sabotage log

Eleven faults, all confirmed red. **Three passed on the first attempt**, and all
three were weak checks rather than working code:

- **The cash test only covered "cannot afford anything".** That passes whether or
  not the plan tracks what it has already committed. The case that bites is
  *enough for the first item, not for both* — a plan that forgets its running
  total promises a spend the player cannot make.
- **The undiscovered-preview test cleared discovery after assigning her**, so the
  preview was already null for the other reason and discovery was never tested.
- **The People screen was not covered at all**, which is how the bug above
  reached `main`.

| # | fault | result |
|---|---|---|
| 1 | preview re-derives instead of using `plan()` | 7 failures |
| 2 | `select()` re-decides instead of executing the plan | 13 |
| 3 | preview ignores stock already held | 5 |
| 4 | preview ignores cash spent so far | 0 → **4** |
| 5 | `storage_free` reports raw capacity | 2 |
| 6 | `spend_options` offers budgets past the cap | 1 |
| 7 | summary previews even once she is out | 1 |
| 8 | summary previews an undiscovered operation | 0 → **1** |
| 9 | `last_assignment` day-scoped like `assignment_for` | 1 |
| 10 | preview mutates (spends cash) | 1 |
| 11 | `people.gd` back to the removed accessor | 0 → **2** |

### Verified at 375×812

Every operation state rendered and read back: available (with the storage/cash
line and both spend buttons), assigned, settled, blocked by the afternoon,
blocked by unpaid wages, undiscovered (panel absent entirely), low cash, and full
storage. Widest laid-out element 375px in every state; no tap target under 44px.

## FS-001.7: Pherris runs the board  (added 2026-08-21)

The first thing a crew member does that you can measure in dollars. She picks
listings off the same board the player sees, pays in the morning, and settles at
night through the same path a personal sale uses. **Parity 7228 → 7308 checks,
0 failures. No schema bump.**

### Two moments, not one

She buys when the assignment is made, not at settlement. The money leaves when
the stock is picked up, which is what makes an assignment a real commitment
rather than a bet — the cash is gone before anyone knows what the items are
worth.

It also closes an exploit a settle-time purchase would open: assign her, spend
the day's cash elsewhere, and have her buy with money that was never there.

### The line delegation must not cross

Settlement runs through `nine07list.settle_holding(index, mode)`, one path for
both modes. What is **identical**: the realised value (keyed on the item and the
day it was bought, so the same object fetches the same price whoever holds it),
the `financial / 907list_profit` rows, and the `market_meetup` outcome.

That last part is the one worth defending. It would be easy to treat a delegated
sale as quieter because the player was not there — but the money still moved and
the block still counts it. Canon's rule is that what reaches Curtis is decided by
the VALUE through his volume filter, not by whose hands carried it. **Making
delegation launder visibility would turn a crew member into a way to hide
income**, which is a different game.

What is **not** shared: a slot, Intelligence training, and `list_flips`. All
three are the player's own experience of the trade. A slot is spent by whoever
went to the meet. Pherris reading value well teaches the player nothing. And
`list_flips` is what earns Broker standing — *your* reputation on the board, not
hers.

Those three are the leak this build had to not spring. Delegation that fed
progression would make the crew member strictly better than doing the work
yourself, and the tier ladder would climb while the player learned nothing. The
suite checks all three, and checks the control case — the same sale by the player
DOES move them, which is what stops the assertions testing an inert path.

### She buys cheap first, and refuses rough

Cheapest-first is a choice, not an accident: a fixed cycle budget spread across
more items is more chances at a good realised value, and the 907List's whole
mechanic is that value is hidden. Volume beats one expensive guess. It also means
a small spend limit produces a day's work rather than one purchase.

Rough-condition stock is the one piece of taste in the selection. Broker standing
is built on clean deals and a rough item is how a dispute happens.

Stop reasons are checked in a fixed priority — **capacity → nothing acceptable →
spend limit → cash → cycle cap** — so the reason reported is the most fundamental
thing in her way rather than whichever happened to be true last. With both an
empty wallet and a full shelf, the shelf is the answer.

### One bug from FS-001.6, found by using it

`crew_operations` kept its adapter registry inside `crew_operation_state`, which
is **persisted**. `_apply()` replaces that dictionary with the saved copy on
every load — and a saved copy can never contain an object. The adapter silently
vanished on every CONTINUE RUN, and settlement would have quietly returned null
forever.

It lives in a runtime dictionary now. The persisted `adapters` key stays where it
is so no schema bump is needed; it is vestigial and nothing reads it. Sabotage 11
puts the registry back and 28 checks fail.

### Two checks that could not tell the difference

Thirteen sabotages, all eventually red. Two passed on the first attempt, and both
were weak checks rather than working code:

**The tie-break test used a three-item board.** GDScript's sort leaves an array
that small alone, so removing the position tie-break changed nothing and the
check could not tell the two implementations apart. Introsort only permutes equal
keys once the array is big enough — the case now uses a twenty-item board of
identical prices, and without the tie-break the order comes back fully scrambled.

**The idempotency test never reached the adapter's guard.** The coordinator
already refuses to settle a settled assignment, so emitting `day_ending` again
stops one layer early. The adapter's own guard is defence in depth and was
untested; it is now called directly. Paying a day out twice is the kind of bug
that surfaces as a number nobody can account for.

### The tests were taking a path the game never takes

Worth recording as a method note. PR #40 added `_require_dispatch` ownership
guards to the Curtis and Exposure mutators. A clean parity run was printing **24**
of those warnings — from this build's own tests, which emitted `day_ending` by
hand to settle without moving the clock.

Real gameplay always crosses the night through `dispatch`, so the guard passes.
The tests were exercising a stack the game never produces, which is exactly the
false signal that guard exists to raise. They cross the night through dispatch
now, and the leakage assertions are restated as *"settling adds nothing on top of
what the night cross itself costs"* — with an empty-cross control to prove the
comparison means something. **Zero warnings in a clean run.**

Sequencing consequence worth knowing: dispatch autosaves on `state_changed`, so
the reload test now snapshots the save bytes before settling. Otherwise the
pre-night save is overwritten by the post-night state and "load the save from
before the night" quietly stops meaning that.

| # | fault | result |
|---|---|---|
| 1 | rough-condition filter removed | 5 failures |
| 2 | stop-reason priority swapped | 3 |
| 3 | Intelligence trains on the delegated path | 2 |
| 4 | `_mark_taken` removed from her purchases | 3 |
| 5 | delegated settlement advances time | 2 |
| 6 | manual-sell guard removed | 2 |
| 7 | selection sorts dearest first | 3 |
| 8 | tie-break dropped | 0 → **1** after the board was widened |
| 9 | cycle cap ignored | 8 |
| 10 | spend limit allows crossing the line | 3 |
| 11 | adapter registry back in persisted state | 28 |
| 12 | settlement not idempotent | 0 → **1** after testing the adapter directly |
| 13 | delegated sale counts a flip | 2 |

### No schema bump, and why that is safe rather than lucky

Her purchases live in `list_holdings` (already persisted, already carrying the
`source` stamp the v6 → v7 migration made room for) and in
`crew_assignments[crew_id]`, which persists whole. The adapter registry is
runtime and deliberately not saved. Nothing new needed a field.

## FS-001.6: the day that ends before the clock moves  (added 2026-08-21)

The delegation lifecycle, with no delegation in it yet. A `day_ending` signal, a
coordinator that owns discovery / assignment / settlement, and nothing that
knows what any operation actually does. **Parity 7121 → 7211 checks, 0 failures.
Save schema v6 → v7.**

### Two signals, because the port already has listeners written against each

`day_ending(ended_day)` fires while the clock still reads the day that is
finishing. `day_crossed` fires after the increment and keeps its existing
meaning — listeners still see the NEW day.

This is canon's shape, not an invention. `confirmDayEnd` (game-core.js:6601)
does every piece of night settlement above the `run.day = oldDay + 1` line, and
canon's own comment on `applyAttendance(state, oldDay)` says why the day is a
parameter rather than a read:

> *so the rung does not depend on sitting above the `run.day = oldDay + 1` line
> further down.*

The port had already discovered this the hard way: `jobs.gd` and
`obligations.gd` both derive `gs.day - 1` today because `day_crossed` fires on
the wrong side of the increment for what they need. Rather than re-time
`day_crossed` and break both, `day_ending` is added beside it. New settlement
gets the ending day handed to it; nothing existing moves.

**The ordering is recorded, not trusted.** A probe subscribes to both signals
and writes down what the clock read at each, so the assertion is about observed
behaviour rather than about reading the source and agreeing with it.

### What the coordinator refuses to know

`crew_operations.gd` knows which operations exist, whether they are discovered,
whether one can be assigned and why not, who is booked today, and when to hand a
pending claim to whoever owns its domain.

It does not know what running the board means, what it buys, what it costs, or
how it decides to stop. **The moment a `if operation_id == "907list_run_board"`
appears in that file, the substrate has stopped being one.**

### Discovery is one-way; assignment is not

Two requirement lists, not one, because they answer different questions.

`907list_run_board` becomes DISCOVERED at Broker tier with Pherris active and
loyal — and stays discovered when her loyalty slips. You learned she can do this.
What you lose is the ability to ASSIGN it, which is evaluated separately.
Collapsing the two would make forgetting a capability the punishment for a bad
week.

Assignment order is the authored priority of the blockers: "she is not on the
crew" outranks "you already used her today", which outranks "it is the
afternoon". The evaluator short-circuits, so the player is told the most
fundamental thing that is wrong.

### Settlement closes the claim even with nobody to run it

With no adapter registered, a pending assignment settles to a **null result**
rather than staying pending. A claim on a day that has ended is finished by
definition — and leaving it open would block that crew member tomorrow through
`crew_unassigned_today`. The substrate has to be correct when it is empty.

### The migration's one transform is ownership

`crew_assignments` and `crew_operation_state` are additive and default in. The
interesting part is `list_holdings`: every holding in a v6 save was bought by
the player, because there was no other way to buy one. That is stamped now
rather than inferred once delegated buying makes it ambiguous — **cheap to do
today, impossible to reconstruct afterwards.**

### The harness could pass by running less of itself

Fourteen sabotages, all eventually confirmed red. Two of them initially reported
**PASS** — on a smaller check count.

A runtime error inside a check (indexing a null, a bad cast) aborts the
enclosing function and returns to the caller, which carries on with the next
section. The run then reports PASS with a smaller total and nothing notices.
Removing the planning-window gate and removing the settled-guard both did
exactly that: they broke a check so badly it could not run, and the suite called
that success.

Two fixes, and the second is the one that generalises:

1. The checks that crashed are null-safe now, so they fail instead.
2. **`MIN_CHECKS`** — the suite asserts its own completeness. The floor only
   ever moves up; it moving down is the signal.

This is a harness-level hole that has existed since Phase 5 and would have
silently weakened any future section. It is worth remembering that *a green
result is only as trustworthy as the number of checks behind it.*

| # | fault | result |
|---|---|---|
| 1 | `day_ending` never emitted | 2 failures |
| 2 | `day_ending` fires AFTER the increment | 3 |
| 3 | discovery re-evaluated instead of latched | 3 |
| 4 | planning window not enforced | 0 → **2** after the null-safety fix |
| 5 | double assignment allowed | 1 |
| 6 | reconcile removed from dispatch | 2 |
| 7 | v6→v7 does not tag holding source | 1 |
| 8 | settled guard removed | 0 → **2** after the null-safety fix |
| 9 | `_facts()` hands over stale assignments | 1 |
| 10 | load-time reconcile removed | 1 |
| 11 | `crew_assignments` dropped from PERSIST_FIELDS | 3 |
| 12 | settlement ignores `ended_day` | 1 |
| 13 | discovery requires only the tier | 2 |
| 14 | a section forced to abort (tests MIN_CHECKS itself) | 1, at 7182 checks |

### The port seam, checked before it could bite

FS-001.5's finding applied forward. This build represents "no assignment" as an
**absent** dictionary key and a stale claim as one whose `day` does not match —
neither of which any oracle-recorded fixture can express. `_facts()` is the one
place live state becomes evaluator input, so it carries its own checks: absent
reads as free, live blocks, yesterday's does not, and the `-1` wage sentinel
survives the trip.

Sabotage 9 is the one that matters there: handing the evaluator the whole
assignments dictionary instead of only today's would strand a crew member
permanently on the strength of a booking they already finished.

## FS-001.5: Crew extensibility — structure without gameplay  (added 2026-08-21)

No new gameplay. Crew members have rank NAMES instead of tier numbers, curves
clamp instead of falling off, and a shared eligibility evaluator exists for
FS-001.6 to build on. **Parity 6702 → 7121 checks, 0 failures. No save schema
bump.**

### The bug hiding in a feature nobody can reach

`heat_multiplier()` read `DESHAWN_HEAT_REDUCTION.get(tier, 1.0)`. That table has
three entries. At rank 4 the lookup misses and returns the neutral `1.0` —
meaning **a promotion would have removed the heat reduction Deshawn had already
earned.** `defense_multiplier()` had the same shape.

Nothing can reach rank 4 today, which is exactly why it had to be fixed before
something can. A benefit that silently vanishes on promotion is not the kind of
bug that gets noticed in review; it is the kind that ships and gets diagnosed
six builds later as "Deshawn feels useless at high rank."

Canon's `curveValueForRank` is the general answer and it is ported whole: a rank
above the highest authored entry **keeps that entry**. Clamping up is the only
safe direction for a curve the player has already paid for.

### The evaluator, and why it reads nothing

`systems/requirements.gd` answers one question — "can this happen yet, and if
not, why" — and returns it structured:

```gdscript
{ok, blocker_code, blocker_copy_key, current, required}
```

`current` and `required` ride on the blocker, so a caller can say "needs loyalty
6, has 4" without knowing what loyalty is. `blocker_copy_key` is the translation
seam: presentation swaps wording without touching eligibility.

**It reads ONLY from the `facts` dictionary passed in.** No GameState, no
autoloads, no `Engine.get_main_loop()`, no `setup()`. It cannot be tested wrong
because it cannot see anything a test does not hand it.

Ten requirement types ship, and **unknown types fail closed**. A typo in a
requirement record must never read as "no gate here" — an unrecognised gate is
an impassable one, which is the only safe direction for code whose whole job is
deciding what is allowed.

### Two divergences from the build brief, both to the oracle

**1. The capability table is Pherris only.** The brief listed capabilities for
Eli, Tone and Deshawn as well. Canon (`src/data/crew-progression.js`) has none
for them, and its own test asserts `crewHasCapability("tone", ...)` is `false`.
Inventing three would hand FS-001.6 data it then has to migrate away from — and
the brief's stated reason for the table is that FS-001.6 can reference it
*without adding data*. Canon's shape is also richer: `{min_rank,
max_cycles_by_rank}` rather than a flat array, so a capability is gated on rank
rather than merely owned.

Tone's defense multiplier and Deshawn's heat reduction are **presence effects**,
not delegable operations — a different mechanism, already shipped, untouched.

**2. Fact keys are snake_case here, camelCase in the oracle.** The oracle reads
`facts.currentDay` / `crew.recruitedDay`; this build's crew records already
carry `recruited_day` and `wage_missed_since`. Translating at every future call
site would be worse than translating once, in the fixture generator, where it is
recorded as data. **The output shape is byte-identical**, including its
snake_case `blocker_code` — that half is a contract, not a convention.

### The sabotage run found a hole in its own coverage

Sixteen faults injected. Fourteen went red immediately. Two did not, and both
mattered:

**`payroll_not_delinquent` ignoring the `-1` sentinel changed nothing.** Canon
records "no missed wage" as `null`; this build records it as `-1`. The evaluator
accepts both — a documented, deliberate superset. Removing that guard broke
**zero** checks, because every fixture came from the oracle and the oracle can
never produce a `-1`.

That is the failure mode of oracle-only fixtures: they prove agreement with
canon and say nothing about the port's own shapes. Fed a real crew record, an
unguarded evaluator computes `current_day - (-1)` days delinquent and silently
blocks every gate. It is now covered by a check that drives the live record
straight out of GameState, and the re-run fails on it.

**The malformed-`proofs` check could not be made to fail.** `crew_proofs()`
returns a typed `Dictionary`, so a guarded read and an unguarded one both yield
`{}` — the engine recovers the type error either way. A check that cannot go red
is not coverage, so rather than bank one, it was **removed** and the reason
written where it was. The guard stays in the code; the falsifiable half — an
absent key — is what the remaining checks pin.

| # | fault | result |
|---|---|---|
| 1 | recruit does not create `proofs` | 2 failures |
| 2 | `heat_multiplier` falls off at rank 4 (the old bug) | 3 |
| 3 | `defense_multiplier` falls off at rank 4 | 3 |
| 4 | `evaluate_requirements` does not short-circuit | 15 |
| 5 | result omits `blocker_code` | 26 |
| 6 | wrong copy-key prefix | 25 |
| 7 | missing `recruited_day` reports 0 tenure, not INF | 4 |
| 8 | payroll ignores the `-1` sentinel | **0 → 2 after the gap was closed** |
| 9 | unsupported requirement type fails OPEN | 3 |
| 10 | loyalty boundary uses `>` instead of `>=` | 6 |
| 11 | curve does not clamp above the authored range | 22 |
| 12 | rank label does not clamp | 2 |
| 13 | capability table gains the brief's invented Tone entry | 3 |
| 14 | `crew_capacity()` returns 3 | 2 |
| 15 | `at_top_rank` always false | 3 |
| 16 | malformed-`proofs` guard removed | **un-falsifiable — check withdrawn** |

### Ranks 4-6 have names and no ladder

`RANK_LABELS` runs to six. `CREW_TIER_REQUIREMENTS` stops at three. That gap is
the shape of this build: the labels exist so the curves have somewhere to clamp
to, and so a later slice adds a *rule* rather than a *concept*.

The Crew screen respects it. At Trusted the promote control is **hidden, not
disabled** — a greyed-out button reading "NOWHERE HIGHER TO GO" advertises a
ladder the player cannot climb, which is a promise this build does not keep. Pay
expands to fill the row instead. The screen asks `at_top_rank()` rather than
matching on the blocker string, because control flow on a copy string breaks the
first time somebody rewords it.

### No save bump, and why that is safe rather than lucky

`proofs` lands inside `crew_records`, which is already in `PERSIST_FIELDS` and
already round-trips as a Dictionary. A record saved before the field existed
reads `{}` through `crew_proofs()` — canon's mergeDefaults pattern applied
inside a persisted dictionary rather than at the top level. Both the absent-key
path and a legacy record that still promotes cleanly are asserted.

### One note on the oracle checkout

`src/systems/requirements.js` and `src/data/crew-progression.js` arrived in web
PR #98, one commit ahead of the oracle checkout's `main`. The generator extracts
those two files to a scratch directory and requires them from there rather than
moving the checkout's HEAD, since every other fixture is recorded from `main`.
The dance is documented at the top of that generator section; when PR #98 lands
on the oracle's main, delete it and require the files directly.

## FS-001.2: 907List opportunity ownership — and the filter that was missing  (added 2026-08-21)

A listing was a shelf, not an opportunity. You could buy the same space heater
until the money or the capacity ran out, and reopening the screen handed it back
every time. **Parity 6641 → 6702 checks, 0 failures. Save schema v5 → v6.**

### What a listing is now

Canon tracks `nineZeroSevenList.taken` as `{day, ids}` and filters the board
POOL by it. Two details in that sentence are load-bearing and both are easy to
get backwards:

**The filter runs on the pool, before generation — not on the output.** Buying an
item does not subtract a row from the board; the board is regenerated from a
smaller pool, so its remaining composition moves with it. Day 2 shows
`[space_heater, dresser]`; take the heater and it shows `[winter_coat, dresser]`,
not `[dresser]`. That is canon's `listingSlate` and it is pinned as a literal in
the fixtures, because it is exactly the behaviour a reasonable person would
"fix" by mistake.

**The day reset is lazy** — keyed on `list_taken.day` rather than a `day_crossed`
handler. Canon does it this way and the reason shows up under load: a save
written on day 4 and loaded on day 9 is correctly empty with nothing having run
in between, and no ordering question arises about whether consumption clears
before or after the systems that settle on a day cross. A handler would have
introduced one.

### The prerequisite nobody asked for

Task 3 was "route the completed flip's financial observation through
`Curtis.broadcast_tracked()`." Doing only that would have been wrong.

Canon gates Curtis's network ear behind `clearsCurtisFilter`: only `violence`,
`defiance` and `growth` clear it by category, and `financial` clears it on volume
alone at **$200**. `exposure.gd` had that filter listed in its header as NOT
ported. Broadcasting a flip's profit on the network without it means **every $40
flip raises Curtis's awareness** — the exact opposite of the design, and canon
says so in its own comment: *a big 907List day is exactly how this is meant to
reach him, and a $40 space heater is exactly how it is meant not to.*

So the filter is ported here, as a dependency of the feature rather than as
scope creep.

### It immediately found a bug I shipped in 5e

Build 5e's HANDOFF entry states that a catastrophic robbery raises Curtis by
**four** — three from the tier, one more because its `network` row lands on him.
That was true, and it was wrong.

The row is `heat_exposure`, which is **not** one of the three categories that
clear his filter. In canon it never reaches him and never credits the point. The
port had been over-crediting Curtis on every catastrophic robbery since 5e,
purely because the filter was missing. Verified directly against the oracle:

```
clearsCurtisFilter({type: "heat_exposure"})  →  false
```

The number is three. The fixture now derives the expected listener count through
`clears_curtis_filter` rather than hardcoding either answer, so the check moves
with the rule instead of having to be re-taught.

### The migration is the first one that reconstructs

Every arm before this defaulted: a v4 save has no attributes, and canon's
fresh-run values genuinely ARE its history. v5 → v6 cannot do that. Defaulting
`list_taken` hands the player back an opportunity they already spent.

So the arm reconstructs what it can prove. **A holding bought on the current day
is proof that listing was taken today**, and holdings persist, so those ids come
back exactly.

**The named limit:** a listing bought AND sold on the same day leaves no trace in
a v5 save. The holding is gone and nothing else recorded the purchase. Those ids
are unrecoverable and are not guessed at — the player gets that one slot back for
the rest of the loading day, and every day after is correct.

The alternative was suppressing the whole board for the loading day, which
punishes every v5 save to be exact about a case most never hit. **Recovering what
is provable and naming what is not** is the honest trade, and the limit is
asserted in the fixtures rather than only commented.

### A pre-existing generator defect, pinned rather than fixed

Day 3 returns one listing where tier 1 asks for two. The cause is real: the board
walks `seeded_int_range` over keys differing only in a trailing counter, and
FNV-1a over that shape clusters hard — all 40 guard keys for day 3 hash into the
same bucket, so the dedupe never finds a second item.

```
907list:3:0 → 0.0463    907list:3:2 → 0.0541
907list:3:1 → 0.0424    907list:3:3 → 0.0502   → floor(x * 8) == 0 every time
```

Canon does not have this because it `seededShuffle`s the whole pool instead of
sampling it with retries. Fixing it moves every board in every existing save, so
it is **filed, not fixed** — and the short day-3 board is now an explicit
assertion, so the day someone fixes it, the fixture says so out loud.

### Sabotage log

Eleven faults injected, every one confirmed red before revert:

| # | fault | result |
|---|---|---|
| 1 | purchase does not record consumption | 12 failures |
| 2 | board does not filter consumed ids | 9 |
| 3 | no system-level duplicate guard | 7 |
| 4 | day reset ignored | 2 |
| 5 | `list_taken` dropped from `PERSIST_FIELDS` | 8 |
| 6 | v5→v6 arm defaults instead of reconstructing | 3 |
| 7 | Curtis network filter removed | 4 |
| 8 | completed flip broadcasts nothing | 4 |
| 9 | volume threshold 200 → 100 | 1 |
| 10 | board seed key changed | 17 |
| 11 | migration recovers all holdings, not just today's | 1 |

Sabotage 7 is the one worth keeping: it reproduces the 5e bug exactly
(`stickup catastrophic curtis awareness: got 4, want 3`), which is how you know
the correction is real and not a fixture edited to match new behaviour.

Sabotage 9 failing on exactly one check — the `$199` boundary — is the shape a
threshold test should have. If moving a constant by 100 had failed nothing, the
boundary was never being tested.

## Build 5e: tiered outcome resolution — the resolver Attributes deferred  (added 2026-08-21)

`systems/attributes.gd` named this port as explicitly deferred, in writing, with
the reason: *"porting the resolver now would ship a large untested branch with
no caller."* It has callers now. **Parity 2399 → 6628 checks, 0 failures.**

A risky action no longer resolves `roll < chance`. It resolves into one of four
tiers — **clean / messy / failure / catastrophic** — and the tier decides the
money, the heat, the injury, what Curtis makes of it, and what the block ends up
knowing.

### The idea, and why it is not a percentage bonus

Every wired roll already computes a context-sensitive chance out of heat,
resistance, attributes and district. Canon does not throw that away for a flat
weighted table — it **splits that chance across the tiers**. `success` divides
the winning half, `failure` divides the losing half.

The attribute then reads the pool with tabletop advantage rather than a bonus to
a number nobody can see:

- **Combat 3+** rolls twice and keeps the better tier
- **Combat 6+** has catastrophic removed from the pool entirely

That shape is deliberate: one effective level is invisible at 0-1 and 3-4 and
decisive at 2 and 5. It is also what makes crew backup (`bonus`) mean something
specific — *it does not make you better at fighting, it takes the worst ending
off the table.*

Measured through the real surface, 1000 seeds per row:

| Combat | chance | clean | messy | failure | catastrophic |
|---|---|---|---|---|---|
| 0 | 0.54 | 365 | 205 | 353 | **77** |
| 1 | 0.62 | 424 | 220 | 303 | **53** |
| 2 | 0.70 | 447 | 263 | 243 | **47** |
| 3 | 0.78 | 688 | 268 | 44 | **0** |
| 6 | 0.86 | 755 | 241 | 4 | **0** |

### The keystone is the observation table, not the roll

`OUTCOME_OBSERVATIONS` is what this build is actually for. Outcome quality
decides the Exposure footprint: **doing crime well does not make you invisible,
it makes you quiet.** A clean robbery still writes its financial row — it just
travels on `direct` instead of reaching the network. A catastrophe goes out on
two channels because somebody called it in.

Most tiers in that table are empty, and that is not an omission. Canon measured
a row for every talk-down and every night at the counter as moving every
disposition up half a band and dragging story pacing with it. What lives in the
table is only the difference between doing a thing well and doing it badly.

One consequence worth knowing: a catastrophic robbery raises Curtis by **four**,
not three. Three from the tier, and one more because its `network` row genuinely
lands on him — that compounding is canon's, in `broadcast_tracked`.

### Two things that are easy to get wrong, both load-bearing

1. **The resolver reads the RAW attribute, not `compat()`.** The compatibility
   offset exists for the pre-v1.10 inline `(x - 2) * k` terms and nothing else;
   canon's own comment says anything routed through `resolveWithAttribute` reads
   the stored value and carries no inline term. Feeding `compat()` in would
   shift both thresholds down a level. The parity fixture pins this: the sabotage
   of moving `ADVANTAGE_THRESHOLD` by one produces 201 failures.
2. **Pool ORDER is load-bearing.** `seeded_pick` walks cumulative weight in array
   order, so a pool with the right entries in the wrong order resolves different
   tiers from the same hash. The fixture checks order, not just content — a
   content-only check waves this through, and reversing the pool produces 2385
   failures.

### Stickup is the vertical proof

| tier | cash | heat | health | Curtis |
|---|---|---|---|---|
| clean | full take | target × 0.5 | — | +1 |
| messy | full take | target × 1.0 | -5..-10 | +2, criminal |
| failure | $0 | max(1, heat-1) | — | +1 |
| catastrophic | $0 | target × 1.5 | -15..-25 | +3, criminal (+1 network) |

`_apply_heat` takes a float now. Rounding it is exactly what would flatten the
difference between a quiet take and a loud one on a 1-heat target.

The hand-rolled `violence / stickup` broadcast is **gone**. `broadcast_outcome`
is the single entry point for post-resolution Exposure effects, and the parity
check asserts no legacy row is written.

**This consequence spread is the port's, not canon's** — canon's failure branch
runs through an arrest system, dirty cash, district heat weighting, a witness
roll and a retaliation queue, none of which this build has. What is oracle-exact
is the thing that had to be: the tier pick. Same seed, same chance, same Combat,
same tier as the web build, proven across 715 grid resolutions, 400 advantage
pairs and 1000 immunity seeds.

### Two surfaces were NOT converted, and that is the oracle's call

The brief listed boost and shark for conversion. The oracle does not tier
either, so converting them would have invented behaviour in two shipped surfaces
with nothing left to check them against:

- **Boost** (`game-core.js:2248`) is still a plain `roll < chance`. Getting
  caught is not a tier in canon, it is a **scene** — the failure hands off to the
  consequence-encounter engine with the take still in play, and *that* resolves
  on this pipeline as `confrontation` / `escape` / `negotiation`. The tiers a
  blown lift deserves already exist in `OUTCOME_SHAPES`; what is missing is the
  encounter engine that reaches them.
- **Shark**'s default check is not an action the player takes. It has no shape in
  `OUTCOME_SHAPES` and never touches `resolveAction` — the player is not in the
  room, and there is no read to make about a phone that does not ring.

Both files now carry that reasoning in their headers so the next person does not
re-open the question from scratch.

### Jobs and 907List, which canon DOES tier

- **Jobs.** Applying used to be a formality — every application became a job.
  It is a real interview now, read through Charisma:
  `clamp(0.62 - max(0, heat - 4) * 0.04, 0.25, 0.95)`. Heat costs you here too:
  a manager who has heard things is a harder room. Measured, 40 applications
  each: 23 hired at heat 0, 21 at heat 6, **13 at heat 12**.
  `job_interview` is the one shape in the table with **no catastrophic tier** —
  the worst case of an interview is not being hired, and canon says so in the
  data rather than in a special case.
  *Divergence:* canon queues the application and resolves it two slots later
  over the phone, then *offers* the job. That pipeline does not exist here, so
  the interview resolves at apply time, keyed on the day and slot applied —
  which is exactly what canon keys on.
- **907List.** A sale is a handoff in a parking lot, resolved on `market_meetup`
  at canon's flat 0.75. The thing to understand: **the tier has no mechanical
  consequence.** Canon leaves the robbery roll alone so the risk number the page
  shows stays honest, and the money is settled before the tier is picked. What
  the tier decides is the Exposure footprint and nothing else.

### The parity work is where the real cost was

4229 new checks, all replayed from oracle truth recorded by
`scripts/parity/gen_fixtures.mjs`. They live in their own file
(`tests/parity/fixtures/outcome_resolver/`) because they are a different kind of
fixture: `rng_fixtures.json` records primitives and system reads, this one
records whole actions resolving.

Every new check was **sabotage-tested before being trusted**. Reversed pool
order → 2385 failures. Advantage threshold off by one → 201. A single weight
typo in one shape → 10. Dropping `broadcast_outcome` → 10.

**One of them was flaky and had to be fixed.** The reload check originally
compared a pre-save injury roll against its post-load replay. Swapping
`seeded_int_range` for `randi_range` *passed* on the first sabotage run — a
5..10 band matches its own re-roll one time in six. The fix is not more samples
alone: the injury is now held to the exact value its key hashes to, which is an
assertion luck cannot satisfy. Re-sabotaged three times: fails every time.

The lesson generalises. **A determinism check that can pass by coincidence is
not a determinism check**, and the only way to find out is to break the thing on
purpose and watch.

### The market stream never moves

Outcome resolution is keyed and hashed, never drawn from `rng_state`. The
xorshift cursor belongs to the nightly market walk and to nothing else — a
resolver that reached for it would desynchronise every price in the run from the
oracle's. Asserted directly: the cursor is unmoved by 100 resolutions and by a
dispatched robbery.

## Phase 5d: Recovery — health finally goes back up  (added 2026-08-20)

Health has been a HUD stat since the first build with nothing in the game able
to raise it. Stickup damage spent it and nothing gave it back. This is the other
half. **Parity 2367 → 2399 checks, 0 failures.** All six of canon's More rows
now ship.

### The ladder reveals itself as the damage justifies it

Canon's subtitle is the design: *"Essential care first; larger options appear
when the damage justifies them."*

| treatment | restores | cost | appears at | time |
|---|---|---|---|---|
| First aid | 18 | $55 | always | **free** |
| Clinic visit | 40 | $135 | health <= 82 | one slot |
| No-Questions Doctor | 75 | $290 | health <= 55 | one slot |

A player at 95 is never shown the $290 option, so **the expensive card arriving
is itself information** about how bad things have got.

First aid costing no time is the load-bearing detail. It is the one thing you
can do mid-crisis, which is what makes the other two a real decision rather than
a formality — and the reason canon has two reducers (`USE_FIRST_AID`, `HEAL`)
for what is otherwise identical arithmetic.

### Lay Low is a trade, not a pause

Heat down 2, one slot gone, and a `discretion` observation filed on Curtis's
network — **going quiet is itself something the neighborhood notices**, and
Curtis is the one lens that reads discretion as information about you. Canon's
warning is on the card and it is the whole point: debt, wages, markets and
Curtis keep moving while the lights are off.

### Two bugs the fixtures caught before the screen did

1. **`lay_low_preview()` returned int and truncated.** Canon's `layLowPreview`
   is `min(heat, max(1, 2 + …))` with no rounding, and heat has been fractional
   since Phase 3e (Deshawn's 0.80 reduction needs it). The first pass promised a
   player sitting at 1.6 a drop of "1". The fixture walks heats that are not
   whole — 0.5, 1.5, 2.4 — which is the only reason it surfaced.
2. **The doctor rendered twice at health 55.** Canon is
   `doctorOpen ? treatment(...) : <div className="card locked">` — the treatment
   card **or** the locked card, never both. `visible_treatments()` returned the
   doctor regardless of whether the contact was open, so a locked run saw a
   buyable $290 card sitting directly above a card saying it was locked.

Both were mine, not canon's, and both were found by writing the check before
trusting the screenshot.

### One named divergence: what opens the doctor

Canon gates it on `base.tracks.recovery >= 2 || npc.mina.trust >= 3`. There is
no base system, and `npc.mina.trust` is a separate counter this port never
carried. What it does have is **Mina's Exposure disposition** — the same
relationship measured a different way — so the gate reads her band reaching
TRUSTED. Taken because the alternative was porting a card no run could ever
reach.

### The More row keeps canon's latch

`features.recovery.available` is `health < 100 || heat > 1 ||
flags.recoveryIntroduced`. The third term is the interesting one: **once
Recovery has mattered it stays on the menu**, so healing back to 100 does not
take away the screen you just used. `recovery_introduced` is that flag, set by
the same read that tests it — which is canon's own arrangement, since
`featureAvailability` runs on every render.

### Not ported, each named

`treatmentCost`'s 10% Street Read discount (the function exists and returns full
price, so the discount has one place to land) · `HEAL_AT_BASE`, the garage
first-aid table · `stats.moneySpent.healing`, which feeds an end-of-run summary
this build has no screen for · `addStreetReadEntry` on a heal.

### Save schema v5

`recovery_introduced` joins `PERSIST_FIELDS`; the v4→v5 arm is additive and a v4
save defaults to false — the flag re-arms the moment health or heat makes
Recovery relevant again, which is what canon's own flag does on a fresh load.

### Verified live (editor run, game log clean)

Fresh full-health run → no Recovery row on More. Health 70 → the row appears;
healed back to 100 → **it stays** (latched). On the screen: health 90 shows
first aid only; 82 adds the clinic; 55 adds the doctor, and with the contact
closed it is the LOCKED card rather than a second buyable one. Four discretion
observations put Mina at BONDED and the doctor card replaces the locked one.
First aid at health 45 → 63, −$55, **clock unmoved**. Clinic → 100 (clamped),
−$135, slot advanced. Doctor while locked → refused. Lay Low → heat 5.0 → 3.0,
one Curtis ledger row, slot advanced. At full health the button reads NOTHING TO
TREAT and disables. Fractional heat 1.6 previews as "lower Heat by 1.6". No
autosave fired and no phantom run was left behind.

## Phase 5c (part 2): the Character screen  (added 2026-08-20)

Street Identity and the screen that reads it. **Parity 2236 → 2367 checks, 0
failures.** More's Character row is live, so five of canon's six rows ship.

### The player is never shown the number

Canon is emphatic and it is the reason the screen exists: an attribute is a
**label** — Green, Capable, Solid, Dangerous, Elite — and the line under the
list says so out loud ("Nobody in Spenard reads you as a number"). Showing 3/12
here would turn a character sheet into a stat block and undo the design. The raw
value lives behind canon's debug flag and nowhere else, so it lives in
`attributes.gd` and nowhere else here.

### Street Identity is cosmetic, derived, and never stored

Canon's own rule: it gates no content, modifies no roll, touches no disposition.
It is your strongest attribute crossed with what you have actually been seen
doing in the last seven days. Canon *retired* a nightly assignment loop with
two-night hysteresis and a stored label to get here, so `identity_profile()` is
pure and writes nothing — **do not cache it back into GameState.**

Two rules in it are easy to get subtly wrong, and both have fixtures on both
sides of the boundary:

1. **A lead of MORE than the balance margin (2) is a lane.** An exact margin is
   still Balanced. Combat 4 / charisma 2 reads "New Face"; combat 5 / charisma 2
   reads "Muscle".
2. **A tie between behaviour columns is not a signal** and falls through to the
   attribute's default label rather than picking one. One violence row and one
   presence row on a Combat 6 player reads "Muscle", not "Shooter" — and giving
   the violence row a count of 2 makes it "Shooter".

`recent_observations()` reaches into the Exposure ledgers, which is the same
reach-across canon makes (`ledgerOf` imported straight into the attributes
system) and for the same reason: identity is a read of what the neighborhood has
seen. Exposure grew a public `ledger_of()` / `npc_ids()` for it rather than
having the caller poke at `gs.npc_ledgers`.

### Three things canon shows here that this build cannot

Each is named on the screen rather than faked:

- **Prior arrests.** Canon's `arrestRecord` reads an arrest/jail system this
  build has never had. The card ships canon's own no-record copy, which is the
  true state of every run here — and the interesting half anyway, because it
  explains what getting booked would cost. It goes live the day an arrest system
  lands with no change to this screen.
- **Recent reputation.** Canon lists the last five `player.behavior.history`
  entries, written by `recordBehavior`. **This is not the People screen**, which
  is what each character makes of you; this would be what *you have done*. Not
  ported; the section shows canon's empty-state line.
- **Legacy background / "Formerly".** Both are save-compatibility cards for runs
  that predate systems this port never had. Nothing they could describe.

### The fixtures cover every arm of the matrix

Fourteen identity cases, all driven through canon's exported `identityProfile` /
`getStreetIdentity` with a hand-built state — the input is supplied, every bit
of the deriving is the oracle's. They cover each lane, each behaviour column,
both sides of the balance margin, the tie rule and the count that breaks it, a
row that has aged out of the 7-day window, the boundary day that has not, and an
unmapped category that must be ignored. The static tables (matrix, descriptions,
behaviour columns) are compared entry for entry so a transcription typo cannot
hide behind correct logic.

### Verified live (editor run, game log clean)

Fresh run → "New Face", all three attributes "Green", the record card empty.
Combat 6 with nothing seen → "Muscle"; add one witnessed violence observation →
**"Shooter"**, and the card's description changes with it. The combat row reads
"DANGEROUS" and never a number. Advance to day 20 so the observation ages out of
the window → back to "Muscle". More's Character row shows the same identity
("SHOOTER") and routes to the screen; BACK TO MORE returns. No autosave fired
and no phantom run was left behind.

## Phase 5c (part 1): attributes — and the bug the pin was hiding  (added 2026-08-20)

The three numbers behind every outcome are real. `systems/attributes.gd` ports
canon's `src/data/attributes.js` + `src/systems/attributes.js`, and the three
surfaces that had been reading a hardcoded constant now read the player.
**Parity 1442 → 2236 checks, 0 failures.**

### The bug: the pin was faithful to the wrong function

Canon's action formulas do NOT read the stored attribute. They read
`compatibilityRating` — `clamp(value + 1, 1, 5)` — and canon says why in its own
comment: those formulas were tuned against a pre-v1.10 attribute that ran 1-5
from a base of **2**, and the v1.10 consolidation moved the stored value onto a
0-12 scale starting at **1**. Reading the stored value directly docks every one
of them a point on day one, which canon measured at roughly **40% of the run
economy**.

Phase 3d pinned `ATTRIBUTE_DEFAULTS` — the STORED default of 1 — where canon
reads the COMPATIBILITY value of 2. Three shipped surfaces have been wrong since:

| surface | canon at default | port had | drift |
|---|---|---|---|
| stickup `(combatCompat - 2) * 0.08` | 0 | -0.08 | tier 1 was **0.54, canon 0.62** |
| boost `(skill - 2) * 0.10` | 0 | -0.10 | tier 1 was **0.70, canon 0.80** |
| shark `- intelligenceCompat * 0.025` | -0.05 | -0.025 | notes 2.5 points likelier to default |

Every robbery was 8 points harder than canon, every lift 10 points harder, and
every note riskier, for two phases. **The pin was not sloppy — it was carefully
wrong.** The header said `ATTRIBUTE_DEFAULTS.combat = 1` and that value is
correct; it just is not the value the formula wanted. Pinning a term at "canon
neutral" means pinning it at what the CALL SITE reads, not at what the data file
declares.

### What is ported

Data tables, the reads (`value` / `compat` / `label`), and growth. `compat()`
carries the offset with a header warning attached to it, because it is the kind
of function that looks redundant right up until someone deletes it.

Growth is canon's log2 taper — `base / log2(sessions + 2)`, halved once the
attribute reaches Dangerous (6). Progress banks as a float and spends a whole
point at 1.0, so **the player is told they got better and never by how much**;
canon keeps the number behind a debug flag and so does this.

`list_flip` is wired: a 907List flip that clears canon's 30% margin
(`PROFITABLE_FLIP_MARGIN`) trains Intelligence, because clearing 30% was a good
READ rather than a lucky sale. It is the only one of canon's nine growth sources
whose venue exists here — the gym's three and The Nile's five wait on their
buildings. **The whole `GROWTH_RATES` table is ported anyway**, because canon's
design is that a new growth source is a row rather than a code path.

### Not ported, each absent rather than stubbed

- **Tiered outcome resolution** (`OUTCOME_SHAPES`, `buildOutcomePool`,
  `resolveWithAttribute`, `resolveAction`). Canon resolves an action into one of
  four tiers — clean / messy / failure / catastrophic — with the attribute
  granting *tabletop advantage* (a second roll at 3, catastrophe immunity at 6)
  rather than a percentage bonus. Every surface here still resolves binary
  `roll < chance`. Converting them also rewrites the Exposure footprint, because
  canon keys `OUTCOME_OBSERVATIONS` off the tier: a clean robbery writes its
  financial row but travels `direct` instead of reaching the network. That is a
  build of its own.
- **Streaks** (`gymStreakBonus`, `nileStreakBonus`, `effectiveAttribute`). Three
  consecutive days at the gym or The Nile are worth +1 effective level. Neither
  venue exists, so the bonus is always 0 and `effectiveAttribute` would be
  `value` with extra steps.
- **Street Identity.** Its only caller is the Character screen — part 2.

### The fixtures are pure oracle, with nothing to prove

`attributeSystem` and the `ATTRIBUTES` data module are **both exported**, so
every fixture value is produced by canon's own functions called directly. There
is no formula copy in this section to verify — the strongest position the
harness has had. What the runner checks: the static tables, the compatibility
offset across the whole clamp range (including floats, negatives and a missing
key), all thirteen label tiers, 315 growth rows (nine activities x seven session
counts x five current values), and **the three real surfaces driven through
their own `chance_for` / `default_probability` at every attribute value**. That
last group is the one that would have caught this bug on the day it shipped.

One fixture note worth keeping: the shark row deliberately uses the
highest-risk borrower on a $500 note. A low-risk borrower clamps to the 0.03
floor at every attribute value, so the check would have agreed for the wrong
reason. The runner asserts the expected value is off both clamps before
comparing.

### Save schema v4

`attributes` and `attribute_progress` join `PERSIST_FIELDS`; the v3→v4 arm is
additive. A save that predates the system defaults to all-1s and zero progress —
and that is the right answer rather than a convenience, because **a run that
predates the attribute system genuinely never trained anything**. The defaults
are its real history.

### Verified live (editor run, game log clean)

Fresh run → all three at 1, compat 2, label "Green". The three formulas read
0.62 / 0.80 / 0.51 where they used to read 0.54 / 0.70 / 0.485. Raising combat
and intelligence to 4 → compat 5, stickup 0.86, boost 0.95, label "Solid".
Growth banked across twelve sessions with the exact canon taper
(0.2000, 0.1262, 0.1000, 0.0861, …) and spent a point on the twelfth, logging
"People read you as Capable now." The cap penalty halves growth at 6 (0.2 →
0.1). An unknown source trains nothing and returns an empty read. **Driven for
real through the dispatch layer**: fourteen days of 907List buys and sells, four
flips sold, three cleared the 30% margin and trained Intelligence with the
correct per-session taper — the fourth did not clear it and correctly trained
nothing. No autosave fired and no phantom run was left behind.

## Phase 5b (part 3): More + Help — the nav is complete  (added 2026-08-20)

**Every bottom-nav cell has a screen.** `screen_base::_wire_nav()` no longer
disables anything. Fifteen screens built; plan-Phase 4 ("Translate Screens")
closes here.

### More is a signpost, not a system

Canon's `More` root (ui.built.js:15809) is a list of `MenuRow`s — title,
description, a right-aligned status, a `›`. Nothing on it computes anything its
destination does not already own; the statuses are one-line reads of live state
so the menu can be scanned instead of walked.

Canon has six rows. Four ship:

| row | status | goes to |
|---|---|---|
| Finances | `$100` / `Debt Day 4` / `Debt due` | Shark |
| Operations | `1 block · 3 soldiers` | Turf |
| Crew | `1/2 active` | Crew |
| Help | `Available` | Help (new) |

### Two rows are dropped, not stubbed

- **Recovery** — no recovery system (treat injuries, lay low to shed Heat).
  Canon itself hides this row until the feature is relevant
  (`features.recovery.available`), so an absent row is the shape canon already
  uses for it.
- **Character** — needs `streetIdentity`, `attributeLabels`, `arrestRecord` and
  the behavior history, none ported. **Attributes are still pinned at canon's
  neutral defaults across every system**, so a Character screen today would be
  five rows of "1" and an empty record. That is the honest reason, and it is
  the same reason the stickup/boost/shark headers already give.

### Routing divergences

1. **Finances → Shark.** Canon's Finances page is cash, debt, Shark notes and
   financial risk, and it opens the Safehouse. No lender system, no safehouse;
   Shark is where this build's money decisions actually live, and cash/debt are
   in the HUD on every screen anyway.
2. **Operations → Turf.** Canon's Operations is a sub-menu: safehouse,
   territory, soldiers, gear, Rob. Territory and soldiers are Turf; Rob is
   Stickup and is already on the Hustle hub; safehouse and gear do not exist.
   **Turf is the only one of the five with no other entrance**, which is what
   makes the row worth having.
3. **Operations is never locked.** Canon gates it on `state.base.controlled` —
   leasing North Star Garage for a deposit. There is no base system to lease,
   and gating on nothing while calling it locked would be a lie. Canon's hint
   copy is recorded in the file header for when the gate returns.
4. **Crew always shows.** Canon reveals it once a crew member is introduced OR
   recruited; "introduced" is not tracked. Gating on recruited alone would hide
   the entry precisely when the player has no crew and most needs to find the
   screen.

### What is deliberately NOT on More

**A People row.** Canon's More does not have one, People is already reachable
from Street and from the Phone's Contacts section, and using it to paper over
the missing Character row would be inventing IA rather than porting it. The
first draft had it; it came out.

**Canon's disabled-row state.** `MenuRow` takes a `disabled` flag that greys the
row and swaps its description for the feature's hint. Not ported, because **no
row in this build has a gate it can fail** — every destination exists and is
always reachable. Adding it back with the first gated row is four lines;
shipping an untested branch with no caller is worse than shipping neither.

### Help is canon's copy, verbatim, including the parts that are not true yet

`ui/screens/help.tscn` ports the web `Help` component (15716): four cards, no
state, no actions. The copy is canon's word for word, because this screen is the
game explaining its own contract and paraphrasing it would be a rules change
written as an edit.

Two lines describe systems this build does not have — *"Week Zero establishes
your life in Spenard"* and *"when you decide to call the final score"* (there is
no voluntary exit; this build's run ends on eviction). **Both are kept.** They
are canon's description of 907Hustle, not of this port, and they will be true
here. Rewriting them to match today's feature set would make the screen wrong
twice: wrong now about the game, and wrong later about itself.

Canon gates the "Market visits" card on `state.market.visible`. This build has
no market-discovery gate — the Street Market is on the Hustle hub from Day 1 —
so the card always shows. Named so the gate has somewhere to go back to.

### A canon oddity, corrected and recorded

Canon's `opsSummary` is `${blocks} blocks · ${soldiers} soldiers`, unpluralised
— it renders **"1 blocks"**. Canon pluralises elsewhere (the Phone's text count
does `text${n === 1 ? "" : "s"}`), so this is an inconsistency rather than a
house style, and at this size the status reads as a stat line where "1 BLOCKS"
looks like a defect. **Pluralised here.** Recorded rather than silently
corrected, which is the standing rule — the correction is presentational and
touches no behaviour.

### Verified live (editor run, game log clean)

Fresh Day 1 → four rows, `$100` / `0 blocks · 0 soldiers` / `0/2 active` /
`Available`. All four routes land on the right scene and Help's BACK TO MORE
returns. Statuses track live state: debt 620 due in 3 → `DEBT DAY 4`, due in 0 →
`DEBT DUE`; one block one soldier → `1 BLOCK · 1 SOLDIER`, two of each →
`2 BLOCKS · 2 SOLDIERS`; recruiting Eli → `1/2 ACTIVE`. **Scroll discipline
proven the same way the Phone's was**: a synthetic press/release 2px apart
navigates, the same pair 80px apart does not. Every nav cell across Home,
Street, Hustle, Phone and More is enabled with the right cell lit — **no
`disabled` left anywhere in the bar**. No autosave fired and no phantom run was
left on the machine.

## Phase 5b (part 2): the Phone screen  (added 2026-08-20)

The nav cell is live. Thirteen of fifteen screens are built; only More is left.
`ui/screens/phone.tscn` + `phone.gd`, derived from `hustle.tscn`'s chrome by
`scripts/make_surface_screen.py`, extending `surface_base.gd`.

### Canon's six sections, in canon's order

Offline card · Texts · Contacts · Bills · Today's Log · Word Around Town
(ui.built.js:15734). Accordions, as canon's are, and **only Texts starts
expanded** — `defaultExpanded: true` is on that one alone. Expansion is UI state
on the script, not in GameState: it is not part of the run, has no business in a
save, and lives outside the node tree so it survives `_bind_content()`'s
clear-and-rebuild.

### The offline state is a voice, not a disabled screen

Canon's subtitle for it is the design in one line: **"The phone stays available
even when the network does not."** Losing service does not lose you the screen,
it changes what the screen can tell you. Every section has an offline reading:

| section | live | offline |
|---|---|---|
| header | PHONE | **NO SERVICE**, with canon's subtitle |
| Texts | "2 texts" + cards | "1 HELD" -> "1 message is waiting for service." |
| Bills | PAY $75 | disabled, reading **PAY AT THE PHONE STORE** |
| Word Around Town | six intel lines | "Word comes back when service does." |

Plus the `card locked` at the top: SIGNAL UNAVAILABLE, days past due, canon's
copy, and a working **PAY AT NIGHT OWL** button — the store surface, which is
the one that works with a dead line. Under it, canon's action-copy line:
*"Free · service restores after the next action."* That sentence is doing real
work — the restoration is deferred by a slot, and without it the player pays,
sees nothing change, and reads a bug.

### Blocker reasons live in the system, not the screen

`obligations.pay_phone_blocker(surface)` and `pay_rent_blocker()` return canon's
own `reason` strings from `phoneBills`' rows. The screen renders the established
repo pattern (crew.gd's): **the button label becomes the reason, uppercased, and
the button disables.** So a row reads `DUE DAY 14` or `NEED $75` rather than
going quiet, and the reason is testable without a screen.

`surface` matters in the blocker in a way it does not in the reducer: canon's
Bills row sits ON the phone, so it refuses while the line is dead and points at
the Phone Store. The store's own button has no such check — that is the whole
point of walking there.

### Four divergences

1. **Contacts links out instead of embedding.** Canon renders the whole
   `SocialContacts` component here. There is no `state.contacts` ledger in this
   build (relationship levels, call/text/visit availability), and there IS a
   People screen showing what each character makes of you — so the section
   routes there. **The count is the honest one available**: people the run has
   actually formed a read on (an Exposure ledger with at least one row), not
   canon's `personalContacts + knownSocialContacts`, which needs the ledger.
2. **"Pay in People -> Crew" became "Pay on the Crew screen."** Canon's arrow is
   U+2192, which no theme font carries. This is a place where a sentence beats
   an icon.
3. **The rent row's eviction gate is unreachable.** Canon hides the row when
   `people.household.evicted`; here the third household warning ends the run
   outright, so there is no evicted-and-still-playing state. Ported anyway as a
   `game_over` check, so it stays correct if that ever changes.
4. **The debt row is wired but dormant.** Canon reads `state.lender` (Dre's
   note); no lender system is ported and `GameState.debt` is 0 on every run this
   build can start. Gating on `debt > 0` shows nothing today rather than a
   fabricated bill, and lights up the day the lender lands.

Not ported: the Accept / Turn it down buttons on a job-offer text. The
descriptor rides through the substrate, but `jobs.gd` hires directly and has no
application -> offer pipeline, so no message ever arrives carrying one. The
branch is written and named rather than silently absent.

### The dismiss glyph was checked, not eyeballed

Canon's is `×` (U+00D7). It is in all five theme fonts — verified against the
cmap tables the way `check_glyph_coverage.py` does, not by looking at it in the
editor, which lends a macOS system font and will happily draw anything. `✕` and
`✖` are in none of them. The accordion affordance is `›` closed and `–` open:
both from the five safe characters, chosen because no safe glyph points down.

### Scroll discipline held

Every tappable thing on this screen is built in code, so the
nothing-inside-the-scroll-is-STOP rule had to be honoured deliberately. The
accordion headers use `tap_connect` on the PanelContainer itself (MOUSE_FILTER
PASS + 12px tap slop), same as `make_tappable`; buttons come from
`surface_base.button()`, which does the same. **Proven, not assumed:** a
synthetic press/release 2px apart toggles a section; the same pair 80px apart
does not, so a drag that starts on a header still scrolls.

### Verified live (editor run, game log clean)

Fresh Day 1 -> all six sections in canon order, Texts open, "No messages yet.",
Bills quiet (both bills six days out, so `Upcoming`/severity 0, no badge). A
lived-in Day 7 -> `3 DUE`; phone `Due today` and rent `Due now` both payable
with "Paid from cash on hand" replacing the where-line; crew wages `Unpaid $45`
with no button. Paying both -> -$75/-$150, due days roll 7 -> 14, rows fall back
to `Upcoming` with disabled `DUE DAY 14` buttons, badge drops to the one wage
row. Dismiss removed one text and the meta went plural -> singular; Clear all
appears only above one. Offline -> the whole table above. Paying at the store
from the offline card stamped `reactivate_at_slot` 24 (= `slotNumber(7, 0)`) and
the header stayed NO SERVICE; one advance flipped it to PHONE with the held text
flushed to the top of the inbox. Contacts routes to People and back. The PHONE
nav cell is red and reachable from every screen; More stays disabled. No
autosave fired and no phantom run was left on the machine.

## Phase 5b (part 1): the phone substrate  (added 2026-08-20)

The phone is a real object now, not three loose scalars. The inbox, the held
inbox and the deferred restoration are ported, the payment reducer was brought
back to canon after the first pass simplified it, and the whole lifecycle is
enforced against oracle-recorded truth — **1212 → 1442 checks, 0 failures**.
The Phone SCREEN is part 2; this is everything it will read.

**On the number:** the build log and the ClickUp migration plan share one phase
sequence, and **6 is Cutover** in both. The Phone is screen work that lands
after the harness and before cutover, so it takes a letter suffix the way
3a-3f did rather than renumbering a plan that is already agreed.

### The idea the rest hangs off: a dead line holds, it does not drop

Canon's `pushPhoneMessage` (game-core.js:735) routes by service state. Live goes
to `inbox` (unshift, newest first); dead goes to `heldInbox` (push, oldest
first). The two halves disagree on order on purpose, because restoration
reconciles them: `[...heldInbox.reverse(), ...inbox]`, so the newest held text
lands on top and the flush reads like the inbox always did. `systems/phone.gd`
ports that, and the order is pinned by a fixture — the oracle's own
`restorePhoneIfReady`, reached through `advanceRun`, produced
`held-3, held-2, held-1, live-1` and the Godot side has to match it exactly.

### Three canon corrections the port needed

The first pass of `_pay_phone` (Phase 3c) was a reasonable-looking
simplification. The oracle disagrees on all three counts:

1. **You cannot pay early.** Canon gates PAY_PHONE_BILL on `due` — the day has
   reached the bill date, OR the counter is already running, OR the line is
   dead. Paying a week ahead to bank a due day is not a move the game offers,
   and the port was offering it.
2. **Paying does not turn the phone back on.** Canon stamps
   `reactivateAtSlot = slotNumber(day, slot)` and leaves `active` false; the
   NEXT slot advance flips it (`restorePhoneIfReady`'s strictly-greater
   comparison against `max(previousAbsolute, reactivateAtSlot)`). Pay and stand
   still and you are still offline. The port restored instantly, which also
   meant it had nowhere to flush a held inbox from.
3. **The due day rolls off TODAY, not off the old due day.** Rent rolls in whole
   periods from the date it was owed; the phone bill just moves a week out from
   when you paid it. Both periods are 7 days, which is exactly why the
   difference is easy to miss — the constants are separate for this reason and
   `obligations.gd` already said so in a comment nobody had cause to test.

`_settle_phone` needed no correction. The clock fixture walks 12 unpaid days and
the Godot side reproduces it frame for frame: counter starts the morning after
the day that ENDED on the due date, line dies once it exceeds two days of grace.

### Restoration hangs off the time system, which is where canon puts it

Canon calls `restorePhoneIfReady` from `advanceRun`. Every time cost in this
build — travel, a shift, a stickup, a boost, a flip — routes through
`time_system.handle("advance_time")`, so that one call site covers all of them,
the same way `advanceRun` does. The absolute slot from BEFORE the move is what
gets passed, which is what stops a line paid for this slot coming back in the
same slot.

### The verification ladder (all in the `parity` CI job)

Everything is driven through EXPORTED oracle surfaces — `createRun`,
`reduceGame`, `advanceRun` — so the fixtures record what canon's own reducer
did, not what a re-implementation thinks it should do.

- **The bill clock** — 12 day-end frames from a real run, unpaid. Pins the grace
  arithmetic against an off-by-one in either direction.
- **The deferred restoration** — offline → paid → advanced, three recorded
  steps. `reactivateAtSlot` came back 48 at day 13 slot 0, which is
  `slotNumber(13, 0)`, and `active` stayed false until the advance.
- **The message id format** — `day:slot:stringHash(from:text)` is a one-line
  copy (game-core does not export `pushPhoneMessage`), and it is **proven, not
  trusted**: the generator drives three `EXPLORE_SPENARD` calls and an
  `APPLY_JOB`, waits for the offer text to land, and requires the copy to
  reproduce the id canon actually minted (`2:1:3213940972`) before writing
  anything. Same discipline the marketPrice copy got in Phase 5.
- **DISMISS / CLEAR** — run against that real inbox.
- **The held flush and its order** — described above. Nothing in a fresh run
  pushes to a dead line (job offers require service), so the held stack is
  seeded by hand and canon's own restoration does the work. The logic under
  test is entirely the oracle's; only the input is supplied.
- **PHONE_INTEL** — exported outright, so Word Around Town is pure oracle data:
  3 areas x 4 slots x 6 lines, compared string for string.

### Save schema v3, and the chain's first arm that actually transforms

`phone_inbox`, `phone_held_inbox` and `phone_reactivate_at_slot` joined
`PERSIST_FIELDS`. Those three are additive and default in. `activity_log` is
not — its rows gained a `day`, because canon stamps every log entry
`Day N · SLOT` and the Phone's Today's Log filters on it, and a row written
before the field existed has no date to recover. The v2→v3 arm walks them and
stamps `-1`: honestly undated, never equal to a real day, never "today". Back-
dating them to the day the save was made would have been a fabricated fact in a
feed whose whole job is to say what happened when.

**Found while writing that test:** `_apply` SKIPS a field the save does not
carry, which keeps whatever is LIVE — not GameState's declared default. Those
are the same thing only on a fresh boot, and a fresh boot is the only place
`load_run()` is called from, so nothing is wrong today. It is a sharp edge for
whoever adds a mid-run load (a slot picker, a restart-without-relaunch), and the
migration test resets first with a comment saying why.

### `-1` is the null

Canon's `reactivateAtSlot` is `null` when nothing is scheduled. A typed
GDScript int cannot hold that, so `-1` is the stand-in — chosen because
`slotNumber` is `(day - 1) * 4 + slot`, which is 0 at the very first slot of the
run and never negative. The fixture generator does the same coercion on the way
out, so the comparison is exact rather than "close enough".

### Two placeholders retired

- **`pending_messages`** is gone. It was a hardcoded Yalonda text that Home's
  People card read as though it were real, and it collides by shape with the
  inbox — the exact collision this session was warned about. The card now reads
  `phone_inbox`, and an empty inbox says so ("NO TEXTS · Nobody has needed you
  today") instead of leaving the scene's editor-time preview standing as a fact.
  A dead line reports what it is holding.
- The Home card's badge is a real count now, and a dead line's badge counts the
  held stack.

### Named, not silently dropped

- **`read` is written and never set true.** Canon does not read it either
  (v1.35 has no read-receipt UI). It is carried so a future unread badge does
  not need a save migration.
- **`action` descriptors** are carried verbatim, but the only kind canon has is
  `job_offer` and this build's `jobs.gd` hires directly — there is no
  application → offer pipeline, so nothing pushes one yet.
- **`retireOfferMessages`** (game-core.js:745) and the `resolveJobApplications`
  call inside restoration, for the same reason: no offers to retire or resolve.
- **The online payment surface.** Canon refuses it without a laptop, an active
  line and knowledge of 907List; no laptop item exists here, so the surface is
  not offered and the reducer does not gate on it. `surface` is still carried
  and returned, because canon's other difference between store and phone is
  time cost — paying at the Phone Store burns a slot — and this build has no
  store screen to spend it from yet.

### Verified live (editor run, game log clean)

New run → phone active, due day 7, both inboxes empty, `reactivate_at_slot` -1.
Push a text → id `1:0:1500448875`, stamp "DAY 1 · MORNING". Pay on day 1 →
**refused** (the new `due` gate). Nine days of advances → day 10, line dead,
3 days past due — frame-identical to the oracle clock. Two texts pushed while
dead → held, inbox untouched. Pay → cash 100→25, due day 17,
`reactivate_at_slot` 36 (= `slotNumber(10, 0)`), **still offline**. One advance
→ active, flush order Mina · Goodie · Night Owl (newest held first), held empty.
Word Around Town interpolates the standing area and part of day, and changes on
travel ("Spenard: afternoon…" → "Industrial Service Roads: evening…"). Home's
People card renders all four states: a live text with its stamp, empty-and-live,
dead-with-held, dead-and-empty. Autosave never fired (`street_name` held empty
for the duration) and no phantom run was left on the machine.

## Phase 5 (part 2): the canon market walk  (added 2026-08-20)

The pending market fixtures are **enforced** now. `economy.gd` speaks canon:
per-area markets, the xorshift stream, mean-reversion, availability — and the
suite grew from 355 to **1212 checks, 0 failures**.

### What the market is now

- **`GameState.markets`** — canon `state.world.markets`: per-area
  `{prices, availability, history (last 8), updated_at}`, walked off
  **`GameState.rng_state`**, the xorshift cursor (canon `run.rngState`).
- **`economy.gd`'s walk primitives are static and pure** — `price_step`
  (marketPrice: 0.34 reversion toward base×bias, ±volatility movement, clamp
  [min×0.72, max×1.2]), `availability_roll` (gate, then int(4,12/9) initial vs
  int(3,13/9) nightly — that asymmetry is canon), `walk_initial_area`,
  `walk_evolve_area`. `GameState.init_markets()` (run creation) and
  `evolve()` (nightly) share them; so does the parity runner.
- **`sync_display_prices()`** mirrors the current district's prices into
  `products[].price`, so every existing screen binding stays correct without
  knowing markets exist. Called after any walk, after travel, after load.
- **Buy enforces and consumes availability** (canon BUY, game-core.js:7561-66);
  sell does not restore it — supply restocks overnight, not from the player's
  bag. Canon rejects an over-availability buy silently; ours says "Not enough
  supply." — named divergence, the action layer speaks.

### Two corrections this forced

1. **Markets move ONCE PER DAY.** evolveMarkets is called from day-end
   settlement (game-core.js:6654), never per slot. The 3b change that keyed
   prices per-slot treated the nightly cadence as a bug and "fixed" it —
   the oracle says nightly was the design. `time_system` now evolves on
   day-cross only; prices hold through a day's four slots.
2. **Product order is stream order.** GameState listed molly before coke;
   canon PRODUCTS is coke-then-molly. With draws consumed in product order,
   the swap silently mis-dealt every draw after it — the end-to-end fixture
   caught it (coke wearing molly's numbers). Products are in canon order now,
   and the Market scene's R4/R5 icons swapped to match. **Data ORDER is part
   of parity, not just data values.**

### The verification ladder (all in the `parity` CI job)

- **Data parity** — the hand-copied bias/availability/volatility tables must
  equal what the oracle carries (a typo can't hide behind a correct formula).
- **Formula parity** — recorded lifecycle walks (initial + 6 nightly evolves,
  3 areas × 8 products, cursor per frame) replay through economy.gd's own
  statics. The generator's marketPrice AND evolveMarkets copies are themselves
  oracle-verified before fixtures are written: each must reproduce a real
  `createRun` market / a real CONFIRM_END_DAY settlement from a scanned
  stream offset (both verified at offset 0).
- **End-to-end parity, pure oracle** — `GameState.init_markets()` must equal
  the recorded output of the web build's actual `createRun` for the same seed:
  every price, every availability, and the cursor left behind. Both real
  seeds are pinned: numeric 907 and the default `"907hustle"` (→ the
  normalizeSeed fallback).

### Save schema v2 — the migration chain's first real use

`markets` + `rng_state` joined `PERSIST_FIELDS`; `SAVE_VERSION` is 2; the
v1→v2 arm is additive (stamp only). A v1 save loads with no markets, so
`load_run()` walks a fresh board off the run seed — an old save resumes priced
rather than empty, and the next day-cross re-walks it.

### Verified live (editor run)

New run → Spenard board priced from the seed walk ($25 weed opening, matching
the oracle); buy 2 weed → cash 100→50, availability 9→7; a 99-unit buy
rejected on supply; prices held across three intraday advances and walked on
the day-cross ($25→$28); Market screen renders the canon-ordered rows with
the right icons. Game log clean.

## Phase 5 (part 1): the parity harness  (added 2026-08-20)

The dual-run harness the Migration doc's plan-Phase 7 asks for, in its first
working form: **the oracle's deterministic primitives are recorded as fixtures,
and CI replays them through the Godot port on every push and PR.** A drifted
primitive now fails a PR before it can merge.

### The shape

- **`scripts/parity/gen_fixtures.mjs`** (Node, run locally against the
  read-only oracle checkout) records what the web build actually produces:
  `stringHash` over game-shaped keys with BOTH normalisations (`/2^32` and
  `%10000/10000`), `normalizeSeed`'s coercion table, and xorshift32 draw
  sequences with the state cursor after every draw. Fixtures are committed
  (`tests/parity/fixtures/rng_fixtures.json`), so CI never needs the oracle.
  Regenerate on oracle version bumps; a fixture diff without a version bump is
  a red flag.
- **`tests/parity/parity_runner.gd`** runs headless
  (`godot --headless --path . res://tests/parity/parity_runner.tscn`), compares
  recorded truth, and quits non-zero on any mismatch. The `parity` CI job runs
  it in the same godot-ci container as the export, with the same MCP-addon
  strip. First run: **355 checks, 0 failures.**
- **The Phase 4 acceptance test is now automated** — the runner replays the
  save→scramble→load round-trip (real dispatches, exposure broadcast, Curtis
  awareness, crew/territory/shark state, fractional heat, Color'd feed entry)
  and deep-compares the full manifest. It restores whatever save file it found
  before running, so a dev machine does not gain a phantom "Parity" run.

### `RngManager` grew the stream half of canon's randomness

Canon has TWO randomness shapes and they are not interchangeable: **keyed**
(`stringHash(key)` → one value per unique key, order-independent) and
**stream** (`makeRandom(rngState)`, xorshift32 — order and COUNT of draws
matter, cursor carried in run state). The market walk and crew assignment
resolution consume the stream. `make_stream()` / `Xorshift` port it exactly:
masking each step to 32 bits is bit-equivalent to JS's int32 intermediates
because XOR and logical shifts only read the low 32 bits. `normalize_seed`
ports the full `Number()` coercion table (non-numeric strings → the 0x9072026
fallback, negatives wrap ToUint32, zero → fallback) — and canon runs it on
carried cursors too, so `make_stream` does as well.

Also fixed while proving bit-exactness: JS `stringHash` iterates code points
but hashes `charCodeAt(0)` — for an astral character that is the HIGH
SURROGATE, not the code point. `string_hash` now reproduces that quirk (no
game key contains one, but the fixture with an emoji key pins it).

### The marketPrice copy is oracle-verified, and the walk fixtures wait

`game-core` does not export `marketPrice`, so the generator carries a copy of
the 6-line formula (game-core.js:1331) — **proven against the oracle, not
trusted**: the generator replays `initialMarket` with the copy against a
scanned stream offset and requires it to reproduce `createRun`'s actual market
(every price AND every availability, 3 areas × 8 products) before writing
anything. It verified at offset 0 — `initialMarket` is `createRun`'s first
stream consumer.

The recorded market walks (canon consumption order: area × product, one
movement draw each, 0.34 mean-reversion, per-product volatility, clamp
[min×0.72, max×1.2]) are **PENDING in the runner, counted but not compared** —
they are the acceptance tests for part 2, the canon economy port. Today's
`economy.evolve()` is still the simplified keyed ±20% model; part 2 replaces
it with the stream-based walk and flips those fixtures from pending to
enforced.

### Gotchas

- Godot's JSON parses every number as float. Fixture hashes/states are uint32
  — exact in a double — so `int(row["hash"])` compares exactly; stream floats
  agree at 0.0 and the runner's 1e-12 epsilon only absorbs printf noise.
- `tests/*` joined the web export's `exclude_filter` — the runner and fixtures
  have no business in the shipped .pck.

## Phase 4: save/load  (added 2026-08-20)

`autoload/save_system.gd` (`SaveSystem`, the 7th autoload) — port of canon's
autosave loop (serialize the whole state to storage on **every** state change
while in-game, ui.built.js `App`) and `inspectSave` (game-core.js:2179). This
closes plan-Phase 3 of the Migration doc ("save → reload → same state restored")
and unblocks CONTINUE RUN + the LAST RUN preview on the title screen.

### The shape

- **Everything mutable in GameState persists** — clock, player stats, inventory,
  jobs, obligations, all six hustle surfaces, crew records + wage clock,
  territory, `npc_ledgers` + `observation_queue`, every Curtis awareness field,
  and the activity feed — via a `PERSIST_FIELDS` manifest, captured and applied
  by name. The current market prices ride separately as a `{product_id: price}`
  slice because `price` is the one mutable value living inside a canon table.
- **Canon tables and UI-scaffold placeholders deliberately do NOT persist**
  (districts, stick_targets, crew_roster… and todays_take, income_sources,
  hustle_surfaces, active_operation, eli_report, pending_messages). A
  data-tuning commit must win over a stale save, and a placeholder that
  persists becomes a fake fact.
- **Autosave cadence is canon's**: GameManager fires exactly one
  `notify_changed()` per successful dispatch, and SaveSystem saves on each one.
  The gate is `street_name != ""` — canon gates on `screen === "game"`, and
  these are the same fact: a run exists once it has a name, and nothing fires
  `state_changed` before name entry sets one.

### Two deliberate divergences from canon's storage

1. **Format is Godot variant text (`var_to_str`), not JSON.** `activity_log`
   rows carry `Color` values JSON cannot represent, and a JSON round-trip turns
   every int into a float, which a typed GDScript var refuses at assignment.
   `str_to_var` round-trips every type exactly and evaluates no code.
2. **One file (`user://907hustle_run.save`) with the version inside the
   payload**, not canon's key-per-version localStorage scheme (`SAVE_KEY` + 8
   `LEGACY_SAVE_KEYS`). That scheme exists because localStorage cannot rename;
   a file has no such constraint, so the legacy-key scan was not ported — no
   Godot save predates this file.

**Versioning is built in from the first byte** — canon's history (migrateSave
handles v3–v10, game-core.js:1719) says the chain WILL be needed. `_migrate()`
is that chain: one `match` arm per future version bump, and a version the build
has never heard of (0, or newer than itself) is invalid, not a guess. A save
missing a required key (`day`/`cash`/`street_name`) is invalid; every other
absent field keeps GameState's declared default — canon's `mergeDefaults`, done
by omission. Values are coerced to the live field's type on apply, so a
hand-edited or migrated save cannot feed a float into a typed int var.

### The title flow (canon `TitleScreen` + `App.startNew`)

- LAST RUN preview is canon's stack: name / "SAVED RUN · DAY X · PART" /
  "DISTRICT · $cash CASH · $debt DEBT", from `inspect().preview`.
- CONTINUE loads and enters the game; if the file dies between inspect and
  load, canon's copy ("The saved run could not be read…") shows as a toast and
  the button re-hides.
- **NEW RUN over a valid save confirms first** ("Start a new run? The current
  autosave will be replaced."). The save is only overwritten by the first
  autosave of the new run — backing out at name entry keeps the old run, same
  as canon.
- **A game-over run stays saved, and CONTINUE routes it straight back to the
  game-over screen** (via `screen_base.refresh()`'s existing game_over gate).
  That is canon parity: the web build autosaves the ended state and Load
  resumes into the EndModal.

### Verified (editor run, all via game_eval; game log clean)

Fresh boot → no save → both title controls hidden. Start run → autosave exists,
preview correct. A lived-in run (market buy, job apply+work, advance, travel,
exposure records + broadcast, awareness 4, crew record, held block, shark loan,
fractional heat 1.6, Color'd log entry) → scramble every field silently → load →
**zero deep-equality differences across the full manifest + prices**; heat came
back float, day came back int. Corrupt file / future version / version 0 /
missing key → exists-but-invalid, load refused, state untouched. Confirm flow
shows/cancels; CONTINUE lands on Home with the run intact; game-over run
re-routes to game_over. **Not verified: IndexedDB persistence across a browser
reload on the deployed web build** — user:// maps to IndexedDB there and the
engine syncs it, but check on a real device after merge.

Gotcha for future save tests: compare captures with `==` (deep content
equality), not `str()` — dictionary key order shifts across a round-trip and
`str()` flags phantom diffs.

## Phase 3f (part 2): Curtis awareness  (added 2026-08-20)

`autoload/curtis.gd` — port of `src/data/curtis-awareness.js` plus
`raiseCurtisAwareness` / `refreshAwarenessPhase` / `broadcastTracked` /
`maybeWatcherEncounter` and the quiet-streak decay.

### Three different things track Curtis, and canon keeps them apart

| | what it is | where |
| --- | --- | --- |
| his ledger | what he **feels** about you (THREAT lens, inverted) | `Exposure` |
| awareness | how hard his **people are looking** | `Curtis` |
| district awareness | police difficulty | not ported |

Do not collapse these. The disposition can be Hostile while awareness is still
Invisible, and that is a meaningful state: he dislikes what he has heard but is
not yet looking for you.

### The join is `broadcast_tracked`

Awareness rises **only when an observation genuinely reaches Curtis over the
network channel**. A thing he never hears about does not make his people look
harder. Verified: a household broadcast leaves awareness untouched, the same
broadcast on network raises it by one.

### Phase floors ratchet

`invisible 0 · ambient 3 · watching 7 · approaching 11`, on canon's 0-15 scale —
the same scale as Heat. Once a phase is reached, decay can never take the level
back below that phase's floor. **Once Curtis notices you, he does not fully
forget.** Verified: awareness 9 decayed to 7 over three quiet days and stopped.

Decay itself is a quiet-streak: the first quiet day is free, and from the second
consecutive one awareness bleeds a point a day. Any criminal action resets it,
which is why `boost.gd` calls `mark_criminal_activity()` even though it is not
loud enough to raise awareness on its own.

### Watchers are texture, not observations

No ledger row, nothing to resolve. At most one a day, only in Spenard, and only
during **ordinary movement** — canon is deliberate that watchers appear while
travelling rather than during the crime itself, which is what makes them
unsettling. `watcher_chance = min(0.7, 0.3 + level * 0.04)`. Lines cycle without
repeating inside the last three.

Rolled off `seeded_unit_10k` rather than a stream, so a run that never qualifies
keeps its exact event sequence.

### Another placeholder retired

`curtis_attention` was a static `4/8`. The Hustle rival card reads the real phase
and level now (`WATCHING 7/15`). **That is the second placeholder found this way
— check `GameState` for an existing name before adding one.**

## Phase 3f (part 1): the Exposure substrate  (added 2026-08-20)

`autoload/exposure.gd` — port of `src/exposure/engine.js` plus `observations.js`,
`npc-lenses.js`, `propagation.js` and `disposition-bands.js`.

**A typed observation is the only thing an NPC ever knows about the player.**
Observations land in a per-NPC ledger keyed by category + event + location, so
the same thing seen twice increments a count rather than growing the ledger. A
lens turns that ledger into one number, and every character weights the same
evidence differently.

### Three things that are easy to get wrong

1. **`SHARED_EVENT_WEIGHTS` is not optional.** Skipping it is a real trap and I
   hit it: `missed_obligation` is category `financial`, which CIVILIAN weights at
   **+1.5**, so missing rent made Yalonda *like you more* — and the escalating
   count made it worse the longer you went unpaid. Resolution order is NPC event
   weight → shared event weight → category weight.
2. **THREAT is inverted.** For a rival a HIGH score means "no problem to me", so
   everything that makes you worth noticing drives Curtis's number DOWN. He reads
   Neutral as invisible and Hostile as confrontation. `is_inverted()` exists so
   callers can flip their reading; the People screen flips its colours with it.
3. **`territory` weighs zero in all four archetypes, deliberately.** Every other
   category is evidence about the player; a warning that Curtis's people are
   working Motel Row is evidence about *Curtis*. It must never move a number, or
   being warned a lot would quietly make Mina like you.

### The two curves

`effective_count` is logarithmic by default — the first three repetitions carry
the weight. Two opt out, and they are not the same rule twice: `betrayal` never
fades, and `missed_obligation` escalates linearly because its weight is negative.
The asymmetry is the design, and it shows:

| | day 8 | day 15 | day 22 |
| --- | --- | --- | --- |
| paying rent every week | 3.00 WARM | 4.75 WARM | 6.00 TRUSTED |
| never paying | -2.50 COLD | -5.00 COLD | -7.50 HOSTILE |

Good behaviour has diminishing returns. Missed obligations do not.

### Not ported, named so the gap is legible

Presence gating (`NPC_PRESENCE_SLOTS` / `NPC_PRESENCE_AREAS` — whether an NPC was
physically somewhere to witness a thing), the Curtis network filter
(`CURTIS_NETWORK_CATEGORIES` and its volume threshold), and slot-level delivery.
The queue works in whole days, which is the granularity the rest of this build
runs on.

### Where to see it

`ui/screens/people.tscn`, from Home's People card. Every score is shown with the
evidence behind it, because a lens disagreeing with another lens should be
legible rather than mysterious.

## Exposure wiring pass — DONE  (closed 2026-08-20)

The OWED checklist from 3c/3d is wired. Every system that makes noise now says so
through the exposure layer:

| system | observation | channel |
| --- | --- | --- |
| `jobs.gd` | `steady_work` (presence) per shift | neighborhood |
| `jobs.gd` | `job_lost` (financial) on firing | household **and** neighborhood |
| `obligations.gd` | `rent_paid` / `missed_obligation` | household (direct) |
| `crew.gd` | `crew_recruited` (growth) | neighborhood, via `broadcast_tracked` |
| `crew.gd` | `paid_the_crew` (loyalty) | network |
| `stickup.gd` | `stickup` (violence) + `organized_hit` at 2+ tier-3 | neighborhood / network |
| `boost.gd` | `fenced_goods` (financial) | **household only** — Slide is discreet |
| `shark.gd` | `note_returned` to Dre · `collected_hard` (violence) · `let_it_go` | direct / neighborhood |

Also closed a real gap found while wiring: **canon charges `heat + 2` for a
violent Shark collection**, which 3d deferred. It is applied now, damped by
Deshawn like every other heat source.

### ⚠ Probable canon bug: `job_lost` scores POSITIVE

`job_lost` is category `financial`, which CIVILIAN weights at **+1.5**, and it is
**not** in `SHARED_EVENT_WEIGHTS`. So being fired currently makes Yalonda think
*better* of you:

```
yalonda after job_lost:          +1.50 (NEUTRAL)
yalonda after missed_obligation: -2.50 (COLD)
```

This is ported faithfully rather than quietly corrected, because the oracle is
the oracle. But it looks like an oversight upstream: canon's own comment on
`SHARED_EVENT_WEIGHTS` says *"Anything that means 'you cost me something' is
priced here instead of inherited from its category"*, and being fired is plainly
that. **Worth fixing in the web build**, at which point adding
`"job_lost": -2.0` here keeps the two in step.

This is the same shape as the bug the substrate PR caught with
`missed_obligation`. When adding any new event, ask whether it means "you cost me
something" — if so it needs an entry in that table, not a category weight.

### Curtis: awareness and disposition move independently, on purpose

Worth seeing in the numbers. After one stickup:

```
curtis disposition 0.0  ·  curtis awareness 2
```

His people noticed (the stickup rides `neighborhood`, and awareness rose from the
direct `raise_awareness(2)`), but he has formed no opinion, because **Curtis does
not listen on the neighborhood channel** — he is on `direct`, `network` and
`reputation`. That is canon and it is the right behaviour: being noticed and
being judged are different things.

## Phase 3e (part 2): Territory  (added 2026-08-20)

**The first income that arrives without an action** — which is also the first
thing that can outrun the rent.

- **`systems/territory.gd`** — the six canon `SPENARD_BLOCKS`, soldiers at
  `SOLDIER_RECRUIT_COST = 140`, capacity `2 + 2 per block held`, and the nightly
  settlement.
- **Income is per soldier with diminishing returns** (`0.85^index`). The decision
  that creates: a second corner beats a second soldier on the first **only if it
  earns at least 85% as much**. Two soldiers on Motel Row (100) make $185;
  split across Motel Row and Fourth Ave (80) they make $180.
- **Ownership costs heat nightly whether or not the corner is staffed.** Canon is
  explicit about why: an empty corner you hold is still a corner people know is
  yours. A block you cannot staff is a pure liability, and the screen says so.
- Territory heat routes through `crew.heat_multiplier()`, same as stickup and
  boost, so Deshawn damps it too.

### The Home Turf card is real now

`GameState.held_blocks` **used to be three hardcoded names** with fixed mini-map
cells (`Minnesota Dr.`, `Burlwood`, `W. 36th Ave.`) and `soldiers = 6`. Those were
placeholders and are gone. The card now derives held count, the 12-cell mini-map,
soldier pips and the report line from the real system, and taps through to Turf.

**Watch for this pattern.** `held_blocks` collided on name with the placeholder
when the real one was added — GDScript takes the duplicate declaration as a parse
error. There are likely more placeholder fields in `GameState` waiting to be
replaced the same way; check for an existing name before adding one.

## Phase 3e (part 1): Crew  (added 2026-08-20)

**This makes `crew_power` a live stat.** It read 0 in the HUD from the first build
with nothing able to move it, exactly as Heat did before stickup.

- **`systems/crew.gd`** — the four canon CREW members, loyalty 0-10 starting at 5,
  `TIER_REQUIREMENTS` (tier 2 at loyalty 7 + 5 days, tier 3 at loyalty 9 + 12
  days), `TIER_WAGES`, and the nightly wage clock.
- **The wage clock is the system.** A wage accrues every night whether or not it
  is paid, two nights are grace, then loyalty falls a point a night, and at zero
  they walk. Canon's power contribution is
  `power + clamp(loyalty - 5, 0, 3) - (wageDue > 0 ? 2 : 0)`, so **an unpaid crew
  member is worth less before they ever leave** — which is why the roster screen
  puts what is owed next to what they are worth.
- **Boost tier 3 is reachable now.** Canon gates it on technique 13 AND a
  field-assignable crew member; all four canon crew qualify. Verified: technique
  13 with Deshawn on the roster promotes to tier 3.
- Reached from the **Street → People** row, which now reports crew and power
  instead of a static contact count.

### Heat became fractional, and had to

Canon carries heat as a float and logs it to one decimal
(`Math.round(addedHeat * 10) / 10`). Ours was an int, which rounded Deshawn's
`DESHAWN_HEAT_REDUCTION` of 0.80 straight back to the unreduced value on a base-2
stickup — 1.6 and 2 are both "2". `GameState.heat` is a float now, with
`heat_shown()` for display. **Any future multiplier on heat depends on this.**

### Canon gates stubbed, each named in the file header

`base.controlled` / `base.visiting` (no garage, so recruiting happens anywhere),
`crew.introduced` and `contactStage` (no NPC introduction arcs, so all four are
recruitable from Day 1), `crewRecruitmentEligible` proof gates, and
`crewCapacityFor` base upgrades (capacity fixed at canon's floor of 2).

Tone's `TONE_DEFENSE_MULTIPLIER` is stored and surfaced but multiplies nothing
until combat encounters exist. Deshawn's heat reduction **is** applied — stickup
and boost both route their heat through `crew.heat_multiplier()`.

## Phase 3d (part 2): 907List + Boost  (added 2026-08-20)

All six Hustle surfaces are live. No row toasts "coming soon" any more.

- **`systems/nine07list.gd`** — the eighteen canon `LISTING_ITEMS` and the three
  `MARKET_TIERS`. **The mechanic is information, not arithmetic.** Every item has a
  hidden `true_value` band and four of the eighteen are traps that sell for less
  than they cost. A Scrapper's board shows only title and price, so condition is a
  guess; Flipper shows condition, which is what turns the guess into a read. The
  screen shows exactly the fields the tier allows and no colour cue either — the
  tier hides the read, not just the word.
- **`systems/boost.gd`** — the twelve canon `BOOST_TARGETS`, `boostChance`,
  `updateBoostTier` and `boostFenceRate` (0.40 + standing*0.05, 0.55 from 3, 0.60
  from 5). Tier 1 reads 0.70 and tier 2 reads 0.45, or 0.65 inside its window.

### Two deliberate divergences

1. **Boost windows are shown outright.** Canon only reveals a tier-2 target's
   window after you have hit it (`ASK_BOOST_WINDOW`). With no surface to learn it
   on, hiding it would be a +0.20 modifier the player can neither see nor act on.
2. **907List tier 2 is gated on flips, not a purchase.** Canon opens Flipper by
   buying a laptop; there is no gear store yet, so it gates on three clean flips
   (`FLIPPER_FLIP_REQUIREMENT`). Tier 3 keeps canon's ten (`BROKER_FLIP_REQUIREMENT`).

### Boost tier 3 is written but unreachable

Canon gates it on technique 13 **and** field-assignable crew. Crew lands in 3e, so
the merchandise-and-fence loop cannot trigger yet. That is canon's gate, not an
omission — the code and the fence screen section are there and will light up when
crew does.

## Phase 3d (part 1): Stickup + Shark  (added 2026-08-20)

Two of the four criminal surfaces. 907List and Boost are part 2 — see the note
at the end of this section for why the phase split.

- **`systems/stickup.gd`** — the nine canon `STICK_TARGETS` (src/data/districts.js),
  `STICK_DAILY_CAP = 2`, and canon's chance formula. **This is what finally makes
  Heat a live stat**; it sat at 0/15 in the HUD doing nothing until now.
- **`systems/shark.gd`** — the four canon `SHARK_BORROWERS` and
  `SHARK_TERMS = {2: 0.40, 4: 0.25, 7: 0.15}`. Notes settle on `day_crossed`,
  reusing the same machinery the obligations run on. Dre takes 12% of the
  interest on every note that comes back.

### Terms pinned at canon neutral

Both formulas reference systems that do not exist yet. Rather than invent
values, each term sits at its canon default and is named in the file header so
the gap is legible when those systems land:

| term | pinned to | why |
| --- | --- | --- |
| `combat` / `intelligence` | 1 | `ATTRIBUTE_DEFAULTS` — no attribute system |
| `weaponBonus` | 0 | no equipment system; tier 2+ weapon gating relaxed to suit |
| `planning` (casing, crew) | 0 | no casing, no crew |
| `districtDelta` | 0 | no district heat/attention tracking |
| Dre bond | false | no relationship bands |

So a tier-1 mark at 0 heat reads 0.62 - 0.08 = **0.54**, which is what the screen
shows. When attributes land, that number moves on its own.

### `RngManager.seeded_unit_10k`

Canon uses **two** normalisations for the same hash: `hash / 2^32` in most
places, and `hash % 10000 / 10000` for others — the Shark default roll
(game-core.js:6561) among them. They produce different values from the same key,
so the roll has to use whichever form canon used or Phase 5's dual-run parity
will not hold. Both live in `RngManager` now; pick by what canon does at that
call site, not by preference.

### `ui/screens/surface_base.gd` and the screen generator

The surfaces are all "a list of state-shaped rows", so the shared builders live
in `surface_base.gd` and each surface overrides `_build_body()` (never
`_bind_content()` — the base does the clear-and-rebuild).

`scripts/make_surface_screen.py <name> <heading> <subtitle> [backdrop]` derives a
new surface scene from `hustle.tscn`: chrome verbatim, content nodes dropped, a
Title and one empty `Body` VBox left behind. Re-authoring 600 lines of chrome per
surface would guarantee they drift.

**Gotcha found here:** `autowrap_mode = WORD_SMART` on a Label inside an HBox
with an expanding sibling collapses it to one character per line. `label()` takes
`wrap` as an opt-in for that reason; only prose asks for it. `jobs.gd` had the
same latent bug and was fixed with it.

### Why the phase split

3d is nineteen canon actions across four surfaces (`BUY_907LIST`,
`BUY_BULK_907LIST`, `SELL_907LIST`, `QUICK_SELL_907LIST`, `DELIVER_907LIST`,
`FILL_BUYER_REQUEST`, `BOOST`, `SHOPLIFT`, `CASE_TARGET`, `ASK_BOOST_WINDOW`,
`ASSIGN_BOOST_CREW`, `FENCE_BOOST_GOODS`, `STICKUP`, `ROB`, `ROB_DEALER`,
`FUND_SHARK`, `ENFORCE_SHARK`, `EXTEND_SHARK`, `FORGIVE_SHARK`). Stickup and
Shark went first because they hook cleanly into infrastructure that already
exists — Heat and the day clock. 907List and Boost need an item/inventory model
and a fencing loop, which is its own shape of work.

## v0.1.0 — Playtest Polish  (added 2026-08-22)

Branch `claude/v0.1.0-playtest-polish-b4nlnx`, from `main` at `c135fee` (PR #51
and PR #50 both merged). Six tasks: build versioning, the surface-visibility
access layer, the seeded-key composition audit, the HOT escape lever, the Phone
tap-target fix, and the canonical location rename.

**Parity: 11,110 checks, 0 failures** (from 10,781). Floor raised 10,770 → 11,100,
set from the MERGED suite with ten of margin: 10,781 (base) + 329 (v0.1.0).
**Save schema: v9 → v10.** 21/21 screens render headless at 375×812.
Glyph coverage passes. The nested save-shape suite is **82 checks** (from 47) —
`save_validator.gd` gained three v10 arms, one per new field.

`main` moved under this branch mid-build (PR #49 nested save-shape validation,
PR #52 the floor-and-doc sync) and was merged in. Three conflicts, all
resolved by TAKING BOTH: the schema constant is v10 *and* preloads the new
validator; the floor keeps PR #52's derivation discipline and extends its
arithmetic; the README roadmap keeps v0.1.0's row.

### Save schema v10

Three additive fields. Two are persisted discovery latches, one is a within-day
ledger.

| Field | Type | New-run default | v9 → v10 arm |
| --- | --- | --- | --- |
| `districts_unlocked` | `Array` of district IDs | `["north_star_lot"]` | **Derived**, not defaulted: `held_blocks.size() >= 1` adds `downtown`, `>= 2` adds `airport_industrial` |
| `job_contacts` | `int` | `0` | **Derived**: one per recruited-and-active contact in `["deshawn", "pherris"]` |
| `pressure_clean_credits` | `Dictionary` | `{}` | Defaulted empty — it is a within-day ledger that drains every night, so empty IS a v9 run's history |

The first two arms derive rather than default because a v9 run has a real past.
A v9 save may hold six corners and have Deshawn on the crew; defaulting
`districts_unlocked` would take Downtown away from somebody who has been trading
there for a fortnight, and defaulting `job_contacts` would re-lock Jobs on a run
that has been working them. `SaveSystem.load_run()` also calls
`reconcile_persistent_invariants()`, so the arm is redundant-by-design — it only
stops the surfaces reading locked for the one frame before the next dispatch.
That redundancy is why the parity check asks `_migrate()` **directly** rather
than through a load: a load-level assertion cannot tell a working arm from a
missing one (proved — sabotage S11 initially passed against a load-level check).

Field IDs use the canonical district IDs (`north_star_lot`, `downtown`,
`airport_industrial`) rather than the build brief's shorthand
("spenard"/"downtown"/"industrial"). Those IDs are what `districts`, the market
keys, `district_pressure` and the save already use; a second vocabulary of
friendly names would be one rename away from gating nothing at all.

### The v10 fields, and the validator that had to learn them

PR #49 landed a load-time nested-shape validator (`autoload/save_validator.gd`)
while this branch was open. It "preserves unknown keys", so the three v10 fields
would have passed through it untouched and unchecked — which is exactly the gap
the validator exists to close. Three arms added, one per field, each guarding a
different failure:

- **`districts_unlocked`** — non-string rows dropped, duplicates dropped, and
  `north_star_lot` restored if a save somehow lost it. A run that cannot travel
  home is worse than any malformed row this validator normally sees.
- **`job_contacts`** — clamped at zero. A negative reads identically to zero
  right up until somebody writes a gate that tests `!= 0`.
- **`pressure_clean_credits`** — same district → family shape as
  `district_pressure`, one level shallower, with negatives clamped: a negative
  credit would ADD Pressure at settlement, the exact opposite of the lever.

Absent is not malformed — a v9 save reaches the validator with none of the three
and must come out with none of them, so `_apply()` supplies GameState's defaults.
Asserted.

### The surface visibility system

`autoload/surface_visibility.gd`. Architecture is the ClickUp Lightweight Design
Pass (Progression Gate Architecture), which is explicit that this must NOT be a
second eligibility engine:

```
GameState / owning systems
  -> progression facts adapter   SurfaceVisibility.facts()
  -> requirements evaluator      systems/requirements.gd   (unchanged engine)
  -> access registry             SurfaceVisibility.GATES
  -> UI + ScreenManager          is_unlocked() / is_visible() / verdict()
```

`requirements.gd` gained six fact-reading requirement types (`crew_count_min`,
`district_discovered`, `list_flips_min`, `job_contacts_min`,
`collection_non_empty`, `fact_true`) and no new evaluation logic. Unknown types
still fail closed.

**The gate table** (authored in one `const GATES`, never scattered across screens):

| Surface ID | Mode | Condition | Hint |
| --- | --- | --- | --- |
| `home.market_snapshot` | LOCKED | `list_flips >= 1` | "Complete your first flip to unlock" |
| `home.turf_crew` | LOCKED | `crew_count >= 1` | "Recruit your first crew member" |
| `menu.crew` | LOCKED | `crew_count >= 1` | "Recruit your first crew member" |
| `menu.jobs` | LOCKED | `job_contacts >= 1` | "Meet someone who hires" |
| `street.downtown` | LOCKED | `"downtown" in districts_unlocked` | "Hold a corner before the city opens up" |
| `street.ship_creek` | LOCKED | `"airport_industrial" in districts_unlocked` | "Hold two corners before the port is worth the trip" |
| `home.tonights_operation` | HIDDEN | `operation_card_live` | — |
| `home.text_messages` | HIDDEN | `phone_messages > 0` | — |
| `home.activity_feed` | HIDDEN | `activity_log > 0` | — |

**LOCKED** renders at 40% opacity (theme constant `Locked/opacity_pct`) with a
lock row underneath: `assets/icons/ui/icon-lock.svg` plus one line in the
`LockHint` variation (Barlow Condensed 11pt, 60% white). A tap on a locked
surface does nothing — `screen_base._on_tap_gui_input` returns early on the
`surface_locked` meta rather than disconnecting handlers, because the connection
is made once in `_ready()` while the gate re-evaluates on every refresh.

**Why an icon and not the 🔒 glyph.** The brief offered U+1F512. No theme font
carries it, so it would render in the editor (macOS lends a system font) and as
tofu in the browser — and `scripts/check_glyph_coverage.py` is a CI gate that
would have failed the build. Same lesson the meter dots and the trend arrow
already learned. Glyph coverage passes.

**Route protection.** `ScreenManager.resolved_route()` consults the same verdict
and returns `""` for a refused destination; `go_to()` then does nothing, silently
— the lock and its hint have already said why. `travel` is gated at the ACTION
too, so a dispatch from anywhere gets the same answer as the Street card.

**Two deviations from the brief, both stated:**

1. **`home.tonights_operation`'s condition is wider than
   `crew_operation_state.active_today`.** That card is not only the delegation
   readout — it is also the only place on Home that carries a DEADLINE (rent
   inside two days, or a workable shift). Hiding it on a fresh run is right: what
   stood there was authored scaffold about a probe on Minnesota Off-Ramp that
   nothing in the run ever wrote. Hiding it on the morning rent is due would have
   removed the warning that decides whether the run ends. So the condition is
   "does this card have something real to say", owned by
   `SurfaceVisibility.operation_card_reason()`, and `home.gd` reads the reason
   back to choose copy rather than re-deriving it.

2. **`gs.active_operation`'s scripted copy is no longer rendered at all.** It was
   UI scaffold nothing wrote. The gate is what finally let it go: the card either
   carries a fact or it is not there.

**FOLLOW-UP (open).** Home's `MOVE PRODUCT` button — the build's only bare
`advance_time` control in the UI — lives on the now-hidden operation card, so a
fresh run must pass time through Street travel, a Hustle action, or More →
Recovery → Lay Low (free, always available, verified) until the card earns its
way back. Re-homing that control is a navigation change and was out of scope
("New screens or navigation changes"). Filed for the next UX pass.

**CLOSED in batch 10.** That was the next UX pass. `MOVE PRODUCT` was never a
product-moving control at all — the comment above it names it as canon's
`explore_spenard`, which is **Wander**, priced correctly at one slot and no
money and wired to `advance_time` plus a toast reading "Time passes." The slot
was spent and nothing was bought with it. Wander now has its own always-present
card on Home, above the operation card and outside its HIDDEN gate, so a fresh
run always has a way to move the clock and something to show for it.

**Unlock triggers were authored, not found.** The brief says Downtown and
Industrial "unlock via existing travel/territory events". No such event exists —
travel was unconditional. Rather than invent progression content, the latches
read the fact the gate table's own rationale names ("Territory not yet
expanded"): `held_blocks.size()`. `job_contacts` counts recruited crew whose
canon role is connecting people to work — Deshawn ("Fixer / Recruiter") and
Pherris ("Connector") — which gives Jobs a distinct, later unlock than Crew
(Eli and Tone open Crew but not Jobs). Both are one-way latches: abandoning a
corner does not take back the knowledge that Downtown exists.

### Seeded key composition audit

FNV-1a's final rounds barely move the high bits, and `seeded_random` reads the
hash as `hash / 2^32`. A small counter appended to the TAIL of a key therefore
moves the roll by about `delta / 256`. Measured: eight consecutive counters at
the tail span **2.7%** of the value band; the same eight at the front span
**82.0%**.

Every `seeded_random` / `seeded_int_range` / `seeded_unit_10k` / `seeded_shuffle`
call site was swept. Rule applied: **rewrite where a varying integer is the FINAL
component of the key.** Six rewrites:

| File | Before | After |
| --- | --- | --- |
| `systems/nine07list.gd:227` | `"907list:value:%s:%d" % [item_id, bought_day]` | `"%d:907list:value:%s" % [bought_day, item_id]` |
| `systems/nine07list.gd:157` | `"907list:%d:%d" % [day, tier]` | `"%d:%d:907list" % [day, tier]` |
| `autoload/curtis.gd:173` | `"curtis:watcher:%d:%d" % [day, slot]` | `"%d:%d:curtis:watcher" % [day, slot]` |
| `systems/retaliation.gd:182` | `"retaliation:ambient:%s:%d" % [queue_id, today]` | `"%d:retaliation:ambient:%s" % [today, queue_id]` |
| `systems/jobs.gd:108` | `"job_interview:%s:%d:%d" % [job_id, day, slot]` | `"%d:%d:job_interview:%s" % [day, slot, job_id]` |
| `systems/shark.gd:238` | `"shark:%d:%d" % [loan_id, due_day]` | `"%d:%d:shark" % [loan_id, due_day]` |

**Deliberately NOT rewritten**, with reasons:

- `"stickup:%d:%d:%s"` and `"boost:%d:%d:%s"` — the tail is a varying STRING
  (target id), not a counter, and the day varies mid-key with plenty of rounds
  after it. `stickup:` is additionally **oracle-locked**: the
  `stickup_keys` fixture in `outcome_fixtures.json` pins the exact context
  strings the web build produces.
- `key + ":take"` / `key + ":injury"` / `"...:boost_caught:%s:injury"` — fixed
  tail suffix; the varying part is already mid-key.
- `"meetup:%d:%d:%s"`, `"job_shift_day%d_slot%d_%s"` — tail is a varying string.
- `"retaliation:schedule:%s:%s" % [cause_id, actor_id]` — actor ids are distinct
  multi-character words, not a small counter, and `cause:%08d` varies at index 21
  with seven rounds after it.
- `seeded_shuffle` — already correct; it prefixes the swap index. Confirmed.

The hash itself (`string_hash`) is untouched. Only key composition at call sites
moved. The rewrites re-rolled the 907List golden boards, the probe day (6 → 2)
and one cumulative-cash probe (day 12 → 11, because day 12's re-rolled tier-3
slate offers only one non-`rough` listing). All re-pinned as literals.

**Visible bug this fixed:** the retaliation ambient line was picked with the day
at the tail, so the same queued row drew the same one or two lines every night it
warned. Measured over eight nights: tail form picked lines `[1,1,1,1,1,0,0,0]`;
front form picks `[1,1,4,4,5,1,3,4]`.

**Permanent check.** `_check_seeded_key_independence` pins the eight leading-counter
rolls as exact floats, asserts their spread ≥ 0.60, AND asserts the trailing form
still clusters at exactly 0.02734440681524575 — so the failure mode is a standing
fixture rather than a memory. It also SOURCE-SCANS `autoload/` and `systems/` for
any seeded key whose format string ends in `%d`, because no amount of sampling
proves the absence of a call site nobody thought to sample.

### HOT escape lever

`data/consequence_rules.gd`:

```gdscript
const PRESSURE_CLEAN_RECOVERY := 0.5
const PRESSURE_MESSY_RECOVERY := 0.0
const PRESSURE_FAILURE_RECOVERY := 0.0
const PRESSURE_CATASTROPHIC_RECOVERY := 0.0
```

Clean outcomes bank a credit as the action resolves; `POST_SETTLE` pays it.
`day_lifecycle.gd` gained a declared `POST_SETTLE_ORDER` (mirroring
`ROLLOVER_ORDER` / `DAY_START_ORDER`) with one entry, `pressure_clean_recovery`,
and the lifecycle trace asserts its position. Credits are banked rather than
applied on the spot so the day's gains all land first, and they are STATE
(`pressure_clean_credits`) rather than a local because the autosave fires once
per dispatch — a player who lifts cleanly at noon and closes the tab must still
be holding that credit when the run reopens.

`recover_pressure()` is deliberately not a negative `add_pressure()`: it must not
stamp `last_gain_day`, must not reset `quiet_days`, and must not schedule a
bleed. Paying pressure back is not a gain, and a day you worked is not a quiet
day.

**Simulation sweep** (five profiles, 29–30 days, seeded; `worst_family_hot_days`):

| Constant | aggressive | yields | cautious | odds | travelling |
| --- | --- | --- | --- | --- | --- |
| **0.0** (sabotage / baseline) | **19** | 19 | 0 | 16 | 11 |
| 0.4 | 9 | 8 | 0 | 8 | 10 |
| **0.5 (shipped)** | **9** | 8 | 0 | 8 | 10 |
| 0.6 | 10 | 7 | 0 | 8 | 8 |

Target was ≤14 for the aggressive profile. 0.5 lands at 9. The lever is flat
between 0.4 and 0.6 on that metric (0.6 is actually *worse* at 10), so the tuning
instruction to dial toward 14 has no purchase — and 0.5 is the value the design
argues for independently: it is the exact wash against both
`PRESSURE_BOOST_SUCCESS` (0.5) and `PRESSURE_BY_TIER["clean"]` (0.5). A clean
source action nets ZERO rather than becoming a discount. 0.4 would make a clean
lift a net +0.1 gain and 0.6 a net −0.1 discount, both arbitrary.

Note the 0.0 row reproduces the pre-lever 19 **exactly**, which also proves the
seeded-key audit did not move this number — the lever alone accounts for the
whole change.

**Market has no clean-outcome wiring, and that is honest.** The mechanism is
family-agnostic and parity-proven for `market`, but no market-family source
action in this build resolves an outcome tier: `economy.gd` adds +0.25 per
criminal sale with no success roll at all, and the 907List `market_meetup` tier
adds no market pressure (a flip is legitimate commerce — no Heat, no Pressure),
so crediting it would be a one-sided discount. When a tiered market action lands
it calls `credit_clean_outcome(district, "market", tier)` and needs no new
machinery.

### Canonical location names

The location registry (ClickUp Master Doc → Locations) names the third district
**Ship Creek** — its page opens "District: Ship Creek (formerly Industrial
Service Roads)". The index page hedges it as "future/renaming guidance until the
repo carries that district name"; this build is what makes the repo carry it.
Corroborated by the repo itself, which already shipped `"Ship Creek Freight"` as
a job and `"Ship Creek Yards, Dock Seven"` as a boost target in that district.

| Before | After | Where |
| --- | --- | --- |
| `INDUSTRIAL` / `SERVICE ROADS` | `SHIP CREEK` / `PORT CORRIDOR` | `districts[2]` name/role |
| "Industrial Service Roads" | "Ship Creek" | `phone.gd` `AREA_PROSE_NAMES` |
| "+$11 Industrial" / "SELL INDUSTRIAL +$11" / "NEEDS INDUSTRIAL TURF" | Ship Creek forms | product route/hint |
| "North Star Garage" | "Home" | Spenard venue (registry lists Night Owl / **Home** / Spenard Gym / The Nile) |
| "Night Owl Mini-Mart" | "Night Owl" | Spenard venue AND `boost_targets` |

The district **ID** `airport_industrial` is unchanged — it is persisted in saves,
keys the market and the pressure ledger, and is pinned by oracle fixtures.

**Oracle divergence, stated once.** `rng_fixtures.json`'s `phone.intel` is
generated from the web build's exported `PHONE_INTEL` and carries the oracle's
own "Industrial Service Roads". The parity runner applies a rename map
(`ORACLE_PROSE_RENAMES`) at COMPARE TIME rather than editing the fixture, because
`gen_fixtures.mjs` would put the oracle spelling straight back on the next
regeneration and a divergence that silently reverts is worse than none. Every
other word in the pool stays oracle-locked byte for byte.

Also fixed in the same pass: `market.gd` now binds the three district tab labels
from `gs.districts` and highlights the current one. They were baked into the
`.tscn` and never bound, so the strip always read SPENARD in accent wherever the
player actually was — a standing rule-4 hole.

### Sabotage log

Every new assertion was proven red before it was believed. Twelve faults injected,
each reverted after.

| # | Injected fault | Caught by | Result |
| --- | --- | --- | --- |
| S1 | `VERSION := "0.1"` | "the version is three numbered parts" +2 more | ✅ 3 failures |
| S2 | `home.market_snapshot` min → 0 | "a fresh run locks home.market_snapshot" +15 | ✅ 16 failures |
| S3 | access guard removed from `resolved_route` | "a locked route is refused" | ✅ 2 failures |
| S4 | key probe switched to the tail form | "leading-counter roll N" + the spread floor | ✅ 9 failures |
| S5 | `curtis.gd` key reverted to tail-varying | the source scan | ✅ 2 failures, names file + line |
| S6 | `PRESSURE_CLEAN_RECOVERY := 0.0` | "a clean outcome is worth 0.5 back" +3 | ✅ 4 failures |
| S7 | `PRESSURE_MESSY_RECOVERY := 0.5` | "a messy outcome pays nothing back" +3 | ✅ 4 failures |
| S8 | `POST_SETTLE_ORDER` emptied | the lifecycle trace +3 | ✅ 4 failures |
| S9 | Phone dismiss back to 34×28 | the 44pt sweep + the widest-case check | ✅ 3 failures |
| S10 | "Industrial Service Roads" restored in `phone.gd` | the prose sweep + intel comparison | ✅ 25 failures |
| S11 | v10 arm defaults instead of deriving | `_migrate()` asked directly | ✅ 2 failures — **see note** |
| S12 | `districts_unlocked` dropped from `PERSIST_FIELDS` | "survives save and load" +2 | ✅ 3 failures |

**S11 is the one that mattered.** It PASSED on the first attempt — the check
asserted the migration through `load_run()`, and `load_run()` reconciles the
latches afterwards, so a broken arm was invisible. The check was rewritten to ask
`_migrate()` directly, plus a one-corner threshold case, and S11 then failed
correctly. A sabotage that passes is the sabotage doing its job.

### Verification

| Check | Result |
| --- | --- |
| Parity suite | PASS — 11,110 checks, 0 failures (floor 11,100) |
| Nested save-shape suite | PASS — 82 checks, 0 failures (from 47) |
| 21 screens render at 375×812 headless | 21/21 |
| Glyph coverage | ok — every shipped character is in all 5 theme fonts |
| `git diff --check` | clean |
| v9 payload migrates to v10 and loads | ✅ arm tested in isolation + through a load |
| Fresh run: only Spenard, nothing unearned | ✅ asserted against the rendered Home |
| Each progression trigger unlocks its surface | ✅ 9 gates × threshold + isolation |
| Seeded key independence ≥60% of the band | 82.0% (floor 60%) |
| Aggressive profile ≤14 HOT days | 9 (was 19) |
| Phone dismiss 44×44 at the widest content | ✅ no control declares past 375pt |
| No placeholder location names | ✅ swept across districts, venues, targets, products, phone prose, and the rendered Street screen |
| Version "0.1.0" on the title screen | ✅ read from the singleton |
| Naming enforcement grep | clean (Rook / Kip Sallis / Mara / Samira / Mini Mart) |
| RNG audit (`randf`/`randi` outside RngManager) | clean |

`refs_validate_project` is an editor-only tool from the `godot_ai` MCP addon and
is not reachable headless. The equivalent coverage here is `--headless --import`
(reports broken references) plus the smoke harness loading and binding all 21
scenes — both clean.

## Batch 1 — Hardening  (added 2026-08-22)

Branch `codex/batch-1-hardening`, from `main` at `c0e12a9` (v0.1.0 merged).
Four tasks off the hardening list: A1, A2, A3, A4.

**Parity: 11,147 checks, 0 failures** (from 11,110). Floor 11,100 → 11,137.
Nested save-shape suite 82, screens 21/21, glyph coverage passes.
**Save schema unchanged at v10** — nothing here adds state.

### A1 — crew and shark settle against the day that ENDED

The one behavioural change in the batch, and it was filed with its own fix
already written down. `day_lifecycle.gd`'s header carried this since FS-003.2:

> *"Canon's `confirmDayEnd` settles crew and shark ABOVE the increment, so both
> see the ending day. This port has always settled them below it... The `+ 1` is
> commented at both call sites and filed. When it is corrected, those two lines
> are the whole change."*

It was, and they were. Both `settle_night(ended_day)` implementations dropped
`+ 1`.

**Crew.** `wage_missed_since` is now stamped with the night the wage was
actually missed rather than the morning after. The *delta* the grace rule reads
is unchanged for a run that starts clean — stamp and comparison moved together,
and the loyalty curve over three consecutive missed nights is still `[8, 8, 7]`,
asserted. What does move is `requirements.payroll_not_delinquent`, which
compares the stamp against the LIVE day rather than against this settlement: it
now measures delinquency from the night it started instead of a day late.

**Shark.** The real one. A note due on day 7 used to resolve on the night that
ENDED day 6, because `ended_day + 1` already read 7 — the player never got their
own due day to pay it. It resolves on the night that ends day 7 now, which is
the rule `obligations.gd` already applied to rent and states the reason for:
*"a bill due on day 7 has to be payable during day 7"*.

Two existing checks pinned the old off-by-one and were re-pinned. They were
written as a matched pair on purpose ("shifting either way breaks exactly one of
these"), and that is exactly how they behaved.

### A2 — 907List board under-fill: already closed, now guaranteed

The ticket describes a retry-sampling loop colliding against itself on FNV-1a
and handing back a short board. **That loop is gone** — PR #46 replaced it with
a keyed forward shuffle, and v0.1.0 moved the key's varying components to the
front. `RngManager.seeded_shuffle`'s own doc names the property: *"Unlike retry
sampling, this always returns a full permutation and therefore cannot under-fill
a board through collisions."*

Rather than close it on that argument, the property is now asserted: every tier,
thirty consecutive days, board size equals the tier's `listings` and no listing
repeats. Plus the inverse — a one-item pool yields a one-item board — because a
board that *padded* itself would pass the first check for the wrong reason.

### A3 — CREW_CAPACITY: already correct, now enforced

Both call sites named in the ticket (`crew.gd`, `more.gd`) already used
`gs.crew_capacity()`. The only remaining reference is the parity check that
tests the constant itself, which is legitimate.

So the ticket became a standing guarantee instead of a no-op commit: a source
scan asserts no screen script mentions `CREW_CAPACITY`. This is a scan and not a
value comparison deliberately — `crew_capacity()` currently *returns* the
constant, so comparing them proves nothing while they agree. The point is the
day capacity scales with rank, when a screen holding the constant starts showing
a number the game disagrees with, quietly, because a constant that is still
correct reads like working code.

### A4 — four unguarded persisted mutators

`_require_dispatch()` already existed on both autoloads and covered five
methods. Four public mutators were outside it and all four write persisted
state:

| Function | Writes |
| --- | --- |
| `Exposure.rollover()` | `observation_queue` |
| `Exposure.propagate_heat()` | via `broadcast_observation` |
| `Curtis.maybe_watcher_encounter()` | `curtis_watchers_seen`, `curtis_last_watcher_day`, `curtis_recent_watcher_lines`, the feed |
| `Curtis.rollover()` | `curtis_quiet_streak`, `curtis_awareness` |

`maybe_watcher_encounter` is the one worth naming: it reads like a query and is
not. `propagate_heat` was already transitively covered, and is guarded anyway so
the warning names the function the caller actually called rather than one two
frames down.

Coverage is asserted from a **named list** rather than a source scan, because
"does this mutate persisted state" is not a question a scan can answer, and a
list somebody has to edit is a list somebody has to think about.

### Sabotage log

| # | Injected fault | Result |
| --- | --- | --- |
| B1-S1 | `ended_day + 1` restored in `crew.gd` | ✅ 2 failures |
| B1-S2 | `ended_day + 1` restored in `shark.gd` | ✅ 2 failures |
| B1-S3 | dispatch guard dropped from `Curtis.rollover` | ✅ 1 failure, names the function |
| B1-S4 | board sliced to `want - 1` | ✅ 14 failures |
| B1-S5 | `gs.CREW_CAPACITY` put back into `more.gd` | ✅ 2 failures, names the file |

### Not touched, and why

**A5 (nested save-shape fixture suite) was already shipped** by PR #49 while
v0.1.0 was open. v0.1.0 extended it with three v10 arms (47 → 82 checks); there
was nothing left for this batch to add.

**B4 (Night Owl "Mini Mart")** shipped in v0.1.0, venue and boost target both.

## Batch 2 — The settlement contract  (added 2026-08-22)

Branch `codex/batch-2-docs-and-glyphs`, from `main` at `d6bdcd8`.

**Parity: 11,177 checks, 0 failures** (from 11,147). Floor 11,137 → 11,167.
**No production behaviour changed.** Every line of code in this batch is either
a comment or a test.

That is the finding, not an apology for it. Six tickets were selected; **five of
them did not reproduce.** Four had already been fixed by earlier builds and one
describes a surface this port does not have. The work was proving that, and then
making sure each stays fixed.

### B2 — the day-cross settlement ordering contract (the real one)

The audit that filed this recorded an implicit order and four load-bearing
dependencies. FS-003.2 has since made the order explicit — `SETTLE_ORDER`,
`POST_SETTLE_ORDER`, `ROLLOVER_ORDER`, `DAY_START_ORDER`, with the whole trace
asserted as a literal — so the ticket's closing line ("FS-002.2 should
eventually replace this with named settlement phases") is already satisfied,
early and by a different milestone.

What was still missing is the part a reader needs: `time_system.gd` owns the
CLOCK and is where somebody arrives asking "what happens at midnight", and it
said almost nothing. It now carries the contract and names all four
dependencies. Each is asserted — a reordering that still produces a
valid-looking sequence is now caught by the thing it would actually break, not
just by the literal trace.

**One of the four had silently inverted.** The audit recorded *"any future
listener sees pre-evolution markets"*. It does not: FS-003.2 moved
`day_crossed` BELOW `economy.evolve()` deliberately, because everything still
connected to that signal was written expecting the new day on the clock and the
board priced. A listener written against the old note would read yesterday's
prices. That is now asserted against **real prices** rather than against the
trace — the trace would still pass if `evolve()` stopped changing anything, so
the check also asserts the overnight walk actually repriced the board.

The other three hold: crew settles before territory (a crew member who departs
tonight for unpaid wages does not reduce tonight's territory heat), Exposure
settles after jobs/obligations/shark (so an observation those three produce on
this cross can be delivered the same night), and `day_crossed` listeners see
pre-restoration phone state.

### C1 — "Street Identity shows 'Hustler' on a brand new game"

**Does not reproduce.** A fresh run shows **"New Face"**. Probed directly:
empty ledger, zero recent observations, `dominant_attribute` → `balanced` (no
lane leads by more than the margin), `dominant_category` → `default` (empty
totals), and `IDENTITY_MATRIX.balanced.default` → `"New Face"`.

"Hustler" is `balanced` + **presence**, which needs observations the run has not
produced. So the reported symptom is what a leaked ledger or a mis-defaulted
category would look like — which is why it is pinned rather than closed on the
reasoning. The sabotage confirms it: defaulting `dominant_category` to
`"presence"` produces exactly the reported "Hustler", and fails 26 assertions.

### C2 — "NPC name popup renders offscreen at the right edge"

**Not applicable to this port.** There is no popup surface in the Godot build —
no `PopupPanel`, no `PopupMenu`, no `Window`, no positioned floating panel
anywhere under `ui/`. NPC names are static labels inside `Container`-laid-out
cards, and the only overlay is the toast, which is anchored and full-width. This
is a web-build finding with no Godot counterpart. Nothing to clamp.

Not pinned, because there is nothing to pin — the 375×812 overflow rule already
covers every control the build actually has, and it is already asserted.

### C3 — "Home menu option duplicates the nav bar icon"

**Already satisfied, twice over.** `more.gd` has six rows — Finances,
Operations, Crew, Recovery, Character, Help — and no Home row. And
`screen_base._wire_nav()` has always declined to wire the current screen's own
nav cell (`if route == scene_file_path: continue`), so even a duplicate could
not re-enter the screen you are on.

Both halves are now asserted, including the control case: Street's Home cell IS
wired, or "the current screen's cell is inert" would pass on a screen whose nav
was never wired at all.

### B1 — pin the oracle SHA — already done

`gen_fixtures.mjs` already carries the literal `a7d9534` in the extraction
comment and `oracle_commit: "a7d9534"` in the fixture metadata, exactly as the
ticket's optional half asked. No placeholder remains.

### B3 — replace tofu glyphs (U+2197, U+265B) — already done

Removed by commit `25c44f5` ("Fix eight tofu glyphs in the web export"), with
the replacements recorded in this file's own glyph table: `icon-external` /
`icon-arrow-up` for the arrow, `icon-crew` for the queen. Neither codepoint
appears anywhere in the repo outside that table.

Nothing added — unlike A2/A3 in batch 1, the standing guarantee already exists:
`scripts/check_glyph_coverage.py` is a CI job that reads the fonts' own cmap
tables and fails the build on any uncovered character.

### Sabotage log

| # | Injected fault | Result |
| --- | --- | --- |
| B2-S1 | crew and territory swapped in `SETTLE_ORDER` | ✅ 5 failures |
| B2-S2 | `day_crossed` emitted before `economy.evolve()` | ✅ 3 failures, including the real-price check |
| B2-S3 | `dominant_category` defaults to `presence` | ✅ 26 failures — **reports "Hustler", the exact filed symptom** |
| B2-S4 | a Home row added to `more.gd` | ✅ 1 failure, names the destination |

## Batch 3 — The Risk Term  (added 2026-08-22)

Branch `codex/batch-3-trading-risk`, from `main` at `40ea377`. Commissioned as
two design gaps: "the trading path carries no risk" and "pure crime is
capital-constrained".

**Parity: 11,248 checks, 0 failures** (from 11,177). Floor 11,167 → 11,238.
Save schema unchanged at v10. 21/21 screens, glyph coverage, save-shape suite 82.

### The instrument came first, and it had to

Both gaps arrived with detailed prior analysis from the **web** build (v1.34,
PR #96): `arbitrage` at 17% of the day job, `hustler` at 110%, 383 purchases for
0 Heat. Its own pre-plan carries a standing instruction, earned the hard way:

> *"This project has now had four build prompts whose central premise was false,
> and the review process caught all four by RE-RUNNING rather than inheriting."*

So nothing was inherited. This port has its own economy, its own wallet split
and its own Pressure layer, and **it had never once been measured** — the five
existing simulation profiles measure the consequence layer and not one of them
buys or sells a unit of product. The game's central economic claim was
unfalsifiable for the whole port.

`_check_economy_profiles` is the instrument: five profiles (`legal_worker`,
`hustler`, `arbitrage`, `flipper`, `trader`) over four seeds each, thirty days,
reporting net worth, **net trade and margin alongside it** (never net worth
alone — unsold stock inflates it as the trade gets worse), peak Heat, arrests,
Pressure, seizures and dead ends.

### What it found, and five things it found about itself first

The instrument was wrong five times before it was right, and each error would
have produced a confident, false number:

| # | Instrument bug | What it would have reported |
| --- | --- | --- |
| 1 | Rent is never auto-paid — `_settle_rent` has no branch that takes the money | Every profile evicted, `legal_worker` sitting on $2,345 and evicted anyway |
| 2 | `_pay_phone` leaves `phone_active` false until the next slot, so a `not phone_active` condition pays again immediately | `legal_worker` earning $2,086 and ending on $86 |
| 3 | `apply_job` returns `ok: true` with an empty `hired` on a failed interview, so a profile that latches on the return value stops applying | Baseline halved — 15 shifts instead of 30, which is the denominator every percentage is quoted against |
| 4 | The courier put 100% of its capital in one bag | Every trading profile at 2-3% with 75% dead ends the moment carry risk existed |
| 5 | Trades ranked by per-unit edge without checking affordability | Fourteen units bought across a month |

**One seed is not enough**, and that was measured too: an early sweep moved a
lever that turned out to be irrelevant and watched `hustler` go 369% → 413%,
which is the seeded market walk realigning. Everything is a mean over four.

### The measured baseline (before the term)

| profile | netWorth | vs job | trade margin | peak Heat | arrests |
| --- | --- | --- | --- | --- | --- |
| `legal_worker` | 1,553 | **100%** | n/a | 0.0 | 0 |
| `hustler` | 16,730 | **1077%** | +38.8% | 0.0 | 0 |
| `arbitrage` | 5,961 | **384%** | +23.6% | 0.0 | 0 |
| `flipper` | 61 | 4% | n/a | 0.0 | 0 |
| `trader` | 33 | 2% | +0.0% | 0.0 | 0 |

**194 units moved for exactly 0.0 Heat.** The premise is confirmed and it is
worse here than in the web build, which at least had a structurally-zero BUY
term — `economy.gd` contains no reference to heat at all.

**The second gap does not transfer.** The web build's "pure crime is
capital-constrained at 17%" is not this port's problem: `arbitrage` is at 384%
and the binding constraint is CARGO, not capital. Every capital-curve lever that
ticket lists — transportation, a bank, more lenders — would have been actively
harmful here. That finding alone justified re-running.

### Three structural findings

1. **Heat has no teeth on the trading path.** `gs.heat` is read in exactly five
   places: Stickup's success chance, the job interview roll, Exposure's
   broadcast thresholds, Lay Low's relief cap, and the arrest gates inside
   Boost's and Stickup's consequence chains. A courier who never lifts and never
   robs touches none of them. Heat pinned at 15.0 in the sweep and the run
   carried on exactly as before. **Heat 15 does not end a run in this port.**
2. **Rotation defeats per-district memory.** Market Pressure caps at +1 per
   district per day and sheds 1.5-2.0 on a quiet one, so a courier alternating
   two districts never reaches even KNOWN — measured peak 1.75 against a
   threshold of 3.0. The stationary `trader` hit 9.0 and felt the whole penalty;
   the profile that was actually winning never saw it.
3. **In-market spread is exactly zero.** `_buy` charges `prod.price * qty` and
   `_sell` credited the identical figure. Every dollar of trading profit is
   cross-district arbitrage. `trader` moved 130 units for a net trade of $0.
4. **Jobs are Spenard-only**, so the route and the shift compete for whole DAYS,
   not slots (`shift_blocker`: *"Every canon job is in Spenard, so this is really
   'are you home'"*). A hybrid that does not go home to work does neither well.

### The term

Four legs were designed. Three were measured and rejected as the main lever,
and the rejections are the design:

| leg | measured effect | why |
| --- | --- | --- |
| Heat on SELL | 382% → 382% | no teeth on this path (finding 1) |
| Pressure price penalty | 382% → 382% | defeated by rotation (finding 2) |
| A slot for the handoff | 369% → 413% | slots are not the constraint; the courier has idle days |
| **The carry** | **384% → 90%** | scales with cargo, which IS the constraint |

**All four shipped anyway**, because the three that do not move the number are
each correct on their own terms and each closes a hole: the sale finally writes
Heat (and finally gives `HeatSystem`'s `market` district multiplier — authored
in FS-003.9, never once fired — something to scale), the corner that has watched
you pays less, and the carry is the leg with the teeth.

```gdscript
MARKET_SELL_HEAT_PER_DOLLAR := 0.006   # capped at 1.5 raw per sale
MARKET_PRESSURE_PRICE_SCALE := 1.0     # x the band's authored penalty
CARRY_STOP_BASE  := 0.010
CARRY_STOP_PER_UNIT := 0.006
CARRY_STOP_PER_HEAT := 0.006
CARRY_STOP_PER_PRESSURE_STEP := 0.025
CARRY_STOP_MAX := 0.55
```

A stop's OUTCOME is the existing resolver's `escape` shape read against
Intelligence, not a second dice table. Clean is a walk; messy takes a third of
the bag; failure and catastrophic take all of it. **A seizure is not a fine** —
it takes product and never touches the wallet, asserted.

The sell price is now two numbers, and the Market screen shows both: the board
price, and what a sale here actually pays. Both read
`economy.sell_unit_price()` — the same function the reducer credits from,
because a preview that re-derives is a second implementation of the price.

### After

| profile | netWorth | vs job | margin | seizures | dead ends |
| --- | --- | --- | --- | --- | --- |
| `legal_worker` | 1,553 | 100% | n/a | 0.0 | 0% |
| `hustler` | 14,467 | 932% | +33.1% | 2.8 ($1,725) | 0% |
| **`arbitrage`** | 1,401 | **90%** | **+6.2%** | 2.0 ($1,144) | 0% |
| `flipper` | 61 | 4% | n/a | 0.0 | 0% |
| `trader` | 33 | 2% | +0.0% | 0.0 | 0% |

**The pure courier route: 384% → 90%**, inside the design position's 70-90%
band, with a margin that is still positive — the route survives its own risk
term, which was the point.

### What is NOT fixed, and why it is a design call rather than another sweep

**`hustler` is at 932%.** A value-scaled carry term is the only thing that
reaches it, and it was built and swept:

| per $100 of bag | `hustler` | `arbitrage` | `arbitrage` margin | dead ends |
| --- | --- | --- | --- | --- |
| 0.000 | 932% | 90% | +6.2% | 0% |
| 0.008 | 487% | 46% | −10.4% | 25% |
| 0.020 | 263% | 2% | −19.1% | 25% |

**The two profiles move in opposite directions and no rate puts both in band.**
The reason is structural, not a matter of rate: **wages are insurance.**
`hustler` has a floor under it, so a seized bag is a bad week; `arbitrage` is
carrying its whole capital, so the same bag is the run. Pricing the carry by
value therefore taxes the fragile strategy harder than the robust one, which is
backwards.

Whether a day job should insure criminal risk is Marcus's call, not a sweep's.
`CARRY_STOP_PER_100` ships at 0 — expressed rather than deleted, the way
`PRESSURE_QUIET_GRACE_DAYS` is — with the surface above recorded beside it.

**Arrests are still 0 for traders.** The carry has no arrest gate, deliberately:
that converts a balance change into a lose-condition change, and it wants its
own vertical slice the way FS-003.7 was one.

### Sabotage log

| # | Injected fault | Result |
| --- | --- | --- |
| T-S1 | `MARKET_SELL_HEAT_PER_DOLLAR` → 0 | ✅ 2 failures |
| T-S2 | district multiplier dropped from the sell gain | ✅ 1 failure |
| T-S3 | `MARKET_PRESSURE_PRICE_SCALE` → 0 | ✅ 1 failure |
| T-S4 | carry stop chance flattened | ✅ 4 failures |
| T-S5 | `_sell` credits the board price again | ✅ 1 failure — *"the sell action pays the price the screen shows: got 728, want 554"* |

## Batch 4 — The Stickup Ladder  (added 2026-08-22)

Branch `codex/batch-4-crime-progression`, from `main` at `63a5ffd`. The second
commissioned design gap: *"the pure-crime path is too heavily constrained by
capital — design progression options, pressures and decision-making beyond cash
requirements."*

**Parity: 11,273 checks, 0 failures** (from 11,248). Floor 11,238 → 11,263.
Save schema unchanged at v10.

### The premise is false, and something worse is true

Batch 3's instrument already showed the web ticket's capital-constraint reading
does not transfer — the courier route measured at 384% of the day job, limited
by cargo rather than capital. So this batch extended the instrument to the two
surfaces nobody had ever measured, `stickup` and `boost`, and found the real
gap immediately.

**`stick_tier` is written exactly ONCE in the entire repository:**

```
$ grep -rn "stick_tier *=" --include="*.gd" .
autoload/game_state.gd:344:	stick_tier = 1
```

That is `reset_to_new_game()`. There is no `_update_tier()` in `stickup.gd`.
`stick_rep` is incremented on every successful take and **read by nothing** — a
counter that costs a save field and does no work.

`visible_targets()` and `blocker()` both gate on `int(t["tier"]) > gs.stick_tier`,
so for the entire life of every run **four of the nine authored stickup targets
were unreachable**: both tier-2 tills, the dice game behind the rec center
($500-1200) and Goodie's stash ($800-1500) — the two biggest paydays on the
surface. Dead content, authored and shipped and never once seen.

**The tell was in the test harness.** `_simulate` sets `gs.stick_tier = 3` by
hand. The only thing in this build that had ever exercised the upper tiers was a
test that skipped the climb — which is exactly how a missing progression hides,
and the same hazard class the web build named after four builds with false
premises.

### The rungs

Shaped after `BoostSystem._update_tier()` deliberately: the two ladders are the
same idea told twice, and a second shape would be a second thing to reason
about.

```gdscript
const STICK_TIER2_REP := 4
const STICK_TIER3_REP := 11
const STICK_TIER3_NEEDS_FIELD_CREW := true
```

Rep is the count of jobs that came off, so the ladder is climbed **by doing the
work rather than by paying for it** — which is the whole point of it being a
progression rather than a purchase, and the direct answer to "beyond cash
requirements". Tier 3 additionally wants somebody who can be put somewhere, the
same gate Boost's tier 3 reads and for the same reason: the top of the ladder is
where the work stops being something you do alone. Canon already treats tier-3
stick work as organised — it tells Curtis about the second one over the network.

The ladder only goes up. Losing the crew does not close the room.

### The criminal surfaces, measured against the job for the first time

Two new instrument profiles that climb their own ladders rather than being
handed a tier:

| profile | netWorth | vs job | jobs | take | arrests | reached | dead ends |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `legal_worker` | 1,553 | **100%** | — | — | 0 | — | 0% |
| `boost` | 471 | **30%** | 20.0 | $641 | 1 | boost tier **1.8** | 0% |
| `stickup` | 25 | **2%** | 50.8 | $558 | 9 | stick tier **2.0** | **50%** |

The ladder demonstrably climbs in play — `stickup` reaches tier 2 and `boost`
averages 1.8 — where before the fix both were pinned at 1 forever.

### The finding that is NOT fixed here, with numbers

**Both criminal surfaces are below the design position's 50% floor, and
`stickup` is not viable at all.** Fifty jobs across a month return $558 — about
$11 a job — against nine arrests and half the runs ending. The ladder is
necessary and it is not sufficient: reaching tier 2 does not save a surface
whose attempt economics are that thin.

That is a numbers call, not a missing mechanism, and this project's own rule is
that balance findings become follow-up tasks rather than in-flight fixes
(FS-003.12's brief, verbatim). Filed for Marcus with the table above. What this
batch was able to establish is the thing that was missing: **there is now an
instrument that can tell whether a change to those numbers helped.**

### Sabotage log

| # | Injected fault | Result |
| --- | --- | --- |
| L-S1 | `_update_tier()` call removed from the success branch | ✅ 1 failure — "the ladder climbs from work alone" |
| L-S2 | `STICK_TIER2_REP` → 99 | ✅ 3 failures |
| L-S3 | field-crew gate dropped from tier 3 | ✅ 1 failure — "tier 3 wants a crew that can be put somewhere: got 3, want 2" |

## Batch 5 — The Route, Made Visible  (added 2026-08-22)

Branch `codex/batch-5-route-visible`, from `main` at `e7b697e`.

**Parity: 11,311 checks, 0 failures** (from 11,273). Floor 11,263 → 11,301.
Save schema unchanged at v10.

### The problem, in one sentence

Batch 3 measured the cross-district courier route as the only strategy in the
game that clears the day job — and **there was no surface anywhere that could
see it**. `economy.sell_unit_price(district_id, product_id)` had always been able
to price a remote district; nothing had ever asked it to. The economy instrument
had to read `gs.markets` directly to play the route, which is the tell: a
strategy only a test can find is not a strategy the player has.

### The authored line was worse than nothing

The Market screen's hint row rendered `p.hint` — a string in the product table:

```gdscript
{"id": "weed", ..., "hint": "SELL SHIP CREEK  +$11", "trend": "up", ...}
```

`economy.evolve()` walks every price every night. That line was true on the day
somebody wrote it and a standing false claim every night after. Seven of the
eight products carried one.

### What shipped

**One substrate, two surfaces, one gate.**

`economy.best_route(product_id)` is the substrate: the best district to take a
product to from where the player stands, what it pays, and which way that corner
is moving. Three things about it matter:

- It reports what a sale THERE would **actually pay** — `sell_unit_price`, not
  the board price — so a corner you have burned is discounted *before* the trip
  rather than being a surprise on arrival.
- It only considers districts in `districts_unlocked`. Word reaches you about
  places you know about.
- `price_trend()` reads `markets[district].history`, which `walk_evolve_area` has
  been keeping (canon's last eight prices) since the market walk was ported and
  **nothing had ever read**.

**Surface 1 — the Market row.** The hint line is live. Three states: a route, no
route ("NOBODY PAYING OVER THE ODDS"), or no line ("NO WORD — LINE IS DEAD").
Locked products keep their authored line, because "NEEDS SHIP CREEK TURF" is a
fact about the world rather than a price claim.

**Surface 2 — Word Around Town.** The Phone section already existed, already went
quiet offline, and already spoke about districts in prose. It now leads with what
product is going for elsewhere, capped at three routes so it stays a rumour
rather than a spreadsheet, then the ambient lines underneath.

**The gate is the phone bill.** Both surfaces go dark when the line does. This is
the honest fiction — you find out what Downtown pays because somebody tells you —
and it is the first mechanical thing the $75/week has ever bought. Losing service
used to mean a quieter inbox; it now means the city goes dark and you trade on
what is in front of you.

### Sabotage log

| # | Injected fault | Result |
| --- | --- | --- |
| R-S1 | `best_route` ignores `districts_unlocked` | ✅ 1 failure — "got 5, want 0" |
| R-S2 | the Market hint reads `p.hint` again | ✅ 3 failures — the authored strings reappear in the render |
| R-S3 | `market_intel` ignores `phone_active` | ✅ 1 failure |
| R-S4 | `best_route` quotes the board price instead of what a sale pays | ✅ 2 failures |

R-S2 is the one worth noting: the check does not assert what the line *says*, it
asserts that **none of the seven authored hint strings appear in the rendered
screen at all**. That is the only way to prove a live read replaced a static one
— asserting the new text would pass just as happily with the old code still
there beside it.

### Not changed

The economy instrument's numbers are unmoved (`arbitrage` 90%, `hustler` 932%),
and they should be: the harness always read `gs.markets` directly, so making the
route visible changes what a *player* can see, not what a simulation could
already do. That is the entire point of the build.

## Batch 6a — The Operation Substrate  (added 2026-08-22)

Branch `codex/batch-6a-operation-substrate`, from `main` at `4bb5c98`.
Infrastructure half of the crew-operations work, split out so the content half
(6b) lands against a seam that already exists and is already tested.

**Parity: 11,330 checks, 0 failures** (from 11,311). Floor 11,301 → 11,320.
Save schema unchanged at v10, and **no bump is needed for new operations** —
`crew_assignments` and `crew_operation_state` have been whole-Dictionary
`PERSIST_FIELDS` since v7 and the validator does not inspect them.

### Why the coordinator could only ever hold one operation

`crew_operations.gd`'s header forbids `if operation_id ==` branches. It did not
need one, because the coupling was worse than a branch: **every player-facing
string was a const or a private method on the coordinator itself.**

```gdscript
const CALLBACK_FROM := "Pherris"
const DISCOVERY_TEXT := "I been watching how you move product on that list. ..."
const LOYALTY_WARNING_TEXT := "I'm not feeling like running errands right now. ..."
func _assignment_line(...)   # "Pherris is running your board today. ..."
func _settlement_text(...)   # reads settled_count / gross / profit_or_loss
```

The coordinator could say one thing, in one person's voice, about one kind of
work. A second operation had nowhere to put its own words.

### The seam

Four OPTIONAL adapter methods, all checked rather than required, because an
adapter that only knows how to `settle()` is still a valid adapter:

```gdscript
sender() -> String
discovery_text() -> String
loyalty_warning_text() -> String
assignment_line(selection, spend_limit) -> String
settlement_text(assignment) -> String
```

Pherris's strings moved into `list_adapter.gd` verbatim. The old consts remain
as the coordinator's fallbacks, which is what an adapter that declines to speak
inherits — and what a registered-but-half-built adapter gets instead of an empty
string at the player.

**Plus a `params` passthrough.** `spend_limit` was the only field the assignment
dispatch ever read, so an operation needing a TARGET — a district to work, a
corner to stand on — had nowhere to receive one. Carried as an opaque Dictionary
the coordinator never inspects; the adapter owns its shape. Absent means `{}`
rather than `null`, so an adapter can read it without checking.

**Capability IDs are constrained and it is worth writing down why.**
`tests/parity/fixtures/requirements/fs001_fixtures.json` asserts
`eli/territory_operations` and `deshawn/network_operations` are `has: false` at
rank 3. Those two IDs are burned; 6b must not use them.

### Three honesty defects in batch 5's route line

Each found by reading the shipped surface rather than by a failing test, which
is why each now has one.

1. **A route you cannot stock is not a route.** `best_route` reported the spread
   without checking the local corner had any to sell you, so a sold-out product
   still advertised somewhere to take it.
2. **A one-dollar spread is arithmetic, not a trip.** The trip has to clear its
   own $5 bus fare before it is reported as a route.
3. **Two different silences.** Before a first corner is held the player knows
   exactly one district, so there is nowhere for word to come FROM. That is a
   map problem, and it was reading as a market conclusion — "NOBODY PAYING OVER
   THE ODDS", on all eight rows at once. It says "NO OTHER BOARD YOU KNOW OF"
   now.

### The route count is pinned, and that is a floor fix

The route-visibility section looped over however many routes the board happened
to offer, asserting three things about each. That makes the section's
contribution to `_checks` move whenever the economy does — and it did, dropping
7 the moment the availability and fare rules disqualified some routes. A floor
exists to catch a section aborting, not to absorb that. The count is asserted
explicitly now and the loop is bounded by it, so an economy change shows up as a
named failure rather than as floor drift.

### Sabotage log

| # | Injected fault | Result |
| --- | --- | --- |
| 6a-S1 | availability check dropped | ✅ 3 failures |
| 6a-S2 | fare floor dropped | ⚠️ **PASSED** first time — see below |
| 6a-S3 | the two silences collapsed | ✅ 2 failures |
| 6a-S4 | `_adapter_copy` always returns the fallback | ✅ 4 failures |
| 6a-S5 | `params` dropped from the assignment record | ✅ 2 failures |

**6a-S2 is the second sabotage this session to pass on the first attempt**, and
for the same shape of reason as S11 in v0.1.0: the assertion swept every route
on the probe board for a sub-fare edge, and no route on that board happens to
have one, so removing the floor left it green. A sweep over data that does not
contain the case proves nothing. The case is now BUILT — a spread set to exactly
the fare, asserted as not-a-route, then one dollar over, asserted as one — and
the sabotage then failed correctly.

## Batch 14: the visibility pass, and Boost's second axis  (added 2026-08-22)

Four playtest findings and one design debt. They arrived as five separate
complaints and they are one defect: **the build showed the player everything at
once and then said nothing about what any of it did.**

The Hustle hub opened with six income surfaces on Day 1, four unusable and none
ordered. The Home Market Snapshot sat greyed under a padlock with real product
names and real prices under it. Wander produced eleven different outcomes and
announced all of them as "You take a walk." POST ELI and LAY LOW were drawn on a
card the gate system hides for the whole of a fresh run. And Boost had exactly
one axis — tier — so its board opened at its widest and every permanent ban
narrowed it for good.

### The amended LOCKED/HIDDEN rule

v0.1.0 drew the line as "progression is LOCKED, population is HIDDEN". That rule
produced both of this batch's UI findings, so it is now stated differently:

> **LOCKED is for a surface the player is MEANT TO KNOW ABOUT and has not
> earned.** A padlock is a promise, and a promise is only worth making about a
> thing the player can go and do something about. Everything else is HIDDEN.

Jobs still earns a lock — "Meet someone who hires" is an instruction and Jobs is
the authored on-ramp. The Hustle ladder's other five rows do not: six padlocks on
a fresh run is the same wall of unusable surface with an apology written on it,
and not one of the hints would have been actionable. The Market Snapshot failed
the rule from the other side — a padlock over live-looking content reads as a
broken feature, not a coming one.

The change itself was one line per surface, which is the payoff the design pass
promised: `mode` is presentation metadata, so a surface moves between the two
without a single screen learning a new condition.

### The Hustle ladder, and why two axes

Five rows, five gates, two facts:

| Row | Opens on | Why that axis |
| --- | --- | --- |
| Street Market | 1 walk | the corner you buy from is a place you found |
| Boost | 3 walks | you notice what is loose by walking past it enough |
| Stickup | day 2 | desperation arrives fast |
| 907List | day 3 | word gets around after a couple of days |
| the shark | day 5 | it takes time to learn who needs money |

WALKS gate what you find by being out; DAYS gate what arrives because time
passed. Neither substitutes for the other, which is what stops a player who only
walks and a player who only sits from converging on the same screen.

Two new requirement types carry them — `day_min` and `wander_count_min` — added
to the one evaluator rather than beside it, and against facts GameState already
held. That is the standing condition for a new type landing at all: a gate whose
fact has not been built yet stays unbuilt.

### Boost's second axis, and the measurement that changed the design

`boost_targets_discovered` is a one-way latch, the same shape as
`districts_unlocked`. A room is on the Boost board because the player clocked it
on a `LOOK FOR A DEAL` walk. The pool a walk draws from is district-scoped,
tier-scoped and minus what is already clocked — so climbing the Boost ladder puts
NEW rooms into the discovery pool, and tier progress and walking the block feed
each other instead of racing.

The filter is in `visible_targets()` **and** in `blocker()`. The first decides
what a screen draws; the second decides what a dispatch may do. A presentation
filter with no rule under it is a list you can walk around by calling the action
directly.

**The instrument disagreed with the brief, and the brief lost.** The claim being
shipped was "a renewable pool that survives bans". The first `boost_finder`
profile — a run that starts with nothing clocked and earns its board — measured
that claim and found it **false as stated**:

```
boost         3.5 bans · 0.0 rooms still workable   ($201, 13% of job)
boost_finder  3.5 bans · 0.0 rooms still workable   ($24,   2% of job)
```

Spenard carries two tier-1 rooms and two tier-2. The profile clocked all of them,
burned all of them, and ended thirty days with an empty screen — exactly like the
profile that was handed twelve targets on day one. The refill is real, but it is
**cross-district**, and a profile that never leaves cannot see it.

So the profile learned to move on when a block is finished — nothing left workable
AND nothing left to clock — at the honest price of a fare and a slot:

```
boost         3.5 bans · 0.0 rooms still workable   ($201, 13% of job)
boost_finder  7.5 bans · 1.5 rooms still workable   ($113,  7% of job)
```

**That is the claim, measured.** The profile that earns its board absorbed more
than twice the permanent bans and still ended with rooms open, where the profile
handed the whole board ended with none.

The cost is on the record too, and it is not small: 13% → 7% of the day job.
Roughly half the yield goes to walking and fares. Boost was already the weakest
criminal surface with a filed anomaly under it (`CAUGHT_EFFECTS talk/messy` is
the only row where a SUCCESS tier permanently bans), and this batch makes the
early game harder before the pool starts paying back. **Reported, not tuned** —
the ramp and the pool are numbers a design pass should move deliberately, and the
instrument that would measure the move now exists.

### The wander toast, and a spec defect worth naming

Wander wrote to the activity feed and nothing else, so the toast said "You take a
walk." The line now comes off the feed — `activity_log[0]`, the row the card just
wrote — rather than being reconstructed from the dispatch's `kind`. Translating a
kind back into copy would be a second author for the same event, one toast out of
date the first time a card is reworded.

The brief specified two `show_toast()` calls on a day crossing, one for the walk
and one for the day. **There is one toast node for the whole session and a second
message replaces the first** (`ui/components/toast.gd`, which says so in a
comment), so that would have shown the day and swallowed the walk — the exact
line the change exists to surface. The day is appended as a second line instead.

The brief's staleness guard had the same shape of bug: it compared the feed row's
`day` against `gs.day`, but a card writes BEFORE the slot advances, so on every
day crossing the row is dated one behind and the guard would always fall back.
It compares against the pre-walk day.

### POST ELI and LAY LOW

Both were drawn on the operation card. `_bind_gates` hides that card whenever
there is no operation out, no rent crunch and no workable shift — which is a
fresh run in its entirety. So both actions were rendered on a node that had
already left the layout, for exactly the part of the run that most needs a door.

They have their own card now (`WHAT ELSE`, directly under Wander) on their own
condition. `SurfaceVisibility.home_actions()` answers which of them EXIST, and
its SIZE is the gate — one derivation, so the card cannot be visible with nothing
on it or filled with buttons that do nothing. A button whose action is not on the
list is hidden rather than disabled: a greyed LAY LOW on a run at full health
with no Heat explains a mechanic the player has no reason to have heard of.

The operation card now carries no controls at all. Every button it ever had has
moved to a card that is there when the button is usable — MOVE PRODUCT to the
Wander card in batch 13, these two here.

### Verification

| Gate | Before | After |
| --- | --- | --- |
| Parity | 11,887 / 0 | **12,249 / 0** (floor 11,860 → **12,239**) |
| Save validation | 82 / 0 | **96 / 0** |
| Screen smoke | 23/23 | 23/23 |
| Glyph coverage | ok | ok |

200 of the 362 new parity checks were not written. `GATE_CASES` is data-driven,
so the five Hustle rows and the actions card each brought the whole fresh-run,
mode, blocker-shape, threshold, isolation and save/load battery with them for six
lines of table — the design pass's "data-driven rather than one bespoke test per
button" paying its way three batches later.

`_fresh_gate_run` moved from day 3 to day 1. It had been an arbitrary number
picked when nothing read it; the day is a gate fact now, and leaving it would
have had the fresh-run assertion pass 907List and Stickup before it started.

### Sabotage log — 14 run, 14 caught

| Sabotage | Caught by |
| --- | --- |
| every Hustle gate's `min` → 0 | 97 failures, led by "a fresh run locks hustle.market" |
| `HUSTLE_STICKUP` reads walks instead of days | "hustle.stickup unlocks at its trigger" |
| `day_min` uses `>` instead of `>=` | "day_min passes exactly at the line" |
| drop the discovered filter from `visible_targets` | "a fresh run can see nothing to lift" (got 5, want 0) |
| drop the discovered arm from `blocker()` | "and a lift on one is refused outright" |
| any intent can clock a spot | "only a walk that went looking for a deal clocks a spot" |
| drop the tier filter from the discovery pool | "a tier-3 room is not something a tier-1 player notices" |
| a boost find does not reset the drought | "finding something resets the drought" (got 2, want 0) |
| a missed DEAL walk does not climb the ramp | "a missed deal walk climbs the same drought" |
| revert the wander toast to the generic line | "the toast says what the walk turned up" |
| drop the toast's day guard | "a stale feed row is not quoted as this walk's outcome" |
| the actions card inherits the operation card's condition | "and the actions card arrives" |
| `HOME_MARKET_SNAPSHOT` back to LOCKED | "a fresh Home hides the market snapshot" |
| delete the v14 → v15 migration arm | 88 failures **and the check floor**, which is the floor doing its job |
| drop the validator's authored-catalogue branch | save validation: "an unknown target id drops" |
| return early instead of defaulting a wrong-type latch | save validation: "a wrong-type latch defaults to nothing clocked" |

**One sabotage escaped on the first pass and the check was rewritten.** Removing
`gs.wander_misses = 0` from `_discover_boost_target` left the suite GREEN: the
check asserted the drought counter was zero after a find, on a run whose setup
had already zeroed it. It is an assertion that could not fail. The sweep now
seeds two misses before each walk, which also bought a second check — that a
missed DEAL walk climbs the same ramp a missed WORK walk does.

### Two harness rules this batch re-learned

- **`size.x` is not a width in a headless run.** The first 375-overflow checks
  measured laid-out size and failed on three screens that fit fine.
  `_fs001_render` already owns that rule and knows the thing a headless check has
  to know — a DECLARED minimum is trustworthy where a laid-out size is not. The
  duplicate was deleted and the three call sites now go through the one owner,
  which also holds every visible button on the new card to 44pt for free.
- **A check whose setup satisfies its own assertion is not a check.** See the
  escaped sabotage above. The tell is an assertion against a value the fixture
  writes.

### Migration note, v14 → v15

`boost_targets_discovered` is additive and the arm stamps the version only. This
is the one arm in the chain where the empty default is generous to nobody: a v14
run could have been lifting Northern Value for a fortnight and comes back with
the shop off its list until it walks past again.

There is no third option, and it is worth writing down why. Stamping in every
target in range hands a loading save the whole board — precisely what this batch
removed. Stamping in the ones it has HIT needs `boost_daily_hits`, which is one
day deep and holds nothing about the run before today. The field did not exist, a
v14 build never asked the question, and the honest reading is that the run has
never been out looking.

`boost_store_bans` is deliberately untouched. **A ban is a face somebody
remembers, not a place you forgot** — re-finding a shop you are banned from does
not un-ban you, and the blocker still refuses it in the order it always did.

### Open, for whoever picks this up

- **The other five discovery axes.** Stickup targets, borrowers, 907List items,
  the crew roster, the venues and all five NPCs are still visible from day one.
  Boost went first because discovery also fixed something there. Stickup is the
  obvious next one and has a filed balance problem of its own that a discovery
  axis will not solve.
- **Boost at 7% of the day job.** Reported, not tuned. The levers are the
  discovery ramp, the pool's tier filter, and the `CAUGHT_EFFECTS talk/messy` ban
  anomaly that has been pinned since FS-003. `boost_finder` is the instrument for
  any of them.
- **Five `.uid` files are missing from the repo** (`data/wander_events.gd`,
  `systems/venues.gd`, `systems/wander.gd`, `ui/screens/night_owl.gd`,
  `ui/screens/spenard_gym.gd`). Godot regenerates them on import, but a
  regenerated UID is not the committed one, so `uid://` references can differ
  between machines. Left out of this PR as unrelated churn; worth a one-line
  commit of its own.

---

## Where the build stands (end of the 2026-08-22 session)

One place to orient before reading anything else below.

| | |
| --- | --- |
| Build version | `0.1.0` (`autoload/version.gd`) |
| Save schema | **v15**, migration ladder walks v1 → v15 |
| Parity | **12,249 checks, 0 failures**, floor `MIN_CHECKS := 12239` |
| Save validation | 96 checks, 0 failures — **a CI gate as of batch 12** |
| Screen smoke | 23/23 screens instantiate — **a CI gate as of batch 12** |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 23 |
| Systems | 28 registered in `GameManager` |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Branches | `main` only; every batch branch merged and deleted |

**The economy, measured** (30 days × 4 seeds, `_check_economy_profiles`). Every
percentage is against `legal_worker`:

| profile | net worth | % | note |
| --- | --- | --- | --- |
| hustler | $11,372 | 732% | trade + job; the ceiling |
| flipper | $5,566 | 358% | 907List |
| worker_wanders | $4,457 | 287% | **the strongest clean path** — zero Heat, zero arrests |
| legal_worker | $1,553 | 100% | the baseline, and see the caveat below |
| arbitrage | $1,288 | 83% | |
| boost | $201 | 13% | handed all twelve targets on day 1; 3.5 bans a run, and it ends with **nothing left workable** |
| boost_finder | $113 | 7% | batch 14 — earns its board and moves when a block is finished. 9.0 targets clocked, **7.5 bans absorbed, and still 1.5 rooms open on the last day** |
| wanderer | $36 | 2% | walking with no job — correctly a trap |
| trader / stickup | ~$30 | 2% | |

**Read the baseline caveat before quoting any of those.** `legal_worker` never
leaves Wash & Go, which is now a player ignoring a free mechanic — and
`ECON_JOB` is not even the best starter shift (`spenard_chevron` pays [48, 60]
against [40, 60]). Re-baselining moves every number in this file and is a design
call, not a hardening one.

**Filed for design, not taken** (item 3 was taken in batch 14 and is kept below
with what actually happened, because the shape of the finding is still the useful
part):

1. **Stickup is under-powered on its own terms.** ~4.6hp expected damage an
   attempt against a ~$11 take. Every cost lever was swept (injuries off → 8%,
   free first aid → 8%, arrests removed → 0%) and a crew-backed profile carrying
   a rank-3 Tone made **no difference**. Take ×3 only reaches 18%.
2. **`CAUGHT_EFFECTS talk/messy` is the binding constraint on Boost** — the only
   row where a SUCCESS tier permanently bans, and 3.5 of 4 Spenard targets are
   banned per run. Changing it was measured at 13% → 15%; narrowing bans to
   catastrophic only was 50% in a scratch tree. It is transcribed from FS-003 §5
   and the web build is the oracle, so it is pinned as an anomaly rather than
   fixed.
3. ~~**`jobs_discovered` is the ONLY discovery axis in the build.**~~ **Half
   taken in batch 14.** Boost targets are now discovered on a `LOOK FOR A DEAL`
   walk, which is what the intent had been missing — it could weight the draw
   and had nothing to find. Stickup targets, borrowers, 907List items, the crew
   roster, the venues and all five NPCs are **still visible from day one**, and
   each is a candidate for the same treatment. Boost was taken first because it
   is the surface where it also fixes something: a ban is permanent by target
   id, so its board could only ever shrink, and discovery is the first thing
   that ever put a room back on it.

**Harness lessons that cost real time this session, all now guarded:**

- `git stash` restores `project.godot` and re-arms the editor-only `godot_ai`
  autoload. Every "is main green?" comparison run across a stash boundary loaded
  the editor helper and failed 8-17 checks that looked exactly like regressions.
- A parse error in `parity_runner.gd` does not FAIL the run, it HANGS it. A
  sabotage that runs long should be suspected of not compiling first.
- Sabotage copies need `.godot/` or every `uid://` breaks and the copy has a
  37-failure baseline, which makes every sabotage look red for the wrong reason.
  **Always establish the baseline in the copy.**
- The suite was not idempotent until batch 6b: `_check_economy_profiles` plays
  thirty days of real dispatches and never restored `user://907hustle_run.save`.

---

## Overnight Build Log — 2026-08-22

Autonomous loop. Each entry: branch, tasks, parity, outcome.

| # | Branch | Tasks | Parity | Outcome |
| --- | --- | --- | --- | --- |
| — | `claude/v0.1.0-playtest-polish-b4nlnx` | v0.1.0: versioning · surface visibility · seeded key audit · HOT lever · phone tap target · canonical locations | 10,781 → 11,110 | Merged, PR #53. Save v9 → v10. |
| 1 | `codex/batch-1-hardening` | A1 settlement day · A2 board fill (verified + guaranteed) · A3 crew capacity (verified + guaranteed) · A4 dispatch guards | 11,110 → 11,147 | Merged, PR #54. Schema unchanged. |
| 2 | `codex/batch-2-docs-and-glyphs` | B2 settlement contract · B1, B3, C1, C2, C3 verified | 11,147 → 11,177 | Merged, PR #55. No production behaviour changed. |
| 3 | `codex/batch-3-trading-risk` | The economy instrument · the trading path's risk term (sell Heat · corner pricing · the carry) | 11,177 → 11,248 | Merged, PR #56. Pure courier route 384% → 90% of the day job. |
| 4 | `codex/batch-4-crime-progression` | The Stickup ladder (`stick_tier` had no writer) · criminal surfaces measured against the job | 11,248 → 11,273 | Merged, PR #57. Four dead targets reachable; stickup at 2% filed for balance. |
| 5 | `codex/batch-5-route-visible` | The route made visible — live Market route line · Word Around Town prices · both gated on the phone bill | 11,273 → 11,311 | Merged, PR #58. Seven authored route strings retired. |
| 6a | `codex/batch-6a-operation-substrate` | Adapter-supplied delegation copy · `params` passthrough · three honesty defects in the route line · route count pinned | 11,311 → 11,330 | Merged, PR #59. No schema bump needed for new operations. |
| 6b | `codex/batch-6b-crew-operations` | Tone absorbs damage at both sites · Eli covers the carry · Deshawn works a corner · per-operation callback flags · the unauthored shark term | 11,330 → 11,402 | Merged, PR #60. Schema unchanged — 6a's substrate held. |
| 7 | `codex/batch-7-venue-interiors` | Spenard Gym · Night Owl · `effectiveAttribute` + the gym streak ported · the `night_owl` job made findable | 11,402 → 11,493 | Merged, PR #61. **Save v10 → v11.** |
| 8 | `codex/batch-8-heat-teeth` | Heat bands · the quiet-day decay · the street stop · Lay Low capped · the propagation inversion fixed | 11,493 → 11,576 | Merged, PR #62. **Save v11 → v12.** |
| 9 | `codex/batch-9-balance-pass` | **The instrument was lying** — a leaked catalogue corrupted every economy number since batch 3 · the class closed · two balance findings filed with live numbers | 11,576 → 11,622 | Merged, PR #63. Schema unchanged. |
| 10 | `codex/batch-10-wander` | **Wander** — the ramped discovery, the card registry, a fourth chain kind · Home's three dead buttons · two unreachable jobs made findable | 11,622 → 11,723 | Merged, PR #64. **Save v12 → v13.** |
| 11 | `codex/batch-11-wander-followups` | An adversarial read of batch 10 found five shipped defects · all five fixed · adapter-supplied choice copy · the glyph CI job now scans `data/` | 11,723 → 11,761 | Merged, PR #65. Schema unchanged. |
| 12 | `codex/batch-12-measure-wander` | **Wander measured** — 307% of the day job · the discovery→money mechanism pinned · the other two harnesses gated in CI | 11,761 → 11,780 | Merged, PR #66. Schema unchanged. |
| 13 | `codex/batch-13-wander-intents` | Wander becomes a choice — three intents · per-day effort falloff · READ, the intent that tells you what the build hides | 11,780 → 11,887 | Merged, PR #67. **Save v13 → v14.** |
| 14 | `claude/batch-14-visibility-discovery-trbd0v` | The visibility pass — the Hustle ladder · the snapshot LOCKED → HIDDEN · the wander toast · POST ELI and LAY LOW re-homed · **Boost's discovery axis** | 11,887 → 12,249 | **Save v14 → v15.** |

**Two verification defects found in batch 6b, both in the harness rather than
the game, both now fixed:**

- **The suite was not idempotent.** Run 1 on a clean `user://` passed 11,330;
  run 2 failed 19. `_check_economy_profiles` (batch 3) plays thirty days of real
  dispatches per profile, `SaveSystem` autosaves on every successful dispatch,
  and unlike `_simulate` it never saved or restored `user://907hustle_run.save`.
  It now captures the file at the start of the section and restores it — or
  deletes it, if there was none — at the end. Consecutive runs now agree.
- **`git stash` silently re-armed the editor-only autoload.** The working tree
  carries `project.godot` with `_mcp_game_helper` and the `godot_ai` editor
  plugin stripped, because they must not load headless. `git stash push`
  reverts that file to HEAD, so every "is main green?" comparison run through a
  stash was loading the editor helper and failing 8-17 checks in ways that
  looked like real regressions and were not. Several hours went into chasing
  them. Headless runs now go through a script that strips the autoload if it is
  present and always starts from a cold `user://`; never run the suite across a
  `git stash` boundary without checking `project.godot` first.
- **Sabotage runs need the import cache.** Copying the tree for parallel
  sabotage without `.godot/` gives a 37-failure baseline (unresolved `uid://`
  references break every screen check), which makes every sabotage look red for
  the wrong reason. Always establish the baseline in the copy before trusting a
  sabotage result.

**Heat, measured after batch 8.** The economy instrument now counts street stops
separately from carry stops. Over 31 days and 4 seeds:

| profile | net worth | peak heat | street stops | taken |
| --- | --- | --- | --- | --- |
| legal_worker | $1,553 (100%) | 0.0 | 0.0 | $0 |
| hustler | $11,372 (732%) | 15.0 | 8.0 | $2,998 |
| arbitrage | $1,288 (83%) | 13.2 | 2.8 | $496 |
| trader | $29 (2%) | 15.0 | 1.8 | $41 |
| stickup | $35 (2%) | 15.0 | 7.8 | $35 |
| boost | $201 (13%) | 10.4 | 1.5 | $269 |
| flipper | $61 (4%) | 0.0 | 0.0 | $0 |

The shape is the intended one: Heat costs the profiles that generate it, in
proportion to what they are carrying, and a profile that keeps Heat under 8
never rolls the stop at all. `stickup` is stopped almost as often as `hustler`
and loses $35 to it, because it has nothing on it — being broke is its own
protection, which is correct and worth knowing.

**Batch 9: the economy instrument had been lying since batch 3.**

`_check_board_fills` replaces the entire 907List catalogue with a single $20
item — correctly, to prove a short pool yields a short board — and never
restored it. `reset_to_new_game()` restored none of the ten authored catalogues.
So every check after that point, the whole economy instrument included, ran
against a one-item board worth about $14 a flip.

**The `flipper` profile has been on record at 4% of the day job since batch 3.
It is 358%.** Two batches of balance reasoning were done against a number that
was an artefact of the harness. The fix is in `reset_to_new_game` rather than in
the offending check, which closes the class: every check calls it, so no future
one can leak a catalogue either.

The corrected table — 30 days, 4 seeds, after batches 7 and 8:

| profile | net worth | % of day job | note |
| --- | --- | --- | --- |
| legal_worker | $1,553 | 100% | the design position |
| hustler | $11,372 | 732% | was 932% before Heat got teeth |
| **flipper** | **$5,566** | **358%** | **was reported as 4%** |
| arbitrage | $1,288 | 83% | |
| boost | $201 | 13% | 3.5 of 4 Spenard targets banned per run |
| trader | $29 | 2% | |
| stickup | $35 | 2% | |
| stickup_crew | $25 | 2% | Tone rank 3 — no better |

**Two balance findings, filed rather than taken.** Both now carry live numbers
from the instrument rather than one-off research:

- **Stickup is under-powered on its own terms, and it is not a crew problem.**
  The measured cause is health: roughly 4.6hp of expected damage an attempt
  against a take of roughly $11, and first aid at $3.06/hp. Batch 6b shipped
  the obvious answer — Tone, who takes a rank-3 wound from 20 down to 13 — so
  batch 9 added a `stickup_crew` profile to test it. **It made no difference:
  2% either way.** Every cost-side lever behaves the same (injuries off → 8%,
  free first aid → 8%, removing arrests entirely → 0%, because bookings are the
  profile's only heat relief). The take side does not rescue it either: ×2 → 9%,
  ×3 → 18%. Spenard's only any-slot tier-1 target is `washgo_regular` at
  [30, 50], the cheapest band in the game, and it absorbs 98% of attempts
  because the 2-a-day cap is spent before the night targets open. This needs a
  design decision, not a multiplier.

- **`CAUGHT_EFFECTS talk/messy` is the binding constraint on Boost.** It is the
  only row in the table where a SUCCESS tier carries a permanent ban —
  `fight/messy` does not, `run/messy` does not. Batch 9 changed it, measured
  13% → 15%, and then **reverted it**: the row is transcribed from FS-003 §5,
  the suite pins the whole table against that spec, and the web build is the
  oracle. Narrowing bans to `catastrophic` only was measured at 50% in a scratch
  tree. The anomaly is now pinned as an anomaly, with the cost recorded beside
  it, so the next reader finds the answer instead of "fixing" it.

**Batch 10 shipped five defects, found by reading it adversarially rather than
by a failing test. All five are fixed in batch 11 and each fix is pinned.**

- **Four of Wander's five encounter choices rendered an EMPTY description**, and
  the fifth inherited Boost's — `talk` read "Hand it back and try to keep this
  from turning physical", which is nothing you can do to a police cruiser. The
  engine's `CHOICE_COPY` is Boost's vocabulary (fight / run / talk / yield) and
  was never going to cover another chain's. Fixed with an adapter-supplied copy
  seam, the same shape batch 6a opened for delegation copy: the engine asks the
  source adapter for a label and a description and falls back to its own. The
  next chain kind needs no edit to the engine or the screen.
- **The ramp and its validator disagreed.** `wander_misses` climbed without
  bound in play while the load-time validator clamped it, so an honest save at
  five misses came back changed with a repair reported against a run that had
  done nothing wrong. One owner now — `WanderEvents.miss_ceiling()` — read by
  both.
- **The toast talked over the encounter.** A wander that opened a blocking chain
  navigated away and then showed "You take a walk" on top of SOMEBODY STOPS YOU,
  because the toast is parented to the tree root rather than the screen.
- **A wander was the one way to move around the block that nobody waiting for
  you could use.** `try_surface_delayed` had exactly two callers, travel and
  day-start. A retaliation that is due now surfaces on a wander too.
- **Which job you found was the order of a constant array**, not a roll. Every
  run in the port's history would have found the warehouse before the freight
  yard. The pick is seeded now, and the check sweeps twelve seeds because one
  cannot tell a seeded pick from a fixed one.

**Two harness gaps found in the same read.** The glyph-coverage CI job scanned
`ui`, `autoload` and `systems` but not `data/` — where every authored Wander
card line lives, including one with an em dash. It scans `data/` now. And of the
three test harnesses only parity runs in CI; `save_validation` and
`screen_smoke` are manual-only, which is filed rather than fixed here.

**Wander is measured, and it is the strongest clean path in the game.**

Batch 10 shipped an action that costs a SLOT — the scarcest thing in the build
at four a day — and nothing measured what taking it costs against the day job.
Two profiles now do. 30 days, 4 seeds:

| profile | net worth | % of day job | note |
| --- | --- | --- | --- |
| `legal_worker` | $1,553 | 100% | never leaves Wash & Go |
| **`worker_wanders`** | **$4,763** | **307%** | 89.5 wanders, both jobs found, shift pay 125 |
| `wanderer` | $41 | 3% | walking with no job — correctly a trap |

Wander triples the honest path and does it on **clean money**: peak Heat 0.0 and
zero arrests across every seed. The wandering worker ends the month on Ship
Creek Freight at $110-140 instead of a $50 car wash, which is exactly the design
intent the web build recorded for legal work ("social gateways into Anchorage").

**Two things the measurement caught that would otherwise have shipped blind:**

- **The first probe reported 129%, and it was wrong.** The profile found both
  jobs and went on clocking in at the car wash, because the sim applies once on
  day one and never again — so a discovery could not become money. The upgrade
  leg is what makes the number honest, and the whole gap between 129% and 307%
  is "can you actually take the job you found". That mechanism is now pinned;
  the balance is reported, not asserted.
- **`ECON_JOB` is not the best starter shift.** `spenard_chevron` pays [48, 60]
  against Wash & Go's [40, 60], so the constant every other profile and every
  published percentage in this file is quoted against is the second-best job a
  run starts knowing about. Left alone deliberately — changing it would move
  every number batch 9 published — but it is worth knowing the 100% baseline is
  a player who is not even optimising the five jobs they start with.

**A balance question for design, not for me.** The `legal_worker` 100% baseline
now represents a player ignoring a free mechanic. Every percentage in the table
— hustler 732%, flipper 358% — is quoted against it. Re-baselining is a design
call with a lot of downstream, so it is filed rather than taken.

**And the CI gap is closed.** Of the three harnesses only parity was a merge
gate; `save_validation` and `screen_smoke` were green and manual-only. Both run
on `pull_request` now, each grepping its own PASS line because a Godot run that
dies part-way still exits 0.

**Wander was dominant and inert, and batch 13 is the fix.**

The measurement said it plainly: 89.5 walks over 31 days, three a day every day,
11 cards of which 7 were ungated flavour, 307% of the day job, and no decision
anywhere in it. The correct play was to press the button with every spare slot.
Dominant and inert at once is the worst pair a mechanic can have.

Three changes, which are really one:

- **The walk has an INTENT.** `LOOK FOR WORK` / `LOOK FOR A DEAL` / `SEE WHO IS
  OUT`. The pool does not change; the WEIGHTING does, and so does what a find
  can be — only a walk that went looking for work finds work. A non-matching
  card is damped (×0.4) rather than excluded (×4.0 on a match), because an
  intent should steer the walk, not put blinkers on it: getting jumped while
  looking for work is exactly the kind of thing that should still happen.
- **A second walk in a day is worth less than the first** — 1.0 / 0.6 / 0.25,
  flattening at 0.1. Applied to the discovery roll and to what an opportunity
  pays, never to whether a card is drawn, so a walk still always produces
  something. This is what kills "press it with every spare slot"; the wandering
  worker drops 307% → 288% and now earns it by choosing rather than by
  repeating.
- **READ is the intent that tells you something.** Five readers reporting live
  state the build tracks and had NO surface for: which families a corner is hot
  for, the Heat band (batch 8 named four and nothing rendered them), whether
  Curtis's people have started looking, what a product fetches somewhere you are
  not standing, and which crew member has a day free. Every one writes nothing —
  a report cannot desync from the thing it reports because it IS the thing it
  reports, and there is a check that captures the save either side of all five.

**READ exists because discovery runs out.** Two jobs, usually found in week one,
and after that the old Wander had nothing left with weight. Reading the block
does not run out.

**`jobs_discovered` is the ONLY discovery axis in the build**, which is worth
knowing before anyone extends this. Boost targets (12), stickup targets (9),
shark borrowers (4), 907List items (18), the crew roster (4), the venues (4) and
the five NPCs are all fully visible from day one — their filters are area, tier
or nothing at all. So `LOOK FOR A DEAL` is the thinnest of the three intents by
construction: it can weight the draw but it has nothing to FIND. Giving it one
means deciding that boost or stickup targets start unknown, which is a design
call about the opening hour, not a hardening task.

**Findings carried forward:**

- v0.1.0's two unlock thresholds (1 corner → Downtown, 2 → Ship Creek; Deshawn
  or Pherris → Jobs) are **authored, not sourced**. The build brief assumed
  travel/territory unlock events that do not exist in this port. The mechanism
  is right; the numbers want a design call.
- Home's `MOVE PRODUCT` — the only bare `advance_time` control in the UI — sits
  on the operation card that v0.1.0 now hides on a fresh run. Passing time still
  works (Street travel, any Hustle action, More → Recovery → Lay Low, all
  verified reachable), but re-homing that control is a navigation change and was
  out of scope.
- **Seven tickets on the eligible list were already closed by earlier work.**
  A2 and A3 (batch 1) and C1, C3 (batch 2) were converted into standing
  guarantees rather than no-op commits — "this does not happen" is a claim with
  a shelf life unless something holds it. A5, B4, B1 and B3 were closed
  outright; B3 in particular already has its guarantee in
  `check_glyph_coverage.py`, a CI job, so adding a parity check would have been
  duplicate enforcement.
- **C2 is not applicable to this port.** The Godot build has no popup surface at
  all — no `PopupPanel`, `PopupMenu`, `Window` or positioned floating panel
  anywhere under `ui/`. It is a web-build finding.
- **The web build's second design gap does not transfer.** "Pure crime is
  capital-constrained at 17%" is not this port's problem — `arbitrage` measured
  at 384% and is limited by CARGO, not capital. Every capital-curve lever that
  ticket lists (transportation, a bank, more lenders) would have been actively
  harmful here. Re-running rather than inheriting is what caught it.
- **The hybrid ceiling is open and needs Marcus.** `hustler` sits at 932%. The
  only term that reaches it taxes the fragile strategy harder than the robust
  one, because wages insure against variance. Sweep surface recorded beside the
  constant, which ships at 0.
- **One documented contract had silently inverted.** The day-cross audit
  recorded that `day_crossed` listeners see pre-evolution markets; FS-003.2
  moved the signal below `economy.evolve()` deliberately and nothing updated the
  note. Now asserted against real prices.

## Working notes / gotchas
- **Build loop:** `session_activate` → edit scene/theme → `scene_open(force_reload)`
  → `project_run(mode=current)` → `editor_screenshot(source=game)` to verify.
  Always `project_manage(op=stop)` before reimport/writes (editor rejects writes
  while playing).
- **Writing project files:** if a shell/Write is ever blocked on this folder,
  write through the editor: `filesystem_manage(op=write_text, path=res://...)`.
  It has full project access and is the reliable path for scene/theme/script files.
- **Viewport:** 375×812, stretch `canvas_items`/`expand`, orientation portrait.
- **The `godot_ai` addon** is committed so the MCP works on any clone.
- A benign `rp_font is null` error comes from the addon's own panel — not the game.
- **Stale parse errors after a bulk file change** (e.g. the WebP conversion) report line
  numbers that no longer match the file — the errors are cached, not real. `project_manage(op=stop)`
  → `editor_manage(op=logs_clear)` → re-run clears them.
- **Renderer:** the project uses `gl_compatibility`, *not* the mobile renderer. Web export
  requires Compatibility, so leave it.
