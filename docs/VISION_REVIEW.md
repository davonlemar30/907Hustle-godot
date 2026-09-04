# Vision Review — against the Full Game Vision (2026-09-03)

The owner handed the project a vision document alongside the 0.7.0 build: what
907Hustle is, what it takes from *Drug Lord 2*, *The Godfather II* and *Torn*,
the four-phase player arc, and eight questions the builder is asked to answer
with an opinion rather than a nod. This page is the answer. It is written
against the code at 0.7.0, not against what the tracker says is planned, and
where it disagrees with the vision it says so and says why.

The short version: the engine is further along than the vision assumes, the
*feel* was further behind than the vision assumed, and 0.7.0 closes that
second gap for the one system the owner named. The three biggest holes the
vision does not name are an ending, a way for the player to answer anybody,
and a reason for prices to be what they are.

---

## 1. What 0.7.0 built, against the vision

The vision's confrontation section asks for four clear options, a visible
health bar, readable enemy information, and combat as a resolution system
rather than a mode. All four existed at 0.6.0. What did not exist was the
feel: results in somebody else's vocabulary, damage that landed once at the
end, no beat between rounds, a panel that hid the third road below the fold,
and a gate that let a clean player walk thirty times and meet the street
three of them.

0.7.0 is five pull requests against exactly that list, and nothing else:

| PR | What the player gets |
|---|---|
| A — the words fit | Every chain ends in its own words. The card's line opens the sheet. The opponent is the headline. Guaranteed roads price themselves against what is in hand. |
| B — the hit lands | Beat damage lands when the beat resolves; every round ends in a result before the next decision. |
| C — the panel | One button per road, all roads visible without scrolling, the street genuinely visible above. |
| D — the street shows up | A clean player meets the street inside the first day and 4–9 times in 30 walks; PAY as a fourth road where money is the point. |
| E — close-out | Version, docs, this review. |

