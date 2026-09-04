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
const VERSION := "1.0.0"

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
