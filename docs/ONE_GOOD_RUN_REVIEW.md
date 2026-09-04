# One Good Run — the 1.0.0 assessment

_Written at the close of 1.0.0 (PR 7), against the build as it measures,
not as it was meant to. Source: `907Hustle_Build_Prompt_v4.md`. Rulings:
`D-28` (OG-D1..D6). The nine questions are the prompt's, in its order._

## What shipped, in one paragraph each

**PR 1 — The rent day (`#146`).** People hides the unmet. Bills come to the
phone with a badge on the nav. Rent escalates in Yalonda's voice: a text
the night it is due, a feed line and a mark on her ledger a day late, a
second text and Juan's the day after, a house warning every third day
until the third is the eviction. Pay late and she says "You got it.
Don't make this a habit." The phone bill goes quiet, then cuts you off.

**PR 2 — Earn your name (`#147`).** Respect is gone. Rank is derived every
time it is read, from the observation ledgers every NPC already keeps:
Nobody, New Face, Known, Player, Connected, Boss. Crew needs Known; a
corner needs Player; the 907List's tiers need Known; the way out needs
Boss. It is on the HUD chip and the Character screen, and the morning
you cross a line the feed says so and somebody texts.

**PR 3 — The player's kit (`#148`).** A weapon slot bought off people on
the street; a beater bought off Sonny's nephew by text; a trunk. Every
NPC has a face, every district a banner, two venues an interior, all of
it rendering as nothing until the file exists. The ride between
districts is a card, and every screen wears the district it is in.

**PR 4 — One good run has an end (`#149`).** The way out, priced by what
you built. Three ways it ends on you. One reckoning screen.

**PR 5 — Stolen goods have a name (`#150`).** The Lift walks out with a
thing. The 907List is the fence, and the buyer is sometimes a cop.

**PR 6 — His blocks fight back (`#151`).** A Curtis block is a fight, the
odds shown. He tests what looks weak every night and texts arrive when
he takes something back.

## The nine questions

### 1. Does the ending feel earned? Does the reckoning screen make the player want to try again?

Earned, yes, on the way out; on the losses it is honest rather than
earned, which is the right shape for a loss.

The way out is gated twice and both gates are things the player did.
Boss is forty points of weighted observation, and the ledgers do not
take a shortcut: a corner claimed, a contract worked, a fight won, a
rent paid on time. The money scales with the life: three thousand
clean, plus four hundred for every corner and three hundred for every
crew member, so the player who built the most has the most to walk away
from, and the card on Home says the number from Connected up, a full
tier before it can be pressed. Choosing tonight as the last night is a
decision that can be reversed, and the card says what reversing it
costs. That is the shape VISION_REVIEW §5 asked for.

The losses are countdowns, not switches, and each one talks first.
Yalonda warns three times. The sentence is the third serious booking,
and the arrest sheet already tells the player which bookings are
serious. Curtis, maxed with nobody standing with you, is a text from a
number you do not have saved, then his car, then the door. The economy
driver's stickup profiles, which never recruit and never pay, meet him
on the eighth morning; the crewed profile that never pays Tone loses
Tone and meets him on the twelfth. That is the intended reading: the
game ends a run that ignored every warning, and it says so in the
feed each morning before it does.

The reckoning is one screen for four endings, and what makes it a
reason to try again is not the head or the kicker but the third
section: a line from every person you met, in the band you left them
in. A run that ended at Curtis's door with Mina cold and Juan neutral
reads differently from one that walked out with Deshawn bonded, and the
lines are authored per person per band, so the player sees who they
were to the city. The earnings-by-source table under it is the run's
shape in numbers: a run that was all shifts, or all fence, or corners.
What it does not yet do is show the road not taken: the rank reached
against the six, the corners held against the twelve. That is the first
thing to add, and it is a table read, not a system.

### 2. Does Rank create meaningful gating, or does it just slow things down?

It gates, and the measurement says the gates are where the game's
weight already was.

Rank is not a bar that fills; it is a reading of the same ledgers the
NPCs already consult to decide how to treat the player, with a cap of
three per observation type so that twenty shifts do not make a Boss.
Known (eight points) arrives in the first week for anyone who does
anything; Player (fifteen) takes doing several different things. The
economy driver's profiles show the cost: `boost_finder` and the corner
profiles needed the staging helper to hit their gates by day five, which
means a real player does not claim a corner in the first three days, and
that is the intent. The 0.9.0 corridors that recruited on day one were
measuring a game where the crew was free.

