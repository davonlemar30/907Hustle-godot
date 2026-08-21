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
