# The World Speaks — the build, and the six questions

_Written 2026-09-03 at the close of 0.8.0, against `907Hustle_Build_Prompt_v2.md`.
Companion to `docs/VISION_REVIEW.md` (0.7.0). Rulings are D-26 in
`docs/DECISIONS.md`._

## What shipped, in one paragraph each

**PR 1 — the city reveals itself.** Nothing criminal is on the board on day
one. The Market arrives through Goodie on the corner from day two; the
Lift through the first loose rack from day three; the stickup through a
broke afternoon or a kid at an ATM from day five; the 907List through
somebody who trusts you mentioning it. The run starts knowing one place
that hires — the Wash & Go, because Yalonda said so — and finds the rest
by walking. `hustles_discovered` (save v26) is the latch.

**PR 2 — every card earns its slot.** Seven verbs on every road in the
game: FIGHT, RUN, TALK, PAY, SURRENDER, BLUFF, COMPLY. The situation moved
to the line under the verb. The roster is keyed to when: Week Zero,
Getting Known, Reputation, Weight. One slot-filler cut, three cards
rewritten to answer who and why, nine new cards on their days.

**PR 3 — the player speaks.** Two answers on every text from a named NPC,
in the player's own thumb-typed voice. The NPC hears it and answers back
once. Silence for a day is a ghost, and the people who notice, notice.
`phone_reply_history` (save v27) is the memory.

**PR 4 — the managers have names.** Lani, Marcus, Mina, Sonny, Denise,
Ray, Big Mike. A hire is a sheet in their voice. The floor has something
happen every three or four shifts. Nights at the Chevron pay extra; the
Night Owl pays its regular. A missed shift is a text from whoever runs the
place. Being let go is a sheet and a last text. The pay bands were re-cut
so the four starters differ.

**PR 5 — the writing pass.** Feed lines are fragments of experience,
not system messages. The board explains itself when it moves hard, in one
of eighteen Anchorage lines. Yalonda's welcome is four lines and her terms
are the first text on the phone. Home's product snapshot reads the live
route instead of the mockup's claim. PR #107's Dre voice is folded in
under the universal verbs.

## The six questions

### 1. Does discovery pacing feel right, or does it delay the fun too long?

It is right for the first three days and one day slow after that.

A player who walks on day one meets the three on the wall, a bus shelter,
a Chevron sign, and the desperate approach. That is enough to feel that the
city has people in it and none of it is a menu. Goodie on day two is the
first real choice, and it is a good first choice because the thing he
offers is small and the reason to take it (rent, seven days out) is
already on the phone.

The wait for the stickup is the one to watch. Five days and under thirty
dollars is a conjunction a careful player never hits — they took the Wash &
Go, they are at fifty dollars, they are never "broke" — and the witness
version needs Spenard after dark. In playtest terms that is a path some
runs will not find in a week. **Recommendation:** keep the day-five floor,
drop the cash condition to under sixty, and let the witness card fire in
any evening slot, not only Spenard. The latch stays; the door widens.

The 907List mention at Warm is the other soft spot: Warm needs a handful
of observations, and a player who has not answered any texts or worked the
Night Owl can sit at Neutral for a week. PR 3 helps (answering Mina is a
point) and PR 4 helps (a Night Owl shift is half a point). Measure again
after both have been played.

### 2. Do simplified roads make encounters clearer, or strip too much flavor?

Clearer, and the flavor moved rather than vanished.

Before, a shakedown's roads read "Stand your ground / Hand it over / Talk
your way out" and the player had to decode which was the fight. Now the
button says FIGHT and the line under it says what fighting means here
("They're kids. That's the problem."). The flavor is in that line and in
the result, which 0.7.0 already authored per road. What was lost is the
occasional road label that was a joke or a specific ("Roll slow"). The
confrontation suite sweeps every road for a verb and a real line under it,
so the floor holds; the risk is authors writing thin under-lines, and the
suite cannot measure thinness.

One honest gap: the stickup room keeps PRESS / WATCH THE ROOM / TAKE AND
GO, because those are the robbery's actions, not a confrontation's roads.
That is the right call and it is documented, but it is the one place the
seven-verb promise is visibly not kept. If it reads as inconsistent in
play, the fix is to relabel them TALK / BLUFF / RUN and keep the copy.

### 3. Which NPC reply dynamics feel best?