Where it slows rather than gates: the 907List's tiers. Known is the
first tier and it lands before most players have listed anything, so
the gate is invisible. It is correct to leave it: the gate exists so the
fence (PR 5) has a rank behind it, and a gate nobody notices is not a
cost. The one gate that will need tuning against real play is Player
for corners, because PR 6 now makes a Curtis corner a fight the player
needs crew for, and crew needs Known, so a fresh Player with no crew is
looking at neutral corners only. That is a sequence, not a wall, but
the Turf screen should say it: the claim blocker names the rank; it
should also name the crew.

### 3. Does the weapon change confrontation feel, or is it just a number?

It is a number at the door and a line in the room, and the line is
what makes it feel like something.

The knife is ten points on the FIGHT road and the piece is twenty-two,
which at the street's usual forty-to-sixty odds is the difference
between a coin flip and a favorite. But the odds are shown on the
button, so the number is legible before the tap, and that is the
feel: the player sees FIGHT 52% become FIGHT 74% and knows why. When
the knife comes out the room says so ("The knife comes out.") and heat
lands for it; the piece costs two and a half heat every time it is
drawn, and a police card that goes wrong with a piece on you is three
more and its own line. So the weapon is a bet with a visible cost, and
the cost is the thing the build was missing.

Where it is still just a number: the room's beats. The weapon adds to
the beat roll but the beat copy does not name it, so a knife fight
reads like a fistfight until the result line. The confrontation copy
table has the seam (`result_headline` takes the tier); a per-weapon
beat line is a table row, not a system.

The buying is the part that works best: the knife is a man at the
Chevron's ice machine a week in, and the piece is Dre's cousin at the
Night Owl once you are a Player, both meetings on the wander deck with
their own roads. Nobody is sold a gun from a menu.

### 4. Does the car change the shape of a day?

Yes, in three ways the measurement can see and one it cannot.

Gas instead of fare turns a three-district day from a fare decision
into a free one, which is the first change: the beater profile in the
economy driver travels when a bus profile would not. Cargo plus four is
a fifth of a load, which the arbitrage profile notices and the day job
does not. The trunk is the stash the checkpoint cannot count, which
changes what a player carries home across a Curtis block. Those three
are in the numbers.

The fourth is the one the player will feel and the suite cannot: the
ride card. On the People Mover the line is about the bus; in the beater
it is about the road, the heater, the window somebody broke Downtown.
The car's costs are authored as mornings and evenings rather than
percentages: fourteen below and it does not turn over, a parking ticket
Downtown, Yalonda noticing it is not insured, Curtis noticing you have
a car. Each is a line the player reads, not a deduction they infer.

What the car does not yet do: vehicle encounters (a stop on the way in,
a break-in in Spenard) and plates Curtis can read as a mechanic rather
than an observation. BLOCK_REMEMBERS_REVIEW §7 asked for the first; it
is a wander card with a `has_vehicle` requirement, and the deck takes
those already.

### 5. Does the Boost → 907List pipeline turn two free paths into one managed decision?

Yes, and the corridor moved to prove it.

Before this build the Lift paid cash at the tap and the 907List was a
wait with no roll that hurt; BLOCK_REMEMBERS_REVIEW §8 called both free
money. Now the Lift walks out with a thing that has a name, a kind and
a value, and the only way it becomes money is the board: list it, wait
a day, meet a buyer who is a cop four percent of the time plus one and a
half per point of heat plus eight if three hot things are up, or a man
who reads the tag one time in ten, or nobody, one time in seven. When
it is clean it is sixty cents on the dollar, dirty. Pherris on the crew
halves the cop and the tag, which is the first time she is worth her
wage to a player who lifts.

What walked out did not move: the boost profile's `take` is $707 across
the same four seeds before and after. What came back did: net worth
29% of a month of shifts to 3%, and the profile that only lifts now
misses rent and is out of the room half the time. A thirty-day probe
lifting once a day with no rent fenced $903 with five losses. That is a
managed decision: the player decides how much heat to carry into the
meet, whether to stack three things on the board, whether to recruit
Pherris before or after. It is also a large nerf to a path that was
already a third of a job, and the honest reading is that the Lift is
now an early-game supplement and a mid-game supply for a player with
Pherris and low heat, not a living. If the owner wants it to be a
living, the rate is one constant (`FENCE_RATE`) and the corridor note
records what it measured at sixty.

### 6. Does Curtis contesting blocks create tension?

It creates a fight and a night.

