# Changelog

The game ships to a public URL on every merge to `main`
(https://davonlemar30.github.io/907Hustle-godot/) and had no release notes
until this file, added in Batch 18 PR 5 (`86bbjxtmr`).

Format loosely follows [Keep a Changelog](https://keepachangelog.com/); this
project does not cut version tags per merge, so entries are grouped by batch
instead of by version number. `autoload/version.gd` carries the one build
version string (currently `1.0.0`); it moves on its own schedule (MAJOR/MINOR/
PATCH per that file's own header), not once per entry here.

**This file starts at Batch 18, not at the beginning of the project.**
Backfilling every batch since Phase 3b in this format would duplicate
`docs/BUILD_LOG.md`'s narrative history in a second, thinner format — the
narrative entries there already say what changed and why, in more depth than
a changelog line can. This file is upkeep from here forward, not a rewrite of
what came before. For full history, see `docs/BUILD_LOG.md` (newest-first,
append-only) and `docs/DECISIONS.md` (standing rulings).

## 1.0.0 — One Good Run: the run has an end (2026-09-04)

The creative director's 0.9.0 playtest (`907Hustle_Build_Prompt_v4.md`):
the game had a beginning and a middle and no end, respect was a number
nobody earned, the player had no kit, the Lift and the board were free
money, and Curtis's blocks were labels. Seven deliverables, each green
before the next started. Rulings are D-28 (OG-D1..D6). The assessment is
`docs/ONE_GOOD_RUN_REVIEW.md`; the images the build looks for are
`docs/ASSET_CHECKLIST.md`.

### PR 1 — The rent day (`#146`)

- **People hides the unmet.** A name appears once its ledger has a row.
- **Bills surface.** PHONE on the nav carries a badge (amber due, red
  overdue); the Phone opens on Bills when one is.
- **Rent escalates in Yalonda's voice** (`rent_arrears_day`, save v29): a
  text the night it is due; a feed line and a `missed_obligation` mark a
  day late; her second text and Juan's the day after; a house warning
  every third day; the third is the eviction. Paid late: "You got it.
  Don't make this a habit."
- **The phone bill goes quiet**, then cuts you off.

### PR 2 — Earn your name (`#147`)

- **Respect is gone; Rank is derived.** `data/rank.gd` reads every NPC's
  observation ledger, weighted by type and capped at three per type:
  Nobody 0, New Face 3, Known 8, Player 15, Connected 25, Boss 40. Never
  persisted.
- **Gates:** crew needs Known; a corner needs Player; the 907List's tiers
  need Known; the way out needs Boss. The HUD chip and the Character
  screen show it; crossing a line is a feed line and a text.

### PR 3 — The player's kit, the faces, the places, and the ride (`#148`)

- **A weapon slot** (save v30): hands; a knife (+0.10 FIGHT, +0.5 heat when
  it comes out) from a man at the Chevron's ice machine a week in; a piece
  (+0.22, +2.5 heat, +3 and a line if the police find it) from Dre's
  cousin once you are a Player. Both are wander meetings with roads.
- **The beater**: Sonny texts the offer at $1,400 (day 5+); gas instead of
  fare, cargo +4, a trunk the checkpoint cannot count, a 10% cold morning,
  a 15% Downtown window, `uninsured_car` on Yalonda's ledger, `has_a_car`
  on Curtis's.
- **Faces, banners, interiors** (`data/portraits.gd`): every NPC on People
  (64px), the Phone (48px), the encounter sheet (64px) and the hire and
  interview sheets (96px); every district's banner on Home and the ride;
  the Night Owl and the gym. Every slot renders as nothing until the file
  exists.
- **The ride is a card**, per district and per mode; every screen wears the
  district's accent and says what kind of place it is.

### PR 4 — One good run has an end (`#149`)

- **The way out** (`systems/ending.gd`, save v31): $3,000 clean + $400 a
  corner + $300 a crew member, at Boss. The card is on Home from
  Connected; LEAVE AT DAY'S CLOSE ends the run at settle.
- **Three losses**: Yalonda's third warning; the third serious booking
  (stick T2/T3, boost T2); Curtis maxed with nobody standing with you --
  a one-way text, his car, then the door on the third morning. Crew keeps
  the door shut while they are paid.
- **One reckoning screen**: head and kicker per ending, earnings by
  source, corners, and a line from every person you met in the band you
  left them in.

### PR 5 — Stolen goods have a name (`#150`)

- **The Lift walks out with a thing** (save v32, `hot_goods`): kind, name,
  value (the same keyed take roll), heat, where it came from. Tier 3 is
  still merchandise for Slide.
- **The 907List is the fence**: UNDER YOUR COAT rows, FENCE IT; a hot
  listing waits a day; the meet is a seeded roll -- cop (4% + 1.5%/heat,
  +8% at three hot), tag (10%), unsold (15%), clean (60% of value, dirty).
  Pherris at loyalty 5 halves cop and tag.

### PR 6 — His blocks fight back (`#151`)

- **A Curtis block is a fight**: TAKE IT opens the confrontation with the
  odds shown (block value, his awareness, crew, kit). RUN is guaranteed
  and remembered. Lose: no block, awareness up. Win: yours, a live front,
  retaliation queued.
- **Nightly probes**: undefended 15%, defended 5%, live front 50%. A block
  that fails is his by morning; the crew texts you.

### PR 7 — Close-out

- Version `1.0.0` (MAJOR: the run has a shape). `docs/ASSET_CHECKLIST.md`,
  `docs/ONE_GOOD_RUN_REVIEW.md`, D-28.

### Measured across the build

Parity 13,782 → 13,979; confrontation 3,614 → 3,628; save-validation
261 → 273; smoke width 2,779 → 2,783 at the phone's width. Four schema
bumps (v29–v32). Corridors re-set with notes: `everyday_criminal` floor
0 (a run that ignores Yalonda ends); `stickup`, `everyday_criminal` and
`stickup_crew` ceilings 60/60/40 (they end at Curtis's door by the
eighth to twelfth morning, and the corridor reads an eight-day pocket
against a month of shifts); `boost` floor 5 → 0 (the free money is
gone; what walked out did not move, what came back did); `boost_finder`
ceiling 40.

## 0.9.0 — The Block Remembers: the screen holds, the city gets a fourth district, and the crew has ideas (2026-09-03)

The creative director's playtest of 0.8.0 (`907Hustle_Build_Prompt_v3.md`):
the writing landed and the replies landed; the screen stretched, the job
tap looked dead, the talker could hit you with no answer, and the crew
question ("Spenard only, or Anchorage?") should not need asking. Six
deliverables, each green before the next started. Rulings are D-27
(BR-D1..D6).

### PR 1 — The screen holds (`#139`)

- **The stretch bug, root-caused.** Home's activity feed rows had no wrap;
  one long feed line set a minimum width past the phone and the shell grew
  and centered, both edges cut off. The rows wrap. The smoke suite
  instantiates every screen at the phone's width (375) over the longest
  lines the game writes and refuses any control outside it; the unwrapped
  Home fails it. The tighter sweep also caught two unwrapped notes (Boost,
  the Gym) and re-measured the encounter panel: the triad fits the glance,
  a fourth authored road sits a drag away.
- **Applying is a state** (`job_applications`, save v28): APPLIED on the
  card, answered by text two slots later. Day labor takes walk-ins.
- **Cargo Value** and the unwired PLAN A ROUTE button are gone.
- **Answering back.** A non-fight road whose tier hurts opens a fistfight
  -- SWING / BREAK FOR IT / GIVE IT UP -- in a room generated from the
  card's own odds; a clean SWING sends him off with a few dollars on the
  ground. Police cards opt out.

### PR 2 — Clock in, move up (`#140`)

- **Interviews.** Two slots after applying, the manager texts to come in;
  a sheet asks three questions in their voice, two answers each; the
  score rides the chance and starts rapport. Ignored offers lapse.
- **Rungs.** Three titles per job. XP fills the bar; the manager grants
  the rung when days, streak, rapport and the job's attribute are met.
  One rung a shift, a line and a text. The Jobs screen says what the next
  rung still wants.
- **The floor.** SOCIALIZE (a coworker, rapport, charisma), BREAK ROOM
  (rest, half a chance to overhear the block or the board), LEARN THE JOB
  (intelligence). A miss breaks the streak and costs two with the boss.

### PR 3 — Your corners, their corners (`#141`)

- **Every block belongs to a district.** Downtown: five venues, more
  money, more heat, three Curtis's. Ship Creek: three lots that are
  supply -- each cuts every buy, anywhere. Claimed where you stand once
  the district is known; heat lands where the block is.
- **Turf screen:** district tabs, held of total, YOURS / CURTIS'S / OPEN,
  what a held block makes, where soldiers stand. One buy price
  (`buy_unit_price`), previewed on the sheet.

### PR 4 — Mountain View (`#142`)

- **A fourth district** with its own bias (pills and lean pay; club drugs
  want Downtown; weed has its own channels), heat (stickup ×1.5),
  adjacency, Street card, Turf tab, four cards, two marks, two targets,
  three corners. Opens a week in at day start, or when two brothers at a
  Spenard bus shelter name it.
- **Arrivals.** The first bus to any new district is a sheet.
- **The oracle holds:** a non-oracle district walks its market on its own
  RNG stream.

### PR 5 — They have their own ideas

- **Two operations** on the crew substrate: Eli scouts a district and
  reports the board; Tone puts a problem down with force, at a cost in
  heat. Mission buttons on the Crew screen for every operation a member
  knows, with a district where one is needed.
- **Proposals.** A member sure of you (loyalty 6) texts an idea that
  fits the day -- a problem on a block, a route, a board, a district you
  have not seen -- every few mornings. Yes is the assignment.

### PR 6 — Close-out

Version 0.9.0, D-27, docs, `docs/BLOCK_REMEMBERS_REVIEW.md` answering the
prompt's eight questions (including the car).

### Measured

| Suite | 0.8.0 | 0.9.0 |
|---|---|---|
| parity | 13,556 | 13,782 |
| confrontation | 3,445 | 3,614 |
| save-validation | 257 | 261 |
| smoke | 96 panel | 98 panel + 2,788 width |
| dre / tips / territory | 427 / 93 / 170 | unchanged |

Save schema v28 (one additive bump). The job yardstick earns less than it
did (rungs are earned, not filled): four economy corridors moved with the
measurement recorded at each constant.

## 0.8.0 — The World Speaks: the city reveals itself, and everybody in it has a voice (2026-09-03)

The owner's directive, from `907Hustle_Build_Prompt_v2.md`: *"the world
should speak to the player — nothing criminal on day one, every card
earning its slot, texts you can answer, jobs with people in them, and a
writing pass over every line the game says."* Five PRs, each green before
the next started, stacked in order. Rulings are D-26 (WS-D1..D5).

### PR 1 — The city reveals itself (`#134`)

- **Nothing criminal is on the board on day one.** The Market arrives
  through Goodie on the corner from day two (Spenard); the Lift through
  the first loose rack from day three; the stickup through a broke
  afternoon (under $30) or witnessing one in Spenard after dark from day
  five; the 907List through the first of Mina, Juan, Yalonda or Dre at
  Warm mentioning it at day start. `hustles_discovered` is the latch,
  **save v26**, derived for v25 saves from the gates they had open.
- **The run starts knowing one job** — the Wash & Go, because Yalonda's
  welcome names it and Lani. The other six are found by walking.
- **Four meeting cards** (`KIND_MEETING`) play before the gate roll on
  their day and never write to Curtis. Goodie's road hands two weed;
  the rack hands cash; the broke afternoon hands cash. Cash lands dirty.
- Every gate in `SurfaceVisibility` reads the new `hustle_discovered`
  requirement; the Jobs menu reads `jobs_known`.

### PR 2 — Every card earns its slot (`#135`)

- **Seven verbs** on every road of every confrontation: FIGHT, RUN, TALK,
  PAY, SURRENDER, BLUFF, COMPLY (plus the crew calls by name). The
  situation lives in the line under the verb; the story in the result.
  The Lift, the caught encounter, both corners, the meetup, the
  checkpoint, the doorstep, retaliation and Dre's collection all speak
  the same set. The stickup room keeps its own actions.
- **A roster keyed to when.** `day_max` joins the requirement language.
  Week Zero (days 1–4), Getting Known (4–10), Reputation (10–20), Weight
  (20+). The mistaken-identity slot-filler is cut; the three on the wall,
  the lot and the wrong place are rewritten to answer who and why; nine
  new cards arrive on their days.

### PR 3 — The player speaks (`#136`)

- **Two answers on every text from a named NPC**, under fifteen words,
  thumb-typed. A leans toward the person (an observation, or a point of
  loyalty for crew); B keeps distance (neutral). The NPC answers back
  once, in their own voice. `Phone.push_text(from, text, context, extra)`
  is the seam; every named push site moved over.
- **Silence costs.** A text on read for a full day is a ghost. Mina,
  Dre, Yalonda and the managers notice: it costs them, and their next
  text opens on it. Juan and the crew shrug.
- **`phone_reply_history`** (save v27, additive) keeps per-NPC counts.

### PR 4 — The managers have names (`#137`)

- **Every job is a person** (`data/job_managers.gd`): Lani, Marcus,
  Mina, Sonny, Denise, Ray, Big Mike. The hire is a flow sheet in their
  voice. Every three or four shifts something small happens on the
  floor. The Chevron pays a night differential; the Night Owl pays its
  regular and every night beside Mina is an observation on her ledger.
  A missed shift is an answerable text; three is the door, with a last
  text and a sheet.
- **Pay differs.** The four starter bands re-cut; the best-job corridor's
  ceiling lifted 130 → 140 (measured 134%).

### PR 5 — The writing pass, and the close-out

- **Feed lines are fragments of experience.** Fifty-odd system messages
  across wander, stickup, 907List, territory, obligations, crew, boost,
  the shark and jobs rewritten in the *Power* register. Lines whose
  number *is* the experience (the stickup room's take and heat) kept.
- **The board explains itself.** Eighteen Anchorage cause lines
  (`data/market_causes.gd`); when the current district's biggest mover
  crosses 15%, one line a day, never a price move.
- **The opening moment.** Yalonda's welcome is four lines; her terms are
  the first text on the phone, and the first thing on it you can answer.
- **Home's route line is live.** The mockup's `route` string ("+$127
  Downtown") is no longer shown; Home reads `best_route()` like Market.
- **PR #107 folded in** under the universal verbs: Dre's collection and
  ultimatum copy, contract bodies, lender and collector lines, People.
- **Version 0.8.0**; `docs/WORLD_SPEAKS_REVIEW.md` answers the prompt's
  six questions.

### Measured

| Suite | 0.7.0 | 0.8.0 |
|---|---|---|
| parity | 13,346 | 13,556 |
| confrontation | 2,994 | 3,445 |
| dre | 404 | 427 |
| save-validation | 247 | 257 |
| smoke panel | 88 | 96 |
| territory / tips | 170 / 93 | unchanged |

## 0.7.0 — Blow by Blow: the hit lands, the words fit, the street shows up (2026-09-03)

The owner's directive, in one line: *"I want to see playable improvements in
the next game."* After 0.6.0 the confrontation chassis was complete and the
popups still were not the fun part. A live walk through a shakedown found
why, and every one of those findings is closed here.

### The words fit

Every street encounter, checkpoint, doorstep visit, Dre collection, corner
script and 907List meetup used to end on the sheet's shoplifting copy. A
three-round fistfight over nothing read "YOU DIDN'T GET FAR — The take is
gone and the room remembers your face." Every road of every card and script
now ends in its own words: twelve cards, road by road and tier by tier, the
shakedown room's own roads, the crew calls, the checkpoint, the doorstep's
three families, Dre, both corners, the meetup, and the stickup rooms. The
card's own opening line is the situation on the sheet, where you can read it.
The person in front of you is the headline. The word CONSEQUENCE, the
engine's name for itself, no longer renders anywhere.

A guaranteed road now states what it will actually take, computed from what
is in your pockets and on your back: "Right now that is $160 in hand and 3
units of product." When there is nothing to take, it says so, instead of
promising a loss it cannot deliver.

### The hit lands

Every round of every room ends in a result before the next decision is on
the table. In the shakedown room a beat's damage lands when the beat
resolves, and the bar drains right there, with the exact number counting
beside it. The totals did not move: every path costs exactly what it cost in
0.6.0, it just costs it when it happens. The stickup rooms show the stack
that just banked, the watch that bought the next move cheaper, and the slip
that turned the room; the doorstep, the corner and the meetup show their own
second rounds the same way.

### The panel

A road is one button with the line under it. Three roads used to stand 330
pixels tall with the third under the fold; now four roads fit on the sheet
with the street visible above it, and the test suite measures both facts on
every card rather than trusting a screenshot.

### The street shows up

A clean player used to meet the street on fewer than three walks in thirty.
The floor is a dime instead of three cents, a clean player can no longer walk
more than eight quiet walks running, and a run's first encounter comes no
later than its fourth walk. Measured across six seeds: four to nine
encounters in thirty walks, with the hot profile's guarantees untouched.

PAY is a fourth road on four cards, where money is the point: pay the two off
the wall, slip the cop something, pay off the argument on the lot, settle the
block's tax. A price is not a roll, and it is not the guaranteed out either —
it is blocked when you cannot cover it, it comes out of either pocket, and
the cop remembers who paid.

#### Next up

Replies on texts — the player has never said a word to anybody — is the
smallest build with the biggest hole behind it; `docs/VISION_REVIEW.md`
makes the case and orders what follows it: price causes and world prices,
the ending (D-2, still the owner's ruling), Curtis's weekly pressure, then
territory offense with a cheaper first block.

### Under the hood

No save-schema bump. Interim results ride the persisted chain's own result
block and the loop's own note to itself; every new field is derived or
transient. Parity 13,281 → 13,346. Confrontation 1,266 → 2,994.
Smoke gained an 85-check panel arm that reads rects on every authored card.
`export_presets.cfg`'s version, which 0.6.0 left at 0.5.0, moves with the
build.

## 0.6.0 — Squared Up: it gets in your face, and it does not take the screen to do it (2026-08-29)

The owner's directive, three parts: an encounter should be a popup over the
street rather than a full-screen takeover, with a health bar that MOVES as
damage lands; the wander pool should stop being a skeleton and carry the
everyday street; and the per-path scripts that have been authored and unwired
for two builds should get their triggers.

Underneath all three was a drift nobody had caught. Encounters were
full-screen and it was enforced *globally* — `ScreenManager.blocking_route()`
returned CONSEQUENCE for any live chain, so every navigation landed there. It
was never "some encounters"; it was all of them.

### The street stays visible behind it

Decision and result stages now render as a `ModalSheet` over whatever screen
the player was on. Booking and release still take the whole screen, because an
arrest genuinely is a takeover. The rendering was lifted out of the screen
into one shared builder that both presentations consume, so they cannot drift
on what a chain looks like.

A blocking sheet cannot be swiped away: the scrim still stops the tap and no
longer treats it as a dismissal, and the grab-bar is not built at all rather
than built and ignored. It closes exactly one way — the chain resolving.

None of it is persisted. Presentation is derived from the live chain, which is
why a save loaded mid-round reopens the sheet over Home with the same round,
the same bank and the same burned verbs, and why this whole build needed no
save-schema bump.

### A health bar that moves

There was no health bar anywhere in the build — the consequence screen printed
`HEALTH 80/100` in a text strip. There is one now, and after a round resolves
the delta *animates* from the previous value with the exact number counting
alongside it, so the player watches the hit land instead of reading a
different number.

### Three roles, and the two guaranteed outs that were missing

Every general encounter now declares `fight` / `run` / `surrender` as a
structural role per choice. Labels stay per-card and in voice — STAND THERE,
DO NOT STOP, HANDS OUT, CROSS THE STREET — and the role is what the chassis
reads.

That mattered immediately: **two of the four cards shipped in 0.5.0 had no
guaranteed out at all**, on a chassis whose stated rule is one guaranteed out
per round. The police stop gained HANDS OUT and the young ones gained CROSS
THE STREET, and a suite arm now sweeps every card and refuses to pass if any
of them is missing a road. Care was what enforced that rule, and care missed
twice out of four.

### A round that is actually a new round

The one multi-round street encounter was one verb re-rolled at worse odds each
time, with generic per-round log copy — the exact thing the loop's own header
forbids. It is three authored situations now: they close the distance,
somebody else joins, the door is behind you. Each has its own copy, its own
roads and its own numbers, and the last one drops the run road because there
is nowhere left to run.

### The street has a roster

Four encounter cards became twelve. Three police searches (the on-foot stop
plus a vehicle search and a warrant check), two hostile addicts, and seven
general street situations — wrong place wrong time, mistaken identity, a
territorial beef, and one that is somebody else's problem until you answer it.
The warrant check is the one card in the game where the guaranteed road is
genuinely the worst one, and it says so in plain words before you commit.

The interruption gate itself was not touched, and that is now *proven* rather
than asserted: its decision is re-derived in the suite from only the two
inputs it is allowed to read and matched against what it actually decided,
thirty for thirty. A cold day-one player still gets interrupted on fewer than
three walks in thirty.

### Everything the street sees, it remembers

Every encounter now writes an observation on resolution — keyed by the road
taken and the tier reached, at the district it happened in, receipted so a
reload cannot double-write it. Standing on a corner, walking past one, and
paying to leave one are three different facts about you now.

### Crew calls, and three tables that were waiting

`CREW_CALLS`, `MARKET_SCRIPTS` and `MEETUP_SCRIPT` had all been fully authored
since the loop was written and consumed by nothing. Tone and Deshawn can be
called into a street encounter or a debt collector's visit — once per
encounter, costing a favour, burning no verb. The corner answers back on both
surfaces: a buyer who counts short after a sale, and Curtis's people deciding
the block is theirs, with standing on it and stepping off writing opposite
entries into his ledger. And the 907List finally has the scene its spec always
named, on the one meetup outcome that used to decide nothing.

While wiring them, the file that documented all of it turned out to have been
lying: four of the five entries under "authored and NOT yet wired" had shipped
builds ago. Corrected, and the suite now asserts the correction.

### The odds went dark

Every response lane carried a qualitative band beside its name — STRONG
CHANCE, FAIR CHANCE, RISKY, BAD ODDS, DESPERATE. The owner's ruling on seeing
it shipped: *"all of these hints can be removed. Dang give the player some
mystery."* They are gone. A lane is its name and what it is for, and you find
out the rest by taking it.

Two things stayed, because neither is an odds hint: an arrest warning still
says THAT a road can book you and never at what number, and a guaranteed road
still states its price — a price is knowable before you pay it, and one card
makes the guaranteed road the worst one on purpose.

Nothing about the engine changed. It still computes every probability it
always did; it just stops telling you.

### Under the hood

No save-schema bump. Every field this build needed already existed or was
derivable from one — including the corner's once-per-district-per-day bound,
which reads a day-stamped counter the market pressure system already keeps.

Parity 12,763 → 13,276. Confrontation 251 → 1,248. Save validation 235 → 247.
Screen smoke gained 67 component checks covering three runtime-built UI
components that nothing in the build could previously see — a gap that caught
a real parse error inside a minute.

## 0.5.0 — The Street Answers Back: you can't walk it for free anymore (2026-08-29)

The owner's own words, after playtesting with *Drug Lord 2* open beside it:
"I should not be able to continuously hit the walk-around button on the Home
screen indefinitely." Wandering paid out against exactly two ordinary
encounter cards at static weights that read nothing about the player — a
run at BURNING Heat with three districts HOT drew from the same gentle deck
as a clean day-one kid. This build answers all three of DL2's own beats:
the street initiates now, running costs what you're actually carrying, and
an unpaid debt eventually comes to you instead of waiting to be paid on
your schedule.

#### Next up

FS-002.4+ Territory offense is still the next systems arc, groundwork
already shipped and waiting. `86bbjxtfz` (the ending) is still an open
escalation needing the owner's ruling. The per-hustle-path deepening
(`86bbnk6en`'s own remaining scope) is still ahead of this build, which
shipped wander/travel/doorstep as one slice of it. A gear system that moves
fight odds (`86bbptgp1`) was deliberately not built here — the owner ruled
fights stay hands-only, the Combat attribute against authored opponent
rows, until that pass runs on its own.

#### Added

- **The street reads the player before it interrupts them.** Every wander
  and every district crossing now rolls a seeded gate whose chance climbs
  with Heat, District Pressure, Curtis's awareness and overdue debt — a
  cold, paid-up player stays near-silent (measured: a clean profile's gate
  opens on 6 or fewer of 30 walks), while a player already loud enough to
  matter cannot out-wait the street (a maximally hot, indebted profile
  never goes quiet longer than 2 consecutive walks running).
- **Four new street encounters**, each authored in the register of
  Courtney Kemp's *Power* — terse, threats delivered as terms, violence
  discussed like logistics until it isn't: an armed shakedown whose
  escalation is this build's first multi-round room (fight it out, blow by
  blow, if FIGHT doesn't end it on the spot); a deepened police foot-stop
  that finally activates STASH IT, a script authored months ago and never
  wired to a caller; a Curtis-side tax stop; and a low-stakes charisma read
  so the roster isn't all guns. Every road puts what's actually being
  carried on the table — DIRTY cash and carried product, through the same
  Wallet and inventory owners every other consequence already uses, never a
  second ledger.
- **The checkpoint**: district travel rolls the same interruption gate a
  wander does. A patrol stop while crossing hot or holding — talk your way
  through, run for it, or hand it over — replaces the older silent
  carry-stop tax for that trip rather than stacking on top of it, so one
  crossing is never taxed twice under two different names.
- **The doorstep**: once Dre's account, a defaulted Book note, or rent
  arrears go far enough overdue, the day starts with that visit whether the
  player wants it or not — one obligation at a time, worst debt first,
  escalating from a forced decision into a real physical enforcement room
  if it still isn't resolved. No road ends a run directly; the worst
  outcome only ever costs health and the debt itself, through the game's
  own existing end conditions.

#### Changed

- **The `arbitrage` economy profile's own corridor moved from 180-320% to
  140-320%**, measured rather than defended at the old number: arbitrage is
  built entirely out of district crossings, so it is the one profile most
  exposed to the checkpoint's new cost by construction. 158% on this
  build's own baseline still clears "materially riskier, not priced out of
  the strategy" — the same balance guard every interruption gate in this
  build was tuned against.

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
