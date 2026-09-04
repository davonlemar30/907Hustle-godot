# The Block Remembers — the build, and the eight questions

_Written 2026-09-03 at the close of 0.9.0, against `907Hustle_Build_Prompt_v3.md`.
Companion to `docs/VISION_REVIEW.md` (0.7.0) and `docs/WORLD_SPEAKS_REVIEW.md`
(0.8.0). Rulings are D-27 in `docs/DECISIONS.md`._

## What shipped, in one paragraph each

**PR 1 — the screen holds.** The stretch bug, three builds old, was one
unwrapped label: Home's activity feed rows set a minimum width past the
phone and the whole shell grew and centered, both edges cut off. The rows
wrap, and the smoke suite now instantiates every screen at the phone's own
width over the longest lines the game writes and refuses any control
outside it (2,743 checks; the unwrapped Home fails it). Applying for a job
is a state on the card, answered by text. The Market's Cargo Value block
and its dead PLAN A ROUTE button are gone. When somebody swings first, the
encounter answers back: a fistfight in a room generated from the card's
own odds.

**PR 2 — clock in, move up.** Interviews (three questions in the manager's
voice, two answers each, the score on the chance), three earned rungs per
job gated on days, streak, rapport and the job's attribute, and floor
buttons that do something: a coworker, rest and a rumor, the manual.

**PR 3 — your corners, their corners.** Every block belongs to a district.
Downtown's five venues earn more and run hotter; Ship Creek's three lots
are supply, a cut off every buy anywhere; Spenard keeps its six corners.
Claimed where you stand, once the district is known. The Turf screen has
tabs, held-of-total per district, whose each block is, what a held one
makes, where soldiers stand.