Dre, then Mina, then the managers.

Dre's texts already had stakes (a due date), so answering them has weight
without the game adding any: "say less. ill have it" and Dre's "Good. I
like a man who answers" is the exchange the whole feature was built for.
Ghosting Dre and having his next text open with "You went quiet on me.
Don't." is the best single beat in the build.

Mina works because her voice is short and the answers are short, and
because the counter offer is a real decision the reply can carry. The
managers work in the missed-shift case and are flat in the default case,
because a default reply pair to a settlement text from Pherris is filler.
**Recommendation for the next pass:** author replies per text, not per
NPC, for the crew operation texts — those are the ones still using
defaults — or leave them with no reply, which the seam already supports.

The one dynamic that does not land yet: distance (B) is neutral for almost
everybody, so it reads as the safe button rather than a choice. Making B
cost half a point with Dre and Mina specifically — the people for whom
distance is a message — would give it teeth. Not done here because it
changes the exposure economy and the prompt said not to.

### 4. Is the jobs system worth deepening further, or is this enough?

This is enough for the jobs system as a *place*. It is not enough for the
jobs system as a *ladder*, and the ladder is the wrong thing to build next.

What PR 4 bought: a job is now somebody, and the feed on a shift day has a
face in it. The micro-events are the cheapest content in the build per
minute of play — one line every three or four shifts — and they are doing
most of the work. Lani's plate, Marcus's ten-short, Denise's rotisserie
coupon.

What it did not buy: a reason to *choose* a job. Pay differs now, but the
choice is still made once and forgotten. Coworkers, shift dialogue, the
"learn the job" approach paying out something specific — the web build had
all three and this port has none. **Recommendation:** do not deepen. The
jobs are the honest floor and they read as one now. Every hour spent here
is an hour not spent on the thing the vision doc is actually about, which
is the crew.

### 5. What is the biggest remaining gap versus the vision?

The crew is still a payroll line.

The vision doc's second section is Godfather 2: a crew you build, that has
faces, that you send to do things and that comes back with stories. What
the game has is a roster with loyalty numbers, three operations that pay
out on a timer, and texts that are one sentence long. The World Speaks
gave every *NPC* a voice and left the crew's voice at "I been watching how
you move product." Eli, Deshawn, Pherris and Tone are the four people the
player should know best by day twenty, and they are the four with the
least written for them.

The concrete shape of the gap: there is no moment where a crew member does
something the player did not order. No Tone showing up at a confrontation
uninvited, no Deshawn talking a corner down before the player gets there,
no Pherris bringing a buyer the player did not ask for. The wander cards
have the crew calls (TONE / DESHAWN as roads) and those are the right seam;
what is missing is the crew *initiating*.

### 6. Which systems should be cut or simplified?

Three candidates, in order of confidence.

**Cut: the `route` field on the product table.** It was a mockup string
the economy never honoured ("+$127 Downtown"). Home read it as fact until
this build. It is dead now and should be deleted from `gs.products` with
the next schema touch, along with `hint`, `trend` and `hint_color`, which
are the same kind of authored claim.

**Simplify: the job approaches.** Four approaches (work hard, socialize,
take it easy, learn the job) where two would do. Socialize and learn the
job differ by half a point of XP and nothing the player can see. Either
give each one a manager line — Marcus reacting to "socialize" is a joke
that writes itself — or fold them to WORK HARD / TAKE IT EASY.

**Simplify: the breadcrumb ramp for job discovery.** Four escalating "you
found nothing" lines exist to make a seeded discovery ramp feel fair. With
PR 1 the ramp is the only way to find five of eight jobs, which means a
player can walk four times and read four consolation prizes. Either the
ramp should be steeper (two walks, not four) or the breadcrumbs should
name the place ("the dock gate was open" → "Ship Creek is hiring, go at
six").

## What was not built, and why

- **The witness card fires only in Spenard.** Left as authored because
  the prompt named Spenard; see question 1.
- **Reply B costs nothing almost everywhere.** See question 3; it is an
  exposure-economy change and the prompt drew that line.
- **The stickup room's own verbs.** See question 2.
- **Feed lines that carry numbers inside a format string** (the stickup
  room's "+$%d, heat +%.1f" family) were left as they are: they are the
  one place the number *is* the experience, and rewriting them as prose
  would hide the thing the player is checking.
