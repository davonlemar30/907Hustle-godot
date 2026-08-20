# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-08-19. Living doc — update as screens land._

## What this is
907Hustle ("One Good Run") is a mobile-first (375×812), dark-theme street sim
being rebuilt from a React web app into **Godot 4.7.2** Control-node scenes,
driven through the **Godot AI MCP** (dlight plugin; server at
`http://127.0.0.1:8000/mcp`, configured in `~/.claude.json`).

- **Godot project:** `/Users/damusthadon/Documents/907HustleGodot/907-hustle-godot/`
- **GitHub:** https://github.com/davonlemar30/907Hustle-godot (PUBLIC, branch `main`)
- **Web source (design authority, read-only):** `/Users/damusthadon/Documents/907HustleGame/907Hustle-game/` — palette/fonts in `v05.css`; game data in `ui.built.js`.

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
- **Phone and More are `disabled`**, not wired to a missing scene.
- **New-run state is canon.** `GameState.reset_to_new_game()` mirrors the web reducer's
  START_RUN branch: `$100`, heat 0, health 100, debt 0, Spenard, Day 1 MORNING. Not the
  CHOOSE_BACKGROUND branch ($375 + a $620 note from Dre, `run.premise = legacy_established`)
  — that is a different opening this build has no screen for. `sanitize_street_name()` is a
  port of `sanitizeStreetName` (`game-core.js:83-86`), 16-char cap, and an empty result
  blocks the run exactly as canon does.
- **CONTINUE RUN and the LAST RUN line are hidden**, gated on `title.gd::_has_save()`, which
  returns false until save/load lands in Phase 4. That one function is the whole switch.

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
