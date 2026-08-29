# Changelog

The game ships to a public URL on every merge to `main`
(https://davonlemar30.github.io/907Hustle-godot/) and had no release notes
until this file, added in Batch 18 PR 5 (`86bbjxtmr`).

Format loosely follows [Keep a Changelog](https://keepachangelog.com/); this
project does not cut version tags per merge, so entries are grouped by batch
instead of by version number. `autoload/version.gd` carries the one build
version string (currently `0.4.0`); it moves on its own schedule (MAJOR/MINOR/
PATCH per that file's own header), not once per entry here.

**This file starts at Batch 18, not at the beginning of the project.**
Backfilling every batch since Phase 3b in this format would duplicate
`docs/BUILD_LOG.md`'s narrative history in a second, thinner format — the
narrative entries there already say what changed and why, in more depth than
a changelog line can. This file is upkeep from here forward, not a rewrite of
what came before. For full history, see `docs/BUILD_LOG.md` (newest-first,
append-only) and `docs/DECISIONS.md` (standing rulings).

## 0.4.0 — Repeat Business: Dre's book becomes standing work (2026-08-29)

Dre's arc used to end. Fund Priya, the Book opens, and Dre himself had
nothing left to say — every dollar after that came from the Book's own
lending, never from him. That was the deferred item this build's own
predecessor named on the record, and it closes here: Dre now hands out
standing work of his own, on a slot the same substrate that already ran his
one authored chain, proven first on a second, unrelated consumer to make
sure it actually generalizes. Riding alongside it: Boost and Stick finally
get the daily District Pressure cap Market has had all along, measured
honestly rather than declared a win it didn't fully earn.

#### Next up

SCORES' own unified presentation (`86bbp38gk`) is still deferred until its
own content design exists — this build proves the substrate generalizes and
hands that proof to whoever designs it next, nothing more. FS-002.4+
Territory offense is the next systems arc, groundwork already shipped and
waiting. `86bbjxtfz` (the ending) is still an open escalation needing the
owner's ruling, not a build. A full fix for the always-criminal archetype's
District Pressure trajectory needs to touch the recovery side (quiet-day
decay or the clean-outcome refund), which this build's own ruling places
out of scope — see PRESS-D1 below.

#### Added

- **A second, unrelated consumer proves the Street Opportunity substrate
  generalizes**: a Score contract (`score_slide_special`) runs the full
  offer → accept → resolve/fail lifecycle on the same substrate Dre's loans
  already used, completely unmodified — the lift itself, the roll, and the
  fence are untouched, the contract only watches. Measured pushing Boost's
  own economy share to 26% once its target (Northern Value) went live.
- **Dre hands out repeatable work after Junior Lender**: up to three live
  offers at once, one new offer a day, riding the exact collection encounter
  his one-time chain already used end to end — no new save schema. Four
  templates across three roles: a base collection, a leaned-on variant with
  higher stakes, a premium tier gated on proven track record, and an errand
  that rewards a simple delivery run. Measured at 109% of the day job for a
  player who works one alongside a day job — meaningful without dominating.
- **Boost and Stick get their own daily District Pressure cap**, on Market's
  own precedent, both landing on 2.0 for a real shared reason: every
  non-Market pressure source ultimately draws from the same tiered table,
  which tops out at 2.0 on a single catastrophic result, so one bad outcome
  is never truncated by its own cap.

#### Changed

- **District Pressure's daily cap is measured honestly as a partial result,
  not declared a full fix.** The always-criminal profile's worst district
  moves from HOT on 14 of 29 days to 13 — a real but small improvement, not
  an exit from HOT. The two ways Pressure actually comes down (a quiet day,
  or a clean-outcome refund) are both structurally rare for a policy that
  works crime every day and rarely resolves clean; a daily cap bounds one
  day's damage, it can't fix an imbalance that recurs every day. Recorded in
  full, numbers attached, rather than quietly declared solved.

## 0.3.0 — Answer For It: the cops talk to you now (2026-08-29)

Doing criminal work while carrying Heat, a blown stickup used to put the
player straight into Booking — no encounter, no choices, no explanation. It
looked like a missing feature; it was a design decision, and the owner's
phone playtest called it out as the first real finding. That design is over.
Every action-sourced caught moment in the game now presents a decision
before any arrest resolves. Heat, which never came down under ordinary
criminal play, now breathes. And stickup, which earned 2% of the day job
with one starved target absorbing 98% of every attempt, has a second target
and a cap that grows with rep.

#### Added

- **The stickup caught decision**: a blown tier-1 job that comes up Failure
  over Heat, or Catastrophic at any Heat, now opens fight/run/talk/yield
  before any arrest resolves — the same response vocabulary Boost's own
  caught chain already taught the player, authored fresh for the responding
  officer rather than the mark. Rooms (tier 2-3) are untouched; their own
  multi-round stages already are the decision. A pre-attempt warning on the
  Stickup screen reads the same Heat the arrest gate reads, so a blown job's
  risk is never a surprise. Old saves holding an already-open booking keep
  resolving exactly as they did.
- **Heat comes back down**: a small decay now runs every night regardless of
  how loud the day was, alongside a bigger (and now more meaningful)
  quiet-day rule. An every-day criminal profile that used to asymptote at
  the ceiling now measurably returns below the tier-1 arrest gate. Boost's
  own tier-3 Run failure no longer arrests unconditionally — Heat has to
  clear a bar at every tier now, the bar just gets lower the bigger the job.
  Measured: Boost's own share of the day job moved 13% → 24% as a result.
- **Stickup earns its place**: a second any-slot Spenard target with a
  meaningfully bigger band, and a daily cap that scales with rep instead of
  sitting flat at two forever. Stickup's measured share moved from 2% of the
  day job to 6% solo, 8% combined with boost.
- **Phone and title polish**: the Texts screen's "clear all" control is a
  real 44pt tap target now, matching the per-message dismiss beside it; the
  title screen keeps its authored mobile proportions — a centered,
  width-capped column — on a desktop-width viewport instead of stretching
  edge to edge.

#### Fixed

- Boost's tier-3 Run failure no longer arrests regardless of the player's
  Heat (see above).

## 0.2.1 — In Hand: the touch fix and the phone build (2026-08-28)

The game scrolls from anywhere now. On almost every screen, a thumb had to
land on bare space between the cards to scroll at all — starting a drag on a
card, a button, or a line of text just stopped it dead, because that was the
one thing on the block that could actually stop something. Market, Jobs,
Phone, the works: touch any card and drag, and the screen moves with your
hand the way it always should have.

And 907Hustle finally has a phone build. Not the browser tab it's been
tested through this whole time — an installable Android APK, built fresh in
CI on every merge to `main`.

#### Added

- **Touch scroll transparency**: cards are transparent to a drag now,
  everywhere, while staying exactly as tappable as they always were — nothing
  that used to be inert became a button, and nothing that used to fire a
  handler stopped firing one. A CI gate walks every screen's scrollable area
  and fails the build if a card ever swallows a drag again.
- **Android debug build**: an installable arm64 APK, debug-signed, produced
  as a CI artifact on every push to `main` and on demand
  (`.github/workflows/android-apk.yml`). The Web build and its Pages deploy
  are untouched — this is a second target bolted on beside the first, not a
  replacement for it.

## 0.2.0 — Dre Lending & Loan-Shark Progression (2026-08-28)

Dre fronts money now, and the debt is real. Juan puts you onto him when
things get tight — not on a clock, on whether you actually need it — and the
first loan is a plain number with a plain deadline: what you get, what you
owe back, and the day it's due. Pay it and Dre trusts you with more. Miss it
and he doesn't come for you himself; he sends somebody, and that's its own
conversation.

Trust him enough and he starts handing you work: a name to collect from,
talked loose or taken the hard way, your call. Handle it clean and he'll put
your own name forward — one borrower, his vouch, funded through the same
book everybody else's money runs through. See that loan through and the Book
opens for real: THE BOOK is yours to run, other people's money at your own
interest, THE SHARK surface retired under a name that actually says what it
is. It was never a Day 5 unlock. You earn it, in order, or you don't see it
at all.

Finances now says the two things it always meant to say as two things: DEBT
TO DRE, what you owe him, and THE BOOK, what they owe you. Never one number
pretending to be both.

#### Next up

The authored chain is the whole of Dre's content for now — repeatable
contracts after Junior Lender (max three live, one new offer a day) are
deliberately deferred past this build, the same discipline that kept this
arc from becoming a second game before the first chain proved itself.

#### Added

- **Dre, the relationship**: `dre_introduced`, `dre_access_tier` (Unknown →
  Borrower → Trusted Customer → Collector → Junior Lender), and a structured
  `dre_account` replacing the old dormant flat-debt fields. Juan's mention
  fires on a real trigger — low cash or rent pressure past Day 2 — never on
  elapsed time alone.
- **First Money**: Dre's first loan, $1,000 for $1,200 back in 5 days, one
  extension (+2 days, +$100), full repayment only. Pay late and restitution
  is a real, separate road back from a suspended account.
- **A Reminder**: Dre's first real contract — collect from a borrower who
  owes him, talked loose (a Charisma read) or taken hard (a real
  confrontation chain, press or walk away). Either road changes what Dre and
  the neighborhood think of you.
- **Your First Name in the Book**: Dre sponsors one borrower — Priya Osei —
  as a fundable exception before the Book itself opens. Fund her, see her
  loan through, and Junior Lender opens for real: the Book, earned, with the
  discovery card to match.
- **The Book, relabeled and gated by access**: borrower rows lock until
  Junior Lender (or Priya's own sponsorship window), and Dre's own
  relationship discount — bonded borrowers default 8 points less often —
  goes live for a Collector or better.
- New systems `dre_lender`, `dre_collector`, and `opportunities` (the shared
  substrate this arc's contracts run on); new gate suite `tests/dre/` (331
  checks) in CI beside the other five.

#### Changed

- Finances (More → Finances, same screen as the Book) now shows DEBT TO DRE
  and THE BOOK as two separate sections — never merged into one "notes"
  total.
- The economy instrument gained a leveraged-lender profile and a standing
  check that no combination of the shipped numbers lets a player borrow from
  Dre and fund the Book for a guaranteed profit.

## 0.1.3 — the long-run memory fix (2026-08-28)

Long runs were getting slower to scroll and slower to tap, and the further
into a run you were the worse it got. Measured on a driven 60-day run: the
phone's inbox kept every text it was ever sent (about 1,400 UI nodes by day
60, rebuilt on every action), and the save the game rewrites after every move
had grown to six figures of bytes.

Fixed by teaching the game to let go of what is finished:

- **Texts** — the inbox keeps your newest 30 (each of its two halves, live
  and held-for-service); the oldest drop off the bottom, the same way the
  activity log has always kept 12.
- **Shark notes** — a note that is repaid, forgiven, or enforced leaves the
  ledger on the next night's settle. Open and defaulted notes stay.
- **The consequence ledger** — each morning the engine sheds threats that
  resolved or expired and the bookkeeping for incidents nothing can revisit.
  Anything still live — an open chain, a threat still waiting for you — is
  untouched.

Save schema moves to v22; loading an older save applies the same cleanup
once, so an existing long run gets its speed back immediately. Nothing about
odds, prices, or outcomes changes — the parity suite's market-stream drift
check proves the boards match day-for-day either way.

## 0.1.2 — She Said Get a Job (2026-08-28)

*Draft — this entry was written from the build's own record of what shipped,
not from an established patch-note voice sample, and is worth a pass before
it goes out under that voice.*

#### THE OPENING

Yalonda replaces the old title-screen opening. You meet her in the scene now
instead of clicking through a separate intro screen first — same beats,
delivered where the run actually starts.

#### THE HOME SCREEN

Turf and Crew don't show up greyed-out on day one anymore. They stay off the
board entirely until you've earned them, the same way Market and Boost
already did — and the game tells you the moment that changes instead of
leaving you to notice on your own.

#### DISCOVERY FEELS LIKE SOMETHING

Wander into a new job, a Lift target, or the Street Market for the first time
and it's not just a toast anymore — you get an actual card for it.

#### YOUR CREW TEXTS YOU

Word gets around now. Recruit Pherris and some mornings she'll text you the
best market route before you've even checked. Recruit Eli and he'll tell you
which side of town is quiet today — the safest road to carry through.
Nobody's crew ever burns you, and most days nobody has anything worth
texting about — silence is the point as much as the tips are.

#### GETTING CAUGHT IS A SCENE NOW

Tier 2-3 stickups — the Chevron till, the Holiday register, the dice game
behind the rec center, Goodie's stash — are staged rooms now, not one roll.
Bank what you've got and go, or push for more; a slipped stage forks into
running for it clean or running for it messy, and heat scales with how much
of the take you actually walked out with. Tier-1 marks are still one roll,
exactly as before, and WALK at the door still costs nothing.

Getting caught lifting has real outs now too: talk your way clear, settle up
with the store you got caught in (once a store, once a run), or just hand
back what you took and walk — no clean roll, but no charge either.

#### THE FAT NIGHT

Every so often Tone hears about a room that's flush — a specific target, a
specific window that same night. Hit it while the window's open and the take
doubles, sometimes better. Miss the window and it's just a normal night
again.

#### Next up

Stickup and the Lift are two versions of the same idea — "take something
that isn't yours" — and the next build starts folding them into one ladder,
SCORES: petty theft up through organized crew work, one progression instead
of two.

#### Added

- **Word of Mouth, slice 1** (`systems/tips.gd`): a day-start tip generator —
  Pherris' route push, Eli's corridor read, Tone's fat-night window — on a
  seeded drought ramp (roughly 40% of days carry nothing). New save fields
  `tip_effects`/`tip_misses` (schema v18 → v19). New gate suite
  `tests/tips/` (93 checks) in CI beside the other four.
- **The Lift's caught loop**: BRIBE (buy off a store, once per store per
  run) and HAND IT BACK (surrender the goods, no roll, no charge) as real
  outs from a caught chain, alongside the existing talk-your-way-clear path.
  New save field `boost_bribes_used` (schema v17 → v18).
- **Tier 2-3 stickups are multi-round rooms.** The take is split across
  authored stages, TAKE AND GO banks what you have and leaves, a slipped
  stage forks into DROP IT AND RUN versus RUN WITH IT, and leaving early is
  quieter — heat scales with the fraction you actually walked out with.
- **New gate suites** `tests/confrontation/` (212 checks) and `tests/tips/`
  (93 checks) in CI beside the other three.

#### Changed

- The consequence scene renders loop chains with a stage counter, a #LEFT
  chip, the banked amount, the current beat as the situation line, and a
  short SO FAR log.
- Three parity sections that drove tier 2-3 stickup dispatches now drive the
  rooms; their contracts (the arrest gate against pre-source Heat, the
  cooldown, retaliation scheduling by outcome) are unchanged.

### 0.1.0 Playtest Pass (2026-08-27)

Three UX PRs addressing findings from the first 0.1.0 playtest session.

#### Fixed

- **Opening screen beat cards overlapping** (PR #78): each beat card was a
  `PanelContainer` with two sibling Labels, but PanelContainer only lays out a
  single managed child. Inserted a VBoxContainer between each card and its
  labels. Added a staggered entrance animation (fade + slide, `create_tween()`).
- **Hustle screen permanently showing $312 "Today's Take"** (PR #79): the
  `todays_take` and `income_sources` fields were scaffold data no system ever
  wrote to. Replaced with `todays_earnings` Dictionary, a `record_earning()`
  helper called by all seven income systems after their wallet credit, and a
  `todays_take()` derived total. Resets at DAY_START alongside `heat_gain_today`.
  Persisted for mid-day save/reload (additive, no schema bump).
- **Market buy/sell hardcoded to quantity 1** (PR #80): the economy system
  already validated and executed any quantity; only the UI never asked "how
  many?" Now tapping BUY or SELL opens a bottom sheet with a live quantity
  stepper (capped at supply/cash/cargo for buy, holdings for sell), running
  total, and a CONFIRM button. Dispatch stays the sole authority.

#### Added

- `GameState.record_earning(source, amount)` — bookkeeping method for day-scoped
  income tracking. Called by jobs, economy (market sells), stickup, boost, shark,
  territory, and nine07list.
- `GameState.todays_take()` — derived total of today's earnings.
- Staggered tween entrance on the Opening screen (head, sub, beat cards, button).
- `ui/components/modal_sheet.gd` — reusable bottom-sheet overlay component
  (scrim, sliding/scaling card, swipe-down handle, `dismissed` signal,
  self-freeing). No Market-specific knowledge; designed for reuse by the
  encounter popup PR.

#### Gates

Parity 12,524 → **12,526** checks, 0 failures (floor raised; +2 from existing
round-trip loops walking one more PERSIST_FIELDS entry). Territory 169/0.
Save validation 114/0. Screen smoke 24/24.

## Batch 18 — the ground under the war, and Territory's missing cost

Five PRs. FS-002 slices .1–.3 (Territory's canonical state and save v16), a
live-defect pass, Territory's first operating cost, and the documentation
split this file is part of.

### Added

- Nightly soldier upkeep for Territory: $20/soldier/night, charged on the full
  roster whether posted or idle (D-1, `86bbjxtfa`, PR 4).
- Economy corridor assertions: every profile in the 30-day economy measurement
  now has a floor/ceiling asserted in CI, not a bare `print()` (`86bbjxth6`,
  PR 4).
- `data/territory_definitions.gd` — the canonical Territory board, replacing
  `GameState.spenard_blocks` (PR 3).
- `tests/territory/` — FS-002's own test harness, seconds rather than the
  parity runner's ~2 minutes (`86bbjxtjb`, PR 1).
- The first `save_validator.gd` arm for Territory state — the root-cause fix
  for an unknown territory node id silently killing nightly settlement
  (`86bbjxtab`, PR 3).
- `systems/run_start.gd` — routes starting a new run through
  `GameManager.dispatch()` for the first time; a new run now autosaves on
  creation (PR 0).
- CI: a crash gate failing any harness run whose log carries `SCRIPT ERROR` or
  `Invalid access`; `timeout-minutes` on every job; the parity job's own
  `PASS` grep, which it had been missing (`86bbjxthk`, PR 0).
- `docs/DECISIONS.md`, `docs/BUILD_LOG.md`, `docs/DESIGN.md`, this file — the
  documentation split (`86bbjxtmr`, PR 5).

### Changed

- **Save schema v15 → v16.** `held_blocks` (keyed off `spenard_blocks` display
  rows) becomes `territory_nodes` (keyed off canonical ids) plus
  `territory_fronts`, a Curtis-relationship ledger. Migration preserves every
  soldier and never confiscates a holding, even one the new board calls
  Curtis-secure (D-6).
- The day-cross settlement ordering contract in `HANDOFF.md` — documented
  wrong for four batches — now matches shipped `SETTLE_ORDER`. The stated
  REASON for the ordering (crew settles before Territory "because territory
  income is computed off crew power") was also false; corrected to name the
  real dependency, Deshawn's heat multiplier (D-5).
- `settler` economy profile: **636% → 409%** of the day job, reflecting
  Territory's new operating cost. 636% is preserved in `docs/BUILD_LOG.md`'s
  batch-17 entry as the finding that motivated D-1, not as a target.
- `HANDOFF.md`: split from 7,440 lines into a ~730-line living-reference file
  plus `docs/BUILD_LOG.md` (history) and `docs/DECISIONS.md` (rulings).

### Fixed

- An unknown territory node id no longer kills nightly settlement outright;
  `territory.gd` and `turf.gd` degrade gracefully and the new save-validator
  arm drops unrecognised ids on load (`86bbjxtab`).
- The parity suite could delete a developer's save file when it was unreadable
  (not merely absent) — the two cases are now distinguished (`86bbjxtaw`).
- Soldier count could permanently exceed capacity after abandoning a corner
  that had raised it; the excess now walks (`86bbjxtb6`).
- `name_entry.gd` wrote `GameState` directly, bypassing the dispatch-ownership
  guard on the largest single write in the build (`86bbjxtbm`).
- Territory's nightly heat gain passed an empty family string to the heat
  multiplier by accident of a dictionary miss rather than by a named rule;
  named explicitly as `HeatSystem.FAMILY_NONE` (`86bbjxtbm`).
- Five documentation findings classified "lying" rather than merely stale:
  the day-cross ordering contract (see above), README's retracted-but-still-
  present "wandering reads 288%" claim, `ASSET_MANIFEST.md`'s nav-icon list
  and delivery paths, and `SABOTAGE.md`'s stale check count and schema-version
  ceiling (`86bbjxtmr`).
- A self-referential off-by-one in `tests/territory/territory_asserts.gd`'s
  own check-floor mechanism, found while wiring PR 4's corridor checks.

### Known gaps, recorded rather than fixed

- **D-2 (the ending) is open, not answered.** No ending mechanic exists;
  nothing in Batch 18 forecloses one. See `docs/DECISIONS.md`.
- Two live defects were escalated as design rulings rather than fixed:
  Boost's tier-3 Run failure arrest (transcribes the approved spec exactly)
  and Pherris's rank-2 wage exceeding her delegated return (any fix is a
  tune). See `docs/DECISIONS.md`, "Escalations open as of Batch 18 PR 0."