Deliberately not built, and the vision agrees: weapons (its own design pass),
territory warfare (FS-002.4+), the ending (the owner's ruling, D-2).

---

## 2. Where systems do not talk to each other

Three real disconnects, each with a bridge that costs one build or less.

**Prices have no reason.** The vision's first Drug Lord 2 note is that every
price swing carries a sentence. The economy already keeps the facts a sentence
needs: District Pressure per family per district, Heat by band, Curtis's
phase, and a market-intel read on the phone. Nothing joins them to a price
line. The bridge is a `cause` on every meaningful price move, chosen from the
loudest live signal in that district (a sweep, a shortage, a rival moving
weight), rendered on the market row and in Word Around Town. Filed as
`86bbfz180` since August; it is a content table and one read, not a system.

**Respect is written by nothing.** The HUD renders `gs.respect` and no
system has ever incremented it. The vision asks for Rank instead of Identity
and for reputation to be "the real currency of access." The observation
ledger already knows what the player has done, in eleven categories, per NPC.
The bridge is to derive Rank from that ledger — the same "derive before you
persist" rule 0.6.0 and 0.7.0 both paid for — and to retire the dead number.

**The world remembers and the player cannot perceive it.** Yalonda notices
rent paid and never mentions it. Curtis has two phase messages and one
borrowed line. The People screen renders the ledger as a scoreboard. The
bridge is the smallest one in this document and the highest-leverage: two
replies per text, chosen from the ledger's own bands, with a disposition
consequence. See §7.

---

## 3. Where the early game loses players

Day one hands the player $100, a job board, and a walk button. At 0.6.0 the
walk paid out against a gate tuned so a clean player would not be punished —
which also meant a new player would not be *shown* the best system in the
game for days. 0.7.0 PR D forces the first encounter by the fourth walk and
raises the floor. That is the single biggest early-game change this build
makes, and it was a number, not a system.

What is still thin in Phase 1: the plug. The market exists, but "finding a
plug" is discovery through wander, and a player who takes the job first may
never wander. Recommendation: the first Goodie text arrives on day two
regardless, through the phone, and it is a reply-able text (§7). The vision's
Phase 1 fantasy — "I need to figure this city out" — needs one person who
speaks to the player first.

---

## 4. Where the late game goes flat

The direction finding from the August studio pass still stands: the run has
a start and a fail state and nothing in between that resolves. Rent is a flat
$150 a week with three warnings; a competent run is unpressured from about day
fifteen. Curtis escalates in phases that mostly change copy.

The vision's Godfather II answer is the right one and it is already
half-designed as FS-002: Curtis has revenue, a network, and people, and each
can be stripped. What the vision under-specifies is the *pressure* side. The
opinion here: before territory offense ships, Curtis needs one thing he does
to the player each week past day fifteen that costs money or a person, on a
schedule the player can read. The doorstep already knows how to force a
visit; a weekly Curtis visit on the same chassis is one adapter and one
script, and it is what makes the middle of a run feel like a middle.

---

## 5. A lose condition that feels earned

Eviction after three warnings is an accounting event. The title of the game
is *One Good Run*, and the ending should be the run. Proposed ruling for D-2,
in three parts:

1. **The run ends when you get out.** A named number of clean money — clean,
   because dirty cash is the thing the city can still take — plus a day the
   player chooses to leave on. That is the win, and the epilogue scores it:
   what happened to Yalonda, to Tone, to the corners, to the people you
   robbed. The vision calls this "the cheapest replay driver available and it
   is pure content." Agreed.
2. **The run ends when the city gets you.** Three ways, each already
   half-built: evicted with nothing (the existing warnings, kept); booked with
   priors past a threshold (the arrest system already keeps a record; the
   third serious booking is a sentence, and the sentence is the ending);
   and Curtis, when Exposure maxes and the player has no crew standing — the
   doorstep's enforcement room with nobody to call.
3. **The reckoning screen shows both in one frame.** What you built, what it
   cost, who remembers you. Win and loss are the same screen with different
   copy, which is why it should be built once.

This is a ruling, not a build. It is written here so the ruling has a draft
to say yes or no to.

---

## 6. Territory pacing

Territory reads at roughly four times the day job once it is set up, which is
why it is expensive and late. A player in a normal thirty-day run reaches it
around day twenty if they are trading well and never if they are working.
The vision asks for an opinion: **the ladder should be cheaper at the bottom,
not shorter.** The first block should be one the player has already fought
for — the corner `corner_push` already contests — offered at a price a
Phase-2 player can cover, with Curtis's people as the first and only rival on
it. The expensive blocks stay expensive. What changes is that Phase 3 starts
at day twelve instead of day twenty, and starts with a corner the player has
a story about.

---

## 7. Relationships: the game has no conversation in it

Five named NPCs, an eleven-category ledger, five lenses, and the player has
never said a word to anybody. Every choice is a consequence-engine button.
The vision deprioritized dialogue trees for scope, correctly. The lightweight
version the vision leaves room for is this, and it should be the next build:

- **Two replies per text.** Every phone message that comes from a named NPC
  carries two answers. Neither is a tree; each writes one observation into
  that NPC's ledger and ends the exchange.
- **The NPC's next line is chosen by disposition band.** Cold, Neutral, Warm,
  Trusted, Bonded — the bands the vision names — read off the ledger the game
  already keeps. Five lines per NPC per beat, authored in the *Power*
  register, no branching.
- **Intel quality follows the band.** The tips system already generates
  intel; gating its accuracy on the band is one read.

That is four texts and twenty lines per NPC, and it is the difference between
a world that remembers you and a world that says so.

---

## 8. Missed opportunities from the three sources

- **Drug Lord 2 — world prices.** The phone's market intel shows a couple of
  routes. An Info surface with every district's price for every product,
  gated on rank or on a purchased tip, is the DL2 screen the owner
  screenshotted and it is one read of data the economy already has.
- **The Godfather II — crime rings.** Controlling every block of a district
  should unlock a district perk and breaking a rival's set should visibly
  hurt him. Territory has the ownership data (`starting_owner`, D-6) and no
  set logic. Fold it into FS-002.5's design rather than building it alone.
- **Torn — mastery curves.** Each hustle has a tier ladder (Boost techniques,
  Stick tiers, 907List tiers) and none of them tells the player where they
  are on it or what the next rung buys. A one-line "next rung" read on each
  surface is a content pass, and it is what makes Torn's crimes feel like a
  skill tree rather than a gate.
- **Torn — the morning.** Nightly resolution exists and the player reads it
  by scrolling the feed backwards. A six-line morning card — what moved while
  you slept — is the flow-sheet queue with one new builder.

---

## Recommended order after 0.7.0

1. **Replies on texts** (§7). The biggest hole, the smallest build.
2. **Price causes and world prices** (§2, §8). Content and one read each.
3. **The ending** (§5). A ruling first, then one build with the reckoning.
4. **Curtis's weekly pressure** (§4) on the doorstep chassis.
5. **FS-002 territory offense** with the cheaper first block (§6) and crime
   rings folded into its design.

Everything above is bounded, connects to at least two existing systems, and
none of it needs a new engine. The chassis is done. The game is what gets
authored on top of it now.