The fight: TAKE IT on a Curtis block opens the confrontation with the
odds on the button, and the odds are the block's value against the
player's crew and kit, discounted by how aware Curtis is. RUN is
guaranteed and costs a mark on his ledger, so the player who looks and
leaves is remembered. A win is the block and a live front and a
retaliation in the queue; a loss is no block and his awareness up. That
is the contest the Godfather doc's 5.2 has wanted since FS-002.3 filed
it as classification.

The night: every SETTLE he tests what looks weak. An undefended corner
one time in seven, a defended one one in twenty, a live front every
other night. A block that fails is his by morning and the crew texts
you, in their own voice, that it is gone. The tension is that a player
with three corners and two soldiers has to choose which corner sleeps
uncovered, and the Turf screen already shows where soldiers stand.

What the measurement says: the stickup profiles, which pump Curtis's
awareness without ever building crew, now die at his door in the ending
PR, and the corner profiles that claim by hand hold their neutral
corners fine. No profile in the driver fights him, because a fight is a
roll and the driver does not gamble, so the contest's actual win rate in
play is unmeasured. That is the first thing a playtest should report.

### 7. Does traveling between districts feel like going somewhere now? What worked and what didn't?

Worked: the ride card and the accent. Every trip is a sheet with the
mode, a line written for that district and that mode, the district's
banner, and STEP OFF or PARK. Every screen's location label wears the
district's colour and says what kind of place it is (the neighbourhood,
the money, the yard, the Drive) instead of a state name. The first
arrival anywhere is still its own sheet from 0.9.0. Together they make
the district a place you are in rather than a tab you are on.

Did not work yet: there are no images. Every banner slot renders as
nothing, so the ride card is text and a colour until the files in
`docs/ASSET_CHECKLIST.md` exist. The build was made to render without
them and it does, but "going somewhere" is mostly a picture, and the
picture is not there. The second gap is that nothing happens on the
ride: no stop, no seatmate, no line from the driver. The ride is a card
with one button, and it should be the place a wander card can fire at a
low rate, on the deck the game already has.

### 8. What is still missing before this game could be shown to someone outside the development team?

In the order it would be noticed:

- **Every image.** Thirty-three files in `docs/ASSET_CHECKLIST.md`. The
  faces first: People, the Phone and the encounter sheet have a hole
  where a person should be.
- **Sound.** None. A phone buzz, a door, the People Mover, the beater not
  turning over.
- **The first ten minutes.** The opening is a name and a wallet. There is
  no sheet that says what the four slots are, what Yalonda wants, what
  the Phone is for. The game teaches by feed line, and a new player does
  not read the feed yet.
- **The middle.** Days one through seven are dense and the ending is
  dense; days ten through twenty-five are the same four slots. Mountain
  View has no lens NPC. The Nile, Humpy's and the Wash & Go have venues
  in the asset list and no screen.
- **Balance against real hands.** Every corridor is measured against a
  driver that does not gamble, does not read texts and does not recruit
  unless told to. The stickup door at eight days, the Lift at three
  percent and the Curtis fight's win rate all need a person.
- **Cuts the review already asked for.** The 907List's execution modes;
  soldiers folded into crew. Both are subtractions that make the Turf
  and List screens smaller.
- **A save slot the player can see.** One save, autosaved, no CONTINUE
  that says when it was.

### 9. Back of the box

_907Hustle._ It is fourteen below in Spenard and the rent is due Friday.
You have four slots a day, a roommate who vouched for you, a landlord
who does not do swearing, and a phone that buzzes when somebody wants
something. Work the Night Owl counter and get a title. Walk the block and
meet the man at the ice machine. Lift a coat from Northern Value and
find out who buys coats. Put somebody on a corner and find out who wants
it back. Every person you meet keeps a ledger on you, and the name you
earn is the sum of what they wrote down: Nobody, New Face, Known,
Player, Connected, Boss. There is a way out, and it costs what you
built. There are three ways it ends on you, and each one warns you
first. One good run, in a city that remembers.

## What was not built, and why

- **Vehicle encounters and plates as a mechanic.** BLOCK_REMEMBERS_REVIEW
  §7 named them; the deck can take them; the build spent its cards on the
  knife and the piece. A wander card with `has_vehicle` is the seam.
- **Per-weapon beat copy.** The result headline knows the tier; the beat
  does not know the weapon. A table row.
- **The road not taken on the reckoning.** Rank against six, corners
  against twelve. A table read.
- **A contest win rate.** The driver does not gamble. A playtest number.