**PR 4 — Mountain View.** A fourth district with its own bias (pills and
lean pay, the club drugs want Downtown, weed has its own channels), its
own heat (the stickup family's heaviest multiplier in the city), its own
adjacency, four cards, two marks, two targets and three corners. It opens
a week in, or earlier when two brothers at the bus shelter name it. The
first bus there is an arrival sheet. Its market walks on its own RNG
stream so the three canon markets still pin to the oracle.

**PR 5 — they have their own ideas.** Two operations on the existing
substrate (Eli scouts a district and reports the board; Tone puts a
problem down with force, at a cost in heat), mission buttons on the Crew
screen for every operation a member knows, and proposals: a member sure
of you texts an idea that fits the day's situation, and yes is the
assignment.

**PR 6 — the close-out.** Version 0.9.0, D-27, docs, this review.

## The eight questions

### 1. Does the per-district territory system create meaningful strategic choices, or does it just multiply the same decision?

It creates two new decisions and multiplies one.

The new ones: Ship Creek is the first block whose value is not a number a
night. A held lot is a cut on every buy, which is worth more the more you
trade and nothing if you do not, so a worker-turned-trader wants it and a
corner boss does not. And Downtown's venues run hot enough that holding
one changes what you can do with the rest of your day in that district,
which is a decision the Spenard corners never asked.

The multiplied one is Mountain View's corners, which are Spenard's corners
with different names. They are there because the prompt asked for
per-district blocks and a fourth district, and an empty tab would have
read as a bug. If the block's corners are going to matter, they need the
rule the World Bible gives them and this build did not: held on trust, so
a corner in Mountain View should require the block to know you (a
disposition gate on the community figure) and should lose soldiers to the
block, not to Curtis, when your reputation there falls. That is the next
territory build, not this one.

What is still missing everywhere is the thing the Godfather doc's Phase
5.2 note names: Curtis's blocks are classification, not contest.
CURTIS'S reads on the tab and costs more to claim, and claiming it is the
same tap as an open one. Taking a block from Curtis should be a
confrontation, and until it is, the districts multiply a decision that
was already too easy.

### 2. Does Mountain View feel like a distinct place with its own rules, or does it play like a reskinned Spenard?

Distinct on arrival and on the board, reskinned on the corner.

Distinct: the arrival sheet, the four cards (the courts, Juba Market, the
church lot, and Reggie asking who you are with), the market (pills and
lean pay, and the arbitrage profile found the route inside a week, which
is why its bias was tempered twice), and the heat (a stickup there carries
1.5x because the block knows the family you robbed). The "who are you
with" encounter is the one card in the game where the cost of the wrong
answer is not damage but the block: product walks off with a kid you did
not see, and nobody outside the barbershop saw a thing.

Reskinned: the corners (see question 1), and the fact that the community
figure the prompt asked for exists only as Reggie's name on a door.
Mountain View's rule is trust, and trust is an Exposure lens the district
does not yet have. Giving the block a lens (an NPC who is the block: the
barbershop owner) and gating its corners and its best buyers on that
lens is what would make it play differently rather than read differently.

### 3. Do crew-initiated actions make the crew feel alive, or do they feel like random events wearing a crew member's name?

Alive when the proposal fits the situation, which is the whole design.

Tone texts "Problem in Spenard. I can handle it. Say the word." only when
there is pressure there. Eli offers to run the bag only when there is a
route and you are holding product. Pherris offers the board only when you
have listings. The proposal is derived from state, not rolled, and the
seeded chance only decides which morning. That is the difference between
a character with a read on the day and a random event with a name on it,
and it is why the suite asserts the proposal names the district with the
pressure.

Where it thins: the proposals are one line each and the yes and no are
fixed. After the third "Problem in Spenard" the line is a button. The fix
is authored variety (three lines per member per situation, seeded on the
day) and, more than that, proposals that are not assignments: Deshawn
saying somebody on the block asked about you, Pherris saying a buyer
wants a thing you do not have. Ideas that make the player do something,
not only ideas that make the crew do something.

### 4. Is the job promotion system worth deepening further, or is it good enough as a background income system?

Good enough, and the measurement says stop.

The rungs are earned now (days, streak, rapport, attribute) and the first
cut of the gates held a plain worker at the bottom rung for a whole run
and cut the job yardstick 28%. The eased cut reaches the second rung in a
week of showing up and the third with one point of the job's attribute,
which the floor buttons can earn. That is a ladder with a top, and the top
is a title and a text. A player who wants more from a job than that is a
player who should be doing something else, and the game has other things.

What would be worth one more pass is not depth but consequence: a
Keyholder at the Wash & Go should be able to work an evening shift alone,
which is the first legal reason to be on Spenard Road at night; an
Assistant Manager at the Chevron should see the night till's schedule,
which is a stickup mark. Rungs that open doors elsewhere in the game are
worth more than rungs that pay ten percent.

### 5. What is the single biggest gap between the current game and the vision?

You.

The crew has missions now, the blocks have districts, the city has four
places, and the player is still a wallet with legs. The vision sentence
is "customize your crew, send them on missions, hold blocks, buy cars,
properties, move weight, become the biggest boss," and every noun in it
that the game has is something the player owns or orders, and none of it
is something the player *is*. There is no weapon in your coat, no car at
the curb, no place you sleep other than Yalonda's room, no way to be
seen on the street as anything but a new face with a bag.

The concrete shape: `gs.attributes` (combat, charisma, intelligence) is
the only thing about the player that persists and grows, and it is
invisible until a roll reads it. The next major system should be the
player's kit: a weapon slot that changes the FIGHT road's odds and the
observation it writes, a car (question 7), and a stash that is not your
pockets. Those three make the player a character the crew works for
rather than a menu the crew is on.

### 6. What should be CUT from the game?

Three things, in order of confidence.

**Cut the 907List's execution modes.** The board has tiers, brokers, a
routing choice on settle, and Pherris's operation on top, and the
creative director's read is that it is "easy af" and does not feel like a
chance game. The layers are complexity that does not produce a decision:
the player lists, waits, collects. Collapse it to one flip with a real
risk roll (a buyer who is a setup, a listing that draws a text from
somebody who recognizes the item) and let Pherris be the thing that makes
it safer, not the thing that makes it a second menu.

**Cut the hustle surfaces menu's tier copy.** "You're a Hustler now" and
the tier names on the Hustle screen are progression labels from the web
build that nothing in this port reads. The rooms open on their own gates.

**Simplify soldiers into crew.** Two rosters (crew with names and
loyalty; soldiers with a count and a wage) is one roster too many. A
soldier is a crew member without a name, and the Godfather model the
vision cites has one kind of person on a block. Fold soldiers into
unnamed crew ranks or give them names. Either way, one screen.

### 7. Propose a vehicle/car system in one paragraph.

The simplest car that changes gameplay is a beater bought from Sonny's
nephew for $1,400 that does three things and costs one. It cuts travel to
a district you have been to from a slot to free (the fare stays, gas now),
which is the first time the four-slot day gets bigger. It carries: cargo
cap +4 when you are in it, and a stash you can leave product in overnight
that the checkpoint cannot search without probable cause, which is the
first hiding place in the game. And it is a target: parked Downtown it
draws a card (window smashed, product gone, or a tow you cannot afford to
claim), and driving it while carrying makes the vehicle search card real
for the first time. The cost is Anchorage's: a battery that dies below
-10°F unless you paid for the block heater, insurance Yalonda notices you
did not buy, and a plate that Curtis's people can read, which is the
Exposure hook: a car is a face that stays parked where you were. No
garage, no upgrades, no second car. One beater, and the day gets bigger
and the risk gets a shape.

### 8. Do Boost and 907List currently feel like they earn their income, or are they free money paths that need friction? If the pipeline was built, assess it. If not, describe what it would take.

They are free money, and the pipeline was not built.

Boost's income is a roll against a tier with a caught state that opens a
room; the room is good (0.6.0), but the take is abstract cash and the
economy sweep's boost profile sits at a third of a job, which means it is
not even good free money. The 907List is a wait: list, settle, collect,
and the profile that only flips runs at 460% of a job with no arrest and
no risk roll that hurts. Neither asks the player a question after the tap.

What the pipeline takes: Boost produces an item (`{kind, value, heat}`
drawn from the target: a Northern Value coat, a pharmacy's bottle, a
Gateway Electronics box) into a `hot_goods` inventory separate from
product; the 907List becomes the only place hot goods turn into cash,
each listing a roll whose failure tiers are the friction the prompt asks
for (a buyer who is a cop at high volume, a buyer who recognizes the
store's tag and texts somebody, a listing that sits and costs a day of
heat). Pherris's operation is what lowers the roll. The dependency that
made it a future build rather than this one: `boost_targets` carry `take`
as cash ranges, `listing_items` are authored separately, and the wallet,
the seizure rule and the market-pressure penalty all read product and
cash and nothing else. Adding a third inventory touches the wallet
provenance rule (dirty cash from a fence is a different observation than
dirty cash from a corner), the save schema, the seizure table, and the
Hustle screen. It is a build of its own, roughly the size of PR 3 here,
and it is the right next build for the income side of the game because it
turns two buttons into one decision the player has to manage.

## What was not built, and why

- **Mountain View's community figure as an Exposure lens.** Reggie is a
  name on a door and a question. The lens is question 2's recommendation.
- **Contested takeovers of Curtis's blocks.** Classification only, as
  FS-002.3 left it; the Godfather doc's 5.2 note still stands.
- **Boost → 907List.** Question 8.
- **Proposals that are not assignments.** Question 3.
- **Two economy corridors lifted in PR 1 and two markets' biases tempered in
  PR 4**, each recorded at the constant with the measurement.
