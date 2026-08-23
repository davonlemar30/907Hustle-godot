# 907Hustle — Godot Port: Session Handoff

_Last updated: 2026-08-23. Living doc — update as screens land._

> **This file is one of four.** `HANDOFF.md` (here) carries current, living
> reference — orientation, design system, canon tables, working notes, and the
> last few batches. `docs/BUILD_LOG.md` carries everything older, newest-first,
> append-only. `docs/DECISIONS.md` is the ADR — every standing ruling (`D-`
> numbers, the Build 5e divergences, open escalations), the one place a ruling
> gets recorded once rather than repeated at every reading. `docs/DESIGN.md` is
> the one-page answer to "what is this game and why."
>
> **The repo owns what the code does; ClickUp owns what we intend to build and
> why. Where they disagree about shipped behaviour, the repo wins.**

## What this is
907Hustle ("One Good Run") is a mobile-first (375×812), dark-theme street sim
being rebuilt from a React web app into **Godot 4.7.2** Control-node scenes,
driven through the **Godot AI MCP** (dlight plugin; server at
`http://127.0.0.1:8000/mcp`, configured in `~/.claude.json`).

- **Godot project:** `/Users/damusthadon/Documents/907HustleGodot/907-hustle-godot/`
- **GitHub:** https://github.com/davonlemar30/907Hustle-godot (PUBLIC, branch `main`)
- **Web source (historical parity reference, read-only):** `/Users/damusthadon/Documents/907HustleGame/907Hustle-game/` — useful for migration history and legacy formulas, but newer approved ClickUp/Godot decisions win.

## Where the build stands

One place to orient before reading anything else below.

| | |
| --- | --- |
| Build version | `0.1.0` (`autoload/version.gd`) |
| Save schema | **v16** (Batch 18 PR 3, FS-002.3) — migration ladder walks v1 → v16. `held_blocks`/`spenard_blocks` retired; `territory_nodes`/`territory_fronts` off `data/territory_definitions.gd` |
| Parity | **12,524 checks, 0 failures**, floor `MIN_CHECKS := 12524` |
| Territory suite | **169 checks, 0 failures** — a CI gate as of Batch 18 PR 1 (`tests/territory/`), FS-002's own harness, seconds rather than the parity runner's ~2 minutes |
| Save validation | 114 checks, 0 failures — a CI gate as of batch 12, +18 from Batch 18 PR 3's Territory arm |
| Screen smoke | 24/24 screens instantiate **with their scripts attached** — a CI gate as of batch 12, script-attachment added in batch 15 |
| Glyph coverage | ok across `ui`, `autoload`, `systems`, `data` |
| Screens | 24 |
| Systems | 30 registered in `GameManager` (Batch 18 PR 0 added `run`) |
| Discovery axes | **2** — `jobs_discovered` (WORK walks) and `boost_targets_discovered` (DEAL walks, batch 14) |
| Territory operating cost | **$20/soldier/night** on the full roster (Batch 18 PR 4, D-1) — the first recurring cost Territory has ever had |
| Branches | Stale remote branches accumulate; every merged PR's branch is deleted at merge time as of Batch 18 (see the feedback note on stacked-PR merges — never delete a branch another open PR is based on). |

**The economy, measured** (30 days × 4 seeds, `_check_economy_profiles`,
`tests/parity/parity_runner.gd`). Every percentage is against `legal_worker`,
**asserted within a corridor as of Batch 18 PR 4** (`ECON_CORRIDORS`, `86bbjxth6`)
— every row below used to be a bare `print()` that nothing failed if it
changed. Fourteen profiles, not the historically-quoted thirteen.

