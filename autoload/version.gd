extends Node
## Version — the build's version string, in one place.
##
## Semantic versioning, MAJOR.MINOR.PATCH:
##
##   MAJOR  a break in save compatibility or in the shape of the run itself.
##   MINOR  a feature milestone — a build that ships new surfaces or systems.
##   PATCH  bug fixes and tuning against an unchanged feature set.
##
## The number lives HERE and nowhere else. The title screen reads it, the web
## export stamps it into the HTML shell's <title>, and the parity suite asserts
## it is well-formed. A version written down twice is a version that disagrees
## with itself the first time somebody bumps one copy, so nothing else declares
## a literal — `Version.VERSION` is the only source.
##
## Registered as an autoload so a screen can reach it by path (`/root/Version`)
## the same way it reaches GameState, without preloading a script for a string.

## Dre Lending & Loan-Shark Progression (PR A-E) closes here: a new
## relationship system, authored contracts, and an earned hustle surface
## (THE BOOK) — the clearest "ships new surfaces or systems" case since this
## file's own MINOR rule was written, so this is the bump that uses it.
##
## 0.2.1 (TOUCH-D7): the touch-scroll pass-through fix and the first Android
## debug build. Neither ships a player-facing surface or system against the
## rule above — the game plays the same, it just scrolls correctly now and
## also runs natively on a phone — so this is PATCH, not MINOR.
##
## 0.3.0 (Answer For It): a blown tier-1 stickup gets its own caught decision
## instead of skipping straight to Booking (D-13) — a new player-facing chain,
## which is the MINOR case squarely. Riding with it: Heat's own unconditional
## nightly decay (D-14) and a second Spenard stickup target with a rep-scaled
## daily cap (D-15).
##
## 0.4.0 (Repeat Business): Dre's book becomes standing work — a fourth
## consumer proves the Street Opportunity substrate generalizes beyond Dre's
## own content (SCR-D1..D3, D-16), a repeatable-contract generator rides the
## existing collection encounter with zero schema bump (REP-D1..D5, D-17),
## and a four-template catalogue across three distinct roles fills it out
## (CAT-D1..D4, D-18) — a new standing-content system, squarely MINOR. Riding
## with it: Boost and Stick each gain a per-family daily District Pressure
## cap on Market's own precedent (PRESS-D1/D2, D-19), measured honestly as a
## partial result rather than a full close.
##
## 0.6.0 (Squared Up): every confrontation stops taking the screen and becomes
## a ModalSheet over the street with a live health bar (SQ-D1..D5), the general
## street gets a structural verb triad and the two guaranteed outs it was
## missing (SQ-D6), the one room in the build stops being a re-rolled verb and
## becomes three authored situations (SQ-D7), every encounter writes an
## observation (SQ-D8), crew calls stop being an authored table nothing reads
## (SQ-D9), the wander pool goes from four cards to twelve, and the last three
## unwired scripts -- both corner rooms and the 907List meetup -- get their
## triggers (SQ-D10). New player-facing surfaces and systems, squarely MINOR.
## No schema bump: everything this build needed was derivable from a field the
## game already kept.
##
## 0.7.0 (Blow by Blow): every chain kind authors its own result copy and the
## card's line is the situation (BB-D1/D2), every round of every room ends in a
## result and beat damage lands at the beat (BB-D3/D4), the roads become one
## button each with the street measured visible above them (BB-D6), the gate
## floor rises with a cold cap and a first-walk guarantee, and PAY is a fourth
## road on four cards (BB-D8/D9). New player-facing behaviour, squarely MINOR.
## No schema bump: interim results ride the persisted chain's own blocks.
##
## 1.0.0 (One Good Run): the run has an end. A way out priced by what the
## player built, three ways it ends on them, and one reckoning screen
## (OG-D4); rank derived from the ledgers and gating crew, corners, the
## board and the door (OG-D2); a weapon, a car and a trunk (OG-D3); the
## Lift walking out with a thing the 907List fences (OG-D5); Curtis's
## blocks fighting back (OG-D6). "The shape of the run itself" changed --
## it has a beginning, a middle and an ending -- which is the MAJOR case
## this file's header has been holding at 0 for. Four schema bumps rode
## the build (v29 rent arrears, v30 the kit, v31 the ending, v32 hot
## goods), every one migrated, none breaking.
##
## 1.1.0 (Somebody Shows You Around): the first ten minutes (Juan says how a
## day goes, Help describes the game that exists, the title says who you
## were, the reckoning says what there was -- SA-D1); the beater on the
## street (three cards, a trunk that can be lost, the weapon's sentence in
## the room -- SA-D2); Mina Vale's trust off her ledger and the evening her
## family shows up (SA-D3); the house talking back every third morning
## (SA-D4). New player-facing content and surfaces on the existing
## systems, squarely MINOR. No schema bump: everything this build needed
## was derivable from a field the game already kept.
##
## 1.2.0 (His Side of the Board): a front is a bill (HS-D1), Tone holds it
## down and you stand watch (HS-D2), Curtis comes back and then he does not
## -- the dismantleable gate D-2 ruled a mid-game unlock (HS-D3), and Turf
## reads the board in words, never a percentage (HS-D4). FS-002.6, .8, .9
## and .10 as this game has them. New systems on the territory the 1.0.0
## contest opened, squarely MINOR. One schema bump (v33: the districts he
## is out of, and the hold toward it).
##
## 1.3.0 (Tighten It Up): the 1.2.0 playtest, answered. The day has edges
## (TU-D1), a name is earned on the street and once per thing (TU-D2), the
## phone in your hand from the owner's mockups (TU-D3), cards that say what
## is happening with no subtext, seizure at booking, drops, buyers (TU-D4),
## and clock in, move up, again: experience on the ladder, a word about
## money, a moment every shift (TU-D5). MINOR. One schema bump (v34, the
## day's buyers).
## 1.4.0 (Room to Move Up): the crew ladder stops lying about itself. A
## rank a save can hold (RM-D1), one capability table (RM-D2), proof
## written where the work settles (RM-D3), promotion as a requirement list
## with SPECIALIST LEAD reachable by role-specific proof (RM-D4..D6), and
## the standing brief -- a lead's operation renewing every morning without
## the player (RM-D7..D9). A new reachable rank and a new kind of
## delegation are new player-facing behaviour: MINOR. No schema bump:
## proofs and the brief ride dictionaries the save already carried.
## 1.5.0 (Her Side of the Street): a business is a second axis over the
## same board -- a person with a till and a ledger, whose allegiance is a
## different question from whose ground it stands on. One identity joining
## the shipped ids a Spenard door already had (HSS-D1), a row whose presence
## means known (HSS-D2), four owners on the Exposure roster (HSS-D3), and
## three ways in: ASK, LEAN and TAKE (HSS-D4). Bands raise the take a
## little and every cost a lot (HSS-D5, D6), the top one has a nightly
## failure roll under it (HSS-D7), an arrangement nobody backs pays half
## (HSS-D8), and the board says all of it in words on Turf (HSS-D9).
## New player-facing behaviour and a new economy: MINOR. One schema bump
## (v35, `businesses`), additive -- an older save discovers its businesses
## from the history it already carries.
## 1.5.1 (The Floor): a corrective release. Zero health ends a run -- the
## web canon did this and the port never carried it over, so a player could
## sit at zero and keep playing (FL-D1). Injury above zero is unchanged
## (FL-D2). The "cash out" ending is deleted with no threshold replacing it:
## wealth never ends this game (FL-D3), which closes D-2. The first rent
## moves to day 14 so the free week is a whole week (FL-D4); Juan stops
## repeating Yalonda's tutorial (FL-D5); the People card stops printing its
## own internals (FL-D6); the Turf board is earned at KNOWN (FL-D7).
## PATCH: nothing here is a thing a player asked for, and no schema moved.
## 1.6.0 (Sleep It Off): the recovery loop 1.5.1 made necessary. Zero health
## became death and nothing gave health back but paid treatment -- the web
## canon's free rest at home had been dropped in the port, so a survivor's
## incidental damage was permanent. REST is that verb back: no money, one
## slot, +10, no per-day cap because time is the cap (SO-D1). Lay Low is
## folded into it, and the first REST of a day still sheds Heat and files
## Curtis's read (SO-D3). A day that did no damage heals +3 overnight, or +1
## inside the severe band at or below 30 (SO-D2, SO-D5), tracked by a derived
## `damage_today` (SO-D4). The economy harness now treats, rests and declines
## fights while hurt, so its corridors measure strategies again (SO-D6).
## A new player-facing verb and a new lifecycle step: MINOR. One schema bump
## (v36, `damage_today`), additive.
const VERSION := "1.6.0"

## The pieces, for anything that needs to compare rather than display.
func major() -> int:
	return int(VERSION.split(".")[0])

func minor() -> int:
	return int(VERSION.split(".")[1])

func patch() -> int:
	return int(VERSION.split(".")[2])

## What the title screen shows. Kept here rather than formatted at the call site
## so every surface that stamps the build stamps it identically.
func display() -> String:
	return "v%s" % VERSION