| profile | net worth | % of job | note |
| --- | --- | --- | --- |
| hustler | $11,372 | 732% | trade + job; the ceiling |
| newcomer | $6,631 | 427% | batch 16 — the only profile that plays the GAME rather than the systems; every gate closed at reset, may only use what the ladder opens |
| **settler** | **$6,351** | **409%** | turf — **409%, not 636%**, as of Batch 18 PR 4's operating cost (D-1); 636% was the bug, not a floor worth defending |
| flipper | $5,566 | 358% | 907List |
| worker_wanders | $4,457 | 287% | zero Heat, zero arrests |
| legal_worker | $1,553 | 100% | the baseline — see D-4 in `docs/DECISIONS.md`, resolved |
| best_job_worker | $1,728 | 111% | same ladder, best starter shift — the 11-point gap IS the baseline answer (D-4) |
| arbitrage | $1,288 | 83% | |
| boost | $201 | 13% | `CAUGHT_EFFECTS talk/messy` is the binding constraint — see D-4 in `docs/DECISIONS.md` |
| boost_finder | $113 | 7% | batch 14 — earns its own board; 7.5 bans absorbed and still workable |
| wanderer | $36 | 2% | walking with no job — correctly a trap |
| trader | $29 | 2% | |
| stickup | $35 | 2% | ~4.6hp expected damage per attempt against an ~$11 take — filed for design, not taken, see `docs/DECISIONS.md` |
| stickup_crew | $25 | 2% | same ladder, rank-3 Tone — makes no measurable difference |

The economy baseline caveat (`legal_worker` as a "naive anchor") is **resolved**
as D-4 in `docs/DECISIONS.md`, not repeated here. The stickup power question and
the `CAUGHT_EFFECTS` anomaly are filed there too, as open design findings rather
than balance work this port can do unilaterally.

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
  which now reads `SaveSystem.inspect()`. See "Phase 4: save/load" in `docs/BUILD_LOG.md` for the whole flow.

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
- **`git stash` restores `project.godot`** and re-arms the editor-only `godot_ai`
  autoload. Every "is main green?" comparison run across a stash boundary loads
  the editor helper and fails 8-17 checks that look exactly like regressions —
  never compare across a stash boundary; commit or use a worktree instead.
- **A parse error in `parity_runner.gd` does not FAIL the run, it HANGS it.**
  Confirmed the hard way in Batch 18 PR 3 and PR 4: a forward-referenced
  top-level const and a lambda indentation error each hung the suite for
  30-90+ minutes at 1-3% CPU before being caught. A sabotage run — or any run —
  going long should be suspected of not compiling first. Check fast with
  `godot --headless --path . --check-only --script <file>`, wrapped in a
  `perl -e 'alarm 30; exec @ARGV' ...` timeout since this environment has no
  `timeout` binary. Kill anything still running past ~2 minutes.
- **Sabotage copies need `.godot/`** or every `uid://` breaks and the copy has a
  37-failure baseline, which makes every sabotage look red for the wrong reason.
  Always establish the baseline in the copy.
- **The economy suite was not idempotent until batch 6b:**
  `_check_economy_profiles` plays thirty days of real dispatches and, before
  that batch, never restored `user://907hustle_run.save` — every run inherited
  the previous run's leftovers. Fixed; still worth knowing if a fresh vs. a
  polluted save ever produce different economy numbers again.
- **When running the same Godot test scene from two processes at once**
  (a foreground fast check and a backgrounded full parity run, say), they can
  race on `user://907hustle_run.save` if both touch it — territory's own
  save-round-trip tests included. Don't overlap two runs against the same save
  file; wait for one to finish, or accept a save-shape false failure needs a
  re-run to confirm before it's trusted.


## Batch 18 PR 5: Documentation  (added 2026-08-23)

**Eleven parity findings** the studio pass reported between what the repo
documents and what it ships — five serious enough to call lying rather than
merely stale. All fixed except one: the ClickUp "Current Godot Build State"
page (~66KB) could not be archived to a pointer as specified — the ClickUp
connector is unauthenticated in this session, and that page lives entirely
outside the repo. Flagged rather than silently skipped.

### The split

`HANDOFF.md` was 7,440 lines with **four different sort orders**: batch
entries roughly newest-first at the macro level but not strictly (Batch 17
sat AFTER all five Batch 18 PR entries, which postdate it), living-reference
sections (Design system, canon tables, working notes) interleaved between
batch entries rather than grouped, and the one table a new reader needs first
— "Where the build stands" — sitting near the bottom rather than the top.

Three files now, each with one job:

- **`HANDOFF.md`** (this file, ~730 lines) — current, living reference only.
  The orientation table moved to the top, right after "What this is." Design
  system, canon tables (market pricing, bottom nav, general canon), the
  standing PROCESS rule, working notes/gotchas, and the three most recent
  batch entries (PR 5, PR 4, PR 3 — PR 2 moved to `BUILD_LOG.md` to keep this
  file's own budget honest as PR 5 added itself to the "last three").
- **`docs/BUILD_LOG.md`** (~6,940 lines) — everything older. **Ordering
  preserved from the source file, not re-sorted by date** — a full
  chronological re-sort would mean guessing at exact dates for entries that
  only carry a day-level timestamp, and this session judged an honestly
  append-ordered history safer than a reconstructed "true" chronology it
  cannot fully verify. Documented as a deliberate choice in the file's own
  header, not left implicit.
- **`docs/DECISIONS.md`** (already started in PR 2 for D-5) — now a real ADR.
  Added: D-2 (the ending, escalated — a narrative-design call this session has
  no standing to make), D-4 (economy baseline, resolved — `legal_worker` stays
  100%, quote the 11% gap), the Build 5e divergences and the Divergence
  Protocol they established (moved verbatim from "Codex Hardening + Fixes
  Batch 01," which otherwise moved to `BUILD_LOG.md` whole), and the
  `CAUGHT_EFFECTS talk/messy` anomaly (folded into D-4 as a related, still-open
  finding).

### The five lying findings, fixed

1. **The day-cross ordering contract** — fixed in PR 2 (D-5), the worst of the
   eleven per the build brief's own framing.
2. **README's "wandering reads 288% — the strongest clean path."** Retracted
   300 lines later in the same file and left standing anyway. Replaced with
   the current, corridor-asserted number: Territory at 409% is the actual
   strongest clean path (D-1), wandering itself still reads 287% and is no
   longer the ceiling.
3. **`assets/ASSET_MANIFEST.md`'s nav-icon list** named five tabs
   (`market`/`crew`/`travel`/`people` plus `home`) that do not exist — the
   canonical nav is `street`/`hustle`/`home`/`phone`/`more`. The four
   wrongly-listed SVGs are real files, drawn for an abandoned early nav plan
   and never deleted, so `assets/icons/nav/` holds both sets.
4. **The same file's delivery paths** — four documented folders
   (`portraits/`, `photos/atmosphere/`, `photos/locations/`, `logo/`) are
   empty on disk; the real art shipped to `assets/img/` and `assets/textures/`
   instead. Corrected with pointers to where things actually are, rather than
   rewriting the original plan (kept as historical record of intent).
5. **`tests/save_validation/SABOTAGE.md`'s check count** said 82; the gate has
   read 114 since PR 3. **Coverage stopped at the v10 arm** while schema is
   v16. The v11–v15 gap is not backfilled with invented sabotage transcripts —
   this project's own no-retro-documentation rule applies to test records the
   same as to narrative — but the v16 Territory arm's real, contemporaneous
   sabotage record (from PR 3) is added.

### `docs/DESIGN.md` and `CHANGELOG.md`, both new

`DESIGN.md`: one page — what the run is, what the four time slots are for,
what each surface is for economically, the standing balance positions ("smart
crime approaches the job and never beats it — except Territory, which is
capital investment, not crime"), and what is deliberately absent (an ending,
contested takeovers, a debt system for Territory's upkeep).

`CHANGELOG.md`: starts at Batch 18, not backfilled to the beginning of the
project — a full backfill would duplicate `BUILD_LOG.md`'s narrative in a
thinner format. Upkeep from here forward.

### Four retro entries, batches 6b–13

Written for the eight batches (6b, 7, 8, 9, 10, 11, 12, 13) that had build-log
rows and no narrative section — four schema bumps (v11→v14) with no design
record, and PR 3's migration passes through all of them. Grouped in pairs by
theme rather than one entry per batch, since four entries covers eight
batches without padding: 6b+7 (crew stops being decorative, two rooms open),
8+9 (Heat gets an edge, the instrument gets a class fix — the leaked-catalogue
bug that made "report, do not tune" the standing rule), 10+11 (Wander ships,
survives an adversarial read), 12+13 (Wander measured, then given a shape).
Reconstructed from the build-log summary and shipped code, not from a live
session — flagged in each entry as retro-documentation, which the standing
PROCESS rule says not to do and which this PR does anyway because the
alternative (migrating across undocumented state) is worse.

### README

Added the repo-vs-ClickUp precedence line the brief specified, plus the five
Batch 18 PR rows the roadmap table was missing.

### What did not get done

The ClickUp "Current Godot Build State" page — flagged above. Also not
attempted: posting the per-ticket ClickUp comments this build's own tracker
mandate (§7) requires for every PR, for the same reason (unauthenticated
connector, non-interactive session). Every PR body in this build carries the
evidence ready to paste once ClickUp access exists.

## Batch 18 PR 4: Territory's operating cost, D-1  (added 2026-08-23)

**The only player-visible change in Build 18.** Territory has claimed and paid
for six corners with zero recurring cost since Phase 3e — a soldier cost $140
once and drew no wage, ever. `settler` read 636% of the day job with zero
arrests, and that was a floor: the profile never even posted a second soldier.
FS-002.5's offense loop would price risk at one slot while claiming and holding
stayed free, making the whole warfare mechanic strictly dominated by not using
it.

### The ruling

Not this session's — decided by the 2026-08-23 studio pass, recorded as D-1 in
the new `docs/DECISIONS.md`: **a nightly soldier upkeep, $20/soldier/night.**
This is a missing rule, not a balance tweak — the FS-002 "constants unchanged"
freeze held through PR 3 only because no FS-002 balance constant existed yet to
freeze.

Three implementation choices executing that ruling, each flagged in
`docs/DECISIONS.md` since the ticket's own comment could not be read:

1. **Charged on the full roster** (`soldiers_total()`, idle AND posted) — the
   parallel to crew wages, charged per recruited member regardless of
   assignment, and the only reading under which "an over-extended board
   becomes a live cost" is actually true.
2. **An immediate best-effort deduction, not a debt.** Every other recurring
   cost in the build (rent, the phone bill, crew wages) is player-initiated
   with a due date and a miss penalty; nightly settlement only ever tracked
   misses, never force-deducted. Building a full debt-and-consequence system
   to match crew's mechanism is a much bigger change than one upkeep line.
   `_settle_upkeep()` pays what the wallet holds, logs the shortfall, and stops
   — no debt, no departure, no grace period. A later ruling can build a real
   consequence on top without this choice foreclosing it.
3. **Lives inside `territory.gd`'s existing `settle_night()`**, not a new
   named step in `day_lifecycle.gd`'s phase lists. "Alongside crew wages...
   a new step in the declared order, not a `day_crossed.connect()`" is
   satisfied by `SETTLE_ORDER`'s existing `crew` → `territory` adjacency and by
   running through the already-declared SETTLE phase — never a signal hookup.
   No phase list needed a new entry.

### The mechanism

`_settle_upkeep()`, called at the end of `settle_night()` — unconditionally on
`soldiers_total() > 0`, NOT gated on holding a corner. That guard used to be
the function's only early-return condition (`territory_nodes.is_empty()`); it
is narrowed to wrap just the corner-specific work (income, heat, the unstaffed
log), because upkeep must still charge a soldier recruited before any corner is
ever claimed — the exact "over-extended" case D-1 exists to price.

```
paid = min(soldiers_total() * $20, cash on hand)
```

Solvent: pays the full bill. Short: pays every dollar there is and logs the
shortfall. Never refuses outright — `wallet.spend()`'s own docs say a refusal
there means a blocker was missed rather than a player was refused, and that
contract does not fit an automatic charge with no blocker to check.

Turf's status card now shows the nightly upkeep line whenever there is a roster
to pay (not gated on holding a corner, matching the mechanism), and the HIRE A
SOLDIER button quotes both the one-time cost and the nightly one.

### The corridors (`86bbjxth6`)

Every profile's `pct_of_job` used to be a `print()`. Nothing failed if it
changed, and the instrument has been publicly wrong twice — batch 9's leaked
catalogue, batch 17's territory-off table — a human catching it both times
rather than the suite.

**`ECON_CORRIDORS`**: a floor and a ceiling per profile, centred on what this
build measures TODAY with headroom on both sides — not a tuning target, and
widening one is a decision with a reason in the diff, made in the PR that
deliberately moves the number. `legal_worker` is the one exact pin (100–100):
`pct_of_job` is its own net worth divided by itself, so it reads 100 by
construction and any other value is corridor code broken, not the economy
moving.

**Fourteen profiles, not thirteen.** The build prompt's own count is stale —
`ECON_PROFILES` has carried `settler` since batch 17 and the array has 14
entries today. Counted programmatically before writing the corridor table
rather than trusting the prompt's number.

**`settler`: 636% → 409%.** The corridor is centred on the post-D-1 number,
which is what this build ships — 636% was the bug, not a floor worth
defending. Every other profile's corridor sits at its pre-existing number
unchanged: only `settler` and `newcomer` (427%, was 636%-adjacent too) touch
Territory, and every profile that never claims a corner is byte-for-byte
unaffected by this PR — confirmed by the parity check count not moving except
for the new assertions themselves.

**Four premise guards the table shipped without**, added alongside the
corridors, matching the pattern nine other profiles already had:
`best_job_worker` actually worked, `stickup_crew` actually committed crimes,
`worker_wanders` actually wandered AND worked, `wanderer` actually wandered.

**A missing-corridor is a hard failure, not a skip.** A profile present in
`ECON_PROFILES` without an entry in `ECON_CORRIDORS` fails loudly
(`_fail("economy corridor", ...)`) rather than silently passing over its check
— the same "the suite must not pass by running less of itself" rule the check
floor enforces, applied to corridor coverage.

### A real bug found while wiring this up, unrelated to Territory

`tests/territory/territory_asserts.gd`'s own floor-check pattern had a
self-referential off-by-one: `a.check("floor", a.checks >= MIN_CHECKS)`
evaluates its condition BEFORE that same call's own `checks += 1` runs, so it
always compared against the count from one check EARLIER than the total it
would go on to report. Every prior PR (1–3) masked this by setting
`MIN_CHECKS` a few checks below the true total for other reasons; this PR is
the first time it was set to the exact observed total (170), which made a
fully passing 169-check run report "169 checks, floor 170" and fail.

Fixed at the root, not by nudging the number: `report()` now takes
`min_checks` as a parameter and checks it directly against the FINAL count
without going through `check()` at all — the same shape
`parity_runner.gd`'s own floor check has always used. `territory_runner.gd`'s
true content-check total is 169; `MIN_CHECKS` now reads 169 and means it.

### Sabotage log

| sabotage | result |
| --- | --- |
| `SOLDIER_UPKEEP_PER_NIGHT` zeroed | **territory FAIL, 2** — the "cash is short of the full bill" premise no longer holds, and the exact-shortfall check fails |
| `_settle_upkeep()`'s insolvency cap removed (pays the full bill or nothing) | **territory FAIL, 1** — `wallet.spend()` refuses the oversized amount outright, cash stays at 10 instead of dropping to 0 |
| `settler`'s corridor moved to 900–1000% | **parity FAIL, 1** — `"settler stays inside its corridor (409%, wanted 900-1000%): expected true"` — proof the suite CAN go red on a moved corridor, which the brief notes was not true of a single balance number in this project before this PR |

### Gates

Parity **12,505 → 12,524** checks, 0 failures (floor raised). Territory
**159 → 169** checks, 0 failures (floor corrected to 169, not raised to a wrong
170 — see the bug above). Save validation 114/0. Screen smoke 24/24. Glyph
coverage ok.

## Batch 18 PR 3: FS-002.3, canonical Territory state and save v16  (added 2026-08-23)

**The one-way door of this milestone.** `held_blocks` (keyed off `spenard_blocks`
display rows) becomes `territory_nodes` (keyed off the new
`data/territory_definitions.gd`) plus `territory_fronts`, a Curtis-relationship
ledger. `spenard_blocks` is deleted whole, not deprecated. Save v15 → **v16**.

The ticket's own ClickUp comment — which the build prompt says to read in full
before starting — could not be read in this session; the connector is
unauthenticated. Everything below that reads as a scope call rather than a
transcription is flagged as such, and one of them (D-6) is recorded as a
standing decision precisely so it can be corrected once that comment is
readable, rather than silently baked in.

### The board

Six nodes, same ids, same `earning` / `heat_exposure` / `claim_cost` / `cell` /
`name` values `spenard_blocks` carried — this is a state-shape migration, not a
balance pass, and the FS-002 "constants unchanged" freeze holds until PR 4 adds
the one missing rule it exists to add. `patrol`: authored on every row since the
system shipped, read by nothing, dropped.

New: `starting_owner`. `spenard_rec_lot` and `wash_and_go_lot` neutral; the
other four (`minnesota_offramp`, `service_road_chokepoint`, `fourth_ave_strip`,
`northern_lights_motels`) Curtis-secure.

**Scope call, flagged:** `starting_owner` gates nothing about `claim_block` in
this PR. All six nodes remain claimable identically on a fresh run — contested
takeovers are FS-002.4/.5 (Build 18b), `territory.gd`'s own header has listed
"Curtis pressure and contested takeovers" under "Not ported" since the system
shipped, and gating claims now with no mechanic behind the gate would lock four
of six corners on every fresh run for a reason no player could discover. That
would be a real gameplay change smuggled inside a migration PR. `starting_owner`
drives the migration only, this build.

### D-6: a migrated holding is never confiscated

A save can already hold a node the new board calls Curtis-secure — Batch 17
measured `settler` holding all six. The seeding rule and "no migrated holding is
ever confiscated" (the ticket's own language) collide on that corner, and one of
them has to lose. **The migrated holding wins.** It stays player-held; the
capture is treated as already having happened, off camera; `territory_fronts`
records `capture_reward_consumed: true` (so a real FS-002.4/.5 reward cannot be
claimed twice) and `conflict_active: true` (so a later build can tell this
corner apart from one nobody has touched). A Curtis-secure node the save did
NOT hold gets no `territory_fronts` entry — the field records a migrated
capture, not a standing fact about the board.

Full ruling, including why it is numbered D-6 rather than D-3 (the build
prompt's own decision list skips D-3, which reads as reserved for something
already in ClickUp rather than accidental — claiming that number risked a
collision), in `docs/DECISIONS.md`.

### The hazards, addressed in order

1. **The 2 → 14 capacity jump.** `soldier_capacity()` counts PLAYER-HELD nodes
   (`territory_nodes.size()`) exactly as `held_blocks.size()` always did —
   never the six authored definitions. Proven with the exact hazard scenario:
   four `territory_fronts` entries present, nothing held, capacity still reads
   2. Sabotage-verified below.
2. **The v9 → v10 arm.** Untouched. It still reads `state.get("held_blocks")`
   off a v9-shaped payload, which is what it will always see — nothing between
   v9 and the new v15 → v16 arm removes the field, so the climb is unaffected.
3. **`_reconcile_progression_latches()` / cached vs. derived.** Resolved by not
   having the dilemma: there is no `held_blocks` compatibility property at all.
   Every one of the twelve production sites plus the parity fixtures was swept
   to `territory_nodes` directly, so `_reconcile_progression_latches()` reads
   `territory_nodes.size()` — a plain field access, not a graph walk, and not a
   second cached truth either.
4. **`home.gd:437`'s mini-map `cell` read.** `cell` survives verbatim in
   `data/territory_definitions.gd`. Coverage that holds corners before
   asserting Turf/Home shipped in PR 1 (`_test_screen_reads`), which is exactly
   the coverage the hazard said screen-smoke cannot provide — it runs on a
   fresh save where `territory_nodes` is empty.
5. **Dead fields.** `patrol`, `claimed_day`, `income_collected` do not survive
   the migration. `income_collected` was written once, at claim, and read
   nowhere — PR 1's audit of `86bbjxtjb` found the only other write in the
   whole build was a save fixture setting up a round-trip test.

### Sites swept

Twelve production sites named in the ticket, one **not** touched
(`save_system.gd`'s v9 arm, hazard #2) — `game_state.gd` (the four
compatibility selectors: `block_by_id`, `holds_block`, `soldiers_total`,
`soldier_capacity`, plus `reset_to_new_game` and
`_reconcile_progression_latches`), `turf.gd` (four sites, plus a new
`UNRECOGNISED` section from PR 0 that now exercises the canonical field),
`home.gd` (four sites), `more.gd` (one site). Plus the parity fixtures —
`_v9_payload`, the scramble/restore block, the economy metrics, the batch-17
five-step chain — and this build's own `tests/territory/` and
`tests/save_validation/` suites.

### Three additions, all in this PR as specified

- **`spenard_blocks` deleted, not deprecated.** `data/territory_definitions.gd`
  is the only board now.
- **The first territory arm in `save_validator.gd`** — the root-cause fix for
  `86bbjxtab`. Drops an id the definitions do not carry, clamps soldiers
  non-negative, caps a posted sum that exceeds the capacity the CLEANED rows
  would grant (deterministic, sorted-id order — which row eats an over-capacity
  cut cannot depend on Dictionary iteration order), repairs a negative
  `soldiers_idle` to 0.
- **Soldier conservation across migration, the total.** Not presence — the
  ticket's own seven fixtures count nodes, and none would catch an arm that
  maps holdings correctly and drops the soldiers standing on them.
  `tests/territory/territory_runner.gd`'s `_test_v16_migration` asserts
  `idle + Σ posted` directly against the pre-migration total.

### The two fixtures the ticket was missing

Both added. The Curtis-secure collision is D-6, above, tested in both
`tests/territory/` and cross-checked in the parity suite's v9 → v16 chain (a
migrated `fourth_ave_strip` holding survives with its capture consumed). The
malformed row — a String where a Dictionary belongs, `soldiers` as a String or
negative — is `tests/save_validation/save_validation_runner.gd`'s
`_test_v16_territory_nodes`, which loads clean today and would crash at
`territory.gd`'s soldier read without the validator's type guard (proven by
sabotage, below).

### A bug this migration found, not introduced

`SaveSystem._migrate()` does not duplicate its input — `state: Dictionary = raw`
aliases the Dictionary handed in, and every existing arm from v9 onward mutates
that same object in place. Harmless as long as every arm only ADDED keys, which
is all any of them had ever done. The new v15 → v16 arm is the first to ERASE
one (`held_blocks`, renamed away), and one existing parity fixture
(`_check_v10_migration`) reused the same payload Dictionary across two separate
`_migrate()` calls — safe against every prior arm, and silently broken against
this one: the first call stripped `held_blocks` off the shared object before
the second call needed it still there, and a real load then legitimately
produced an empty `territory_nodes` and a city that never opened.

**Found by running the full parity suite, not by inspection** — six failures,
all reading like a fresh migration bug ("a v9 run keeps the city it opened",
"v9 migration preserves the corners: got 0, want 2") until the trace made the
aliasing obvious. Fixed at the two call sites that reused the mutated object
(fetch a fresh `_v9_payload()` for each `_migrate()` call, matching the pattern
the function's own `barren_state`/`one_corner` sub-cases already used) rather
than in `_migrate()` itself — `_migrate()` is called exactly once per real load
in production, so the aliasing is invisible there, and changing its general
contract to deep-copy would touch every arm's behaviour for a bug that only
existed in test-fixture reuse. **`save_system.gd`'s v9 → v10 arm itself is
unchanged** — hazard #2 held even while chasing this down.

### A parse error hangs rather than fails, confirmed the hard way

The ground truth's own warning: *"A parse error in `parity_runner.gd` hangs
rather than fails; a sabotage run going long is probably a compile error."*
`const B18_TERRITORY := preload(...)` was first declared beside its batch-17
usage — but the economy-measurement section (`_econ_try_turf`), which precedes
batch 17 in the file, reaches it too, and GDScript here does not accept a
top-level const referenced before its own declaration. The parity run sat at
1–3% CPU for over an hour before this was diagnosed and killed; a syntax check
(`godot --headless --check-only --script <file>`, wrapped in a 30-second `perl
alarm` since this environment has no `timeout`) finds the same fault in
seconds. Fixed by moving the declaration to the top of the file. Every touched
file was syntax-checked this way before the next full parity run.

### Sabotage log

| sabotage | result |
| --- | --- |
| dropped `soldiers` in the v16 arm | **territory FAIL, 5** — every preserved-soldier and conservation check across the migration |
| confiscated migrated Curtis-secure holdings (D-6, reversed) | **territory FAIL, 6** — "both corners carry over (got 1, wanted 2)", "the Curtis-secure corner is flagged, not confiscated", both consumed/contested flags |
| `.size()`-based capacity from the compat selector (hazard #1, reversed) | **territory FAIL, 8** — capacity reads 14 everywhere it should read 2, 4, or the base |
| removed the validator's row-type guard | **save_validation FAIL, 1** — `SCRIPT ERROR: Invalid cast: could not convert value to 'Dictionary'` at `save_validator.gd:717`, exactly the crash the arm exists to prevent |

### Gates

Parity **12,499 → 12,505** checks, 0 failures (floor raised in this PR).
Territory **136 → 159** (+23, floor raised 134 → 158). Save validation **96 → 114** (+18,
Territory arm). Screen smoke 24/24. Glyph coverage ok.

---

**Older history:** `docs/BUILD_LOG.md`. **Standing rulings:** `docs/DECISIONS.md`.
**What this game is and isn't:** `docs/DESIGN.md`. **Release notes:** `CHANGELOG.md`.
