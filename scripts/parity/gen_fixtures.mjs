#!/usr/bin/env node
// Phase 5 parity harness — fixture generator.
//
// Runs the WEB ORACLE (read-only; never edit it from here) and records what its
// deterministic primitives actually produce, so the Godot side can be compared
// against recorded truth instead of against a re-implementation's opinion of
// itself. Fixtures are committed; CI replays only the Godot half, so the
// oracle checkout is never needed in CI.
//
// Usage:
//   node scripts/parity/gen_fixtures.mjs [path-to-web-oracle]
// Default oracle path is the sibling checkout used throughout the migration.
//
// Regenerate whenever the oracle version bumps, and commit the diff — a fixture
// change without an oracle version change is a red flag, not noise.

import { createRequire } from "node:module";
import { writeFileSync, mkdirSync } from "node:fs";
import { resolve, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const oraclePath = resolve(
  process.argv[2] ?? "/Users/damusthadon/Documents/907HustleGame/907Hustle-game"
);
const require = createRequire(join(oraclePath, "package.json"));
const { stringHash, HASH_CEILING } = require(join(oraclePath, "src/hash.js"));
const Random = require(join(oraclePath, "src/events/random.js"));
const { normalizeSeed, makeRandom } = Random;
const core = require(join(oraclePath, "game-core.js"));

// ---------------------------------------------------------------------------
// stringHash — including both normalisations the game derives from it.
// Keys mirror the shapes the game actually hashes, plus edge cases: empty,
// unicode (BMP), and one astral character to pin the charCodeAt surrogate
// quirk the Godot port reproduces on purpose.
const HASH_KEYS = [
  "", "a", "907hustle", "907hustle:market_evolve_day1_slot0_weed",
  "907hustle:market_evolve_day14_slot2_meth",
  "12345:meetup:3:1:0", "seed:shark:default:nora:day4",
  "Curtis Foyer", "Yalonda Hernandez", "north_star_lot|financial|rent_paid",
  "wash_go:day7:slot2", "0", "1", "-1", " spaces around ",
  "long:".repeat(40) + "tail",
  "midpoint·dot", "dash–em—dash", "café",
  "emoji\u{1F3B2}roll", // astral: JS hashes the high surrogate D83C
];
const hashes = HASH_KEYS.map((key) => ({
  key,
  hash: stringHash(key),
  unit: stringHash(key) / HASH_CEILING,
  unit10k: (stringHash(key) % 10000) / 10000,
}));

// ---------------------------------------------------------------------------
// normalizeSeed — the coercions a seed actually meets: numeric strings, the
// run's non-numeric string seed (→ fallback), negatives (ToUint32 wrap),
// floats (truncate), zero (→ fallback), huge values (mod 2^32).
const SEED_CASES = [
  907, 0x9072026, "907hustle", "12345", "", "  ", 0, -1, -907.75,
  4294967296, 4294967297, 1e12, 3.99, "3.99", true,
];
const seeds = SEED_CASES.map((value) => ({
  input: value,
  normalized: normalizeSeed(value),
}));

// ---------------------------------------------------------------------------
// xorshift32 streams — mixed next()/int()/pick() draw sequences with the state
// cursor recorded after every draw, because stream parity is about ORDER, not
// just values. Seeds cover: plain, fallback-via-string, wrap-via-negative.
function recordStream(seed, script) {
  const random = makeRandom(seed);
  const draws = [];
  for (const step of script) {
    if (step.op === "next") {
      draws.push({ op: "next", value: random.next(), state: random.state });
    } else if (step.op === "int") {
      draws.push({
        op: "int", min: step.min, max: step.max,
        value: random.int(step.min, step.max), state: random.state,
      });
    } else if (step.op === "pick") {
      draws.push({
        op: "pick", items: step.items,
        value: random.pick(step.items), state: random.state,
      });
    }
  }
  return { seed, normalized: normalizeSeed(seed), draws };
}
const MIXED_SCRIPT = [
  { op: "next" }, { op: "next" }, { op: "int", min: 0, max: 9 },
  { op: "next" }, { op: "int", min: 40, max: 80 }, { op: "int", min: 1, max: 1 },
  { op: "pick", items: ["a", "b", "c", "d", "e"] }, { op: "next" },
  { op: "int", min: -3, max: 3 }, { op: "next" },
];
const LONG_SCRIPT = Array.from({ length: 64 }, () => ({ op: "next" }));
const streams = [
  recordStream(907, MIXED_SCRIPT),
  recordStream(0x9072026, MIXED_SCRIPT),
  recordStream("907hustle", MIXED_SCRIPT), // non-numeric → fallback seed
  recordStream(-1, MIXED_SCRIPT),          // ToUint32 wrap → 4294967295
  recordStream(1755657600000, LONG_SCRIPT), // Date.now()-shaped seed
];

// ---------------------------------------------------------------------------
// marketPrice — canon's mean-reversion walk, recorded per product per area as
// a sequence driven by one stream in canon's own consumption order. These
// fixtures are AHEAD of the Godot port (build Phase 5 part 2): the runner
// reports them as pending rather than failing until economy.gd speaks canon.
//
// game-core does NOT export marketPrice, so the formula is copied here from
// game-core.js:1331 — and then PROVEN against the oracle below: the generator
// replays initialMarket (game-core.js:1323) with this copy against a scanned
// stream offset and requires it to reproduce createRun's actual market, every
// price and every availability, before any fixture is written. A wrong copy
// cannot pass that for 3 areas x 8 products.
const PRODUCTS = core.PRODUCTS;
const AREAS = core.NEIGHBORHOODS.filter((area) =>
  ["north_star_lot", "downtown", "airport_industrial"].includes(area.id)
);
const clamp = (value, min, max) => Math.min(Math.max(value, min), max);
function marketPriceCopy(product, area, random, previous) {
  const anchor = product.base * (area.bias[product.id] || 1);
  const prior = Number(previous) || anchor;
  const reversion = prior + (anchor - prior) * 0.34;
  const movement = 1 + (random.next() * 2 - 1) * product.volatility;
  return Math.round(clamp(reversion * movement, product.min * 0.72, product.max * 1.2));
}
// initialMarket structure, verbatim (game-core.js:1323-1329): price draw,
// availability gate draw, quantity draw int(4, Outer?12:9) when the gate holds.
function replayInitialArea(area, random) {
  const prices = {}, availability = {};
  for (const product of PRODUCTS) {
    prices[product.id] = marketPriceCopy(product, area, random, null);
    availability[product.id] = random.next() <= area.availability[product.id]
      ? random.int(4, area.role === "Outer" ? 12 : 9) : 0;
  }
  return { prices, availability };
}
// evolveMarkets structure, verbatim (game-core.js:4483-4495): price walked
// from the previous price, then the gate + int(3, Outer?13:9). Event
// modifiers and dealerSupplyFactor are identity in the scenarios recorded
// (no events, no dealers on a fresh run).
function replayEvolveArea(area, random, previousPrices) {
  const prices = {}, availability = {};
  for (const product of PRODUCTS) {
    prices[product.id] = marketPriceCopy(product, area, random, previousPrices[product.id]);
    availability[product.id] = random.next() <= area.availability[product.id]
      ? random.int(3, area.role === "Outer" ? 13 : 9) : 0;
  }
  return { prices, availability };
}

function verifyMarketPriceCopy() {
  const seed = 907;
  const reference = core.createRun({ seed });
  for (let burn = 0; burn < 2000; burn += 1) {
    const random = makeRandom(seed);
    for (let i = 0; i < burn; i += 1) random.next();
    let match = true;
    for (const area of AREAS) {
      const oracle = reference.world.markets[area.id];
      const replayed = replayInitialArea(area, random);
      for (const product of PRODUCTS) {
        if (replayed.prices[product.id] !== oracle.prices[product.id]
          || replayed.availability[product.id] !== oracle.availability[product.id]) {
          match = false;
          break;
        }
      }
      if (!match) break;
    }
    if (match) return burn;
  }
  throw new Error(
    "marketPrice copy failed oracle verification: no stream offset reproduces createRun's market"
  );
}
const verifiedAtBurn = verifyMarketPriceCopy();

// The evolve copy is proven the same way, against a REAL day-end: drive the
// reducer through a full day to CONFIRM_END_DAY, then require the copy to
// reproduce the entire evolved market (every area, every price, every
// availability) from some offset of the pre-settlement stream cursor. The
// settlement draws before evolveMarkets (Curtis, exposure, soldiers) are
// whatever the burn absorbs; evolveMarkets itself is one contiguous block.
function verifyEvolveCopy() {
  let state = core.createRun({ seed: 907 });
  state = core.reduceGame(state, { type: "START_RUN", streetName: "Parity" }) || state;
  for (let guard = 0; guard < 24 && !state.run.dayEndPending; guard += 1) {
    // Story cards block advanceRun until resolved; take every first choice.
    if (state.run.pendingEvent) {
      state = core.reduceGame(state, { type: "RESOLVE_EVENT", choiceIndex: 0 }) || state;
      continue;
    }
    state = core.advanceRun(state, { reason: "REST" });
  }
  if (!state.run.dayEndPending) throw new Error("could not reach dayEndPending");
  const beforePrices = {}, cursor = state.run.rngState;
  for (const area of AREAS) beforePrices[area.id] = { ...state.world.markets[area.id].prices };
  const after = core.reduceGame(state, { type: "CONFIRM_END_DAY" });
  for (let burn = 0; burn < 5000; burn += 1) {
    const random = makeRandom(cursor);
    for (let i = 0; i < burn; i += 1) random.next();
    let match = true;
    for (const area of AREAS) {
      const oracle = after.world.markets[area.id];
      const replayed = replayEvolveArea(area, random, beforePrices[area.id]);
      for (const product of PRODUCTS) {
        if (replayed.prices[product.id] !== oracle.prices[product.id]
          || replayed.availability[product.id] !== oracle.availability[product.id]) {
          match = false;
          break;
        }
      }
      if (!match) break;
    }
    if (match) return burn;
  }
  throw new Error(
    "evolve copy failed oracle verification: no stream offset reproduces the day-end market"
  );
}
const evolveVerifiedAtBurn = verifyEvolveCopy();

// Walk fixtures mirror the Godot market lifecycle exactly: one stream, an
// initial frame (canon initialMarket), then N nightly evolve frames. The
// runner replays these through economy.gd's own walk statics.
function recordLifecycle(seedValue, evolveSteps) {
  const random = makeRandom(seedValue);
  const out = { seed: seedValue, normalized: normalizeSeed(seedValue), frames: [] };
  const current = {};
  const initialFrame = { kind: "initial", areas: {} };
  for (const area of AREAS) {
    const walked = replayInitialArea(area, random);
    current[area.id] = walked.prices;
    initialFrame.areas[area.id] = walked;
  }
  initialFrame.state = random.state;
  out.frames.push(initialFrame);
  for (let step = 0; step < evolveSteps; step += 1) {
    const frame = { kind: "evolve", areas: {} };
    for (const area of AREAS) {
      const walked = replayEvolveArea(area, random, current[area.id]);
      current[area.id] = walked.prices;
      frame.areas[area.id] = walked;
    }
    frame.state = random.state;
    out.frames.push(frame);
  }
  return out;
}
const market_walks = [recordLifecycle(907, 6), recordLifecycle("907hustle", 6)];

// PURE oracle, no copies anywhere: createRun's actual opening market + the
// cursor it leaves behind, for the seeds the Godot build actually uses. The
// runner drives GameState.init_markets() and requires identity.
function recordInitialMarket(seedValue) {
  const run = core.createRun({ seed: seedValue });
  const areas = {};
  for (const area of AREAS) {
    areas[area.id] = {
      prices: { ...run.world.markets[area.id].prices },
      availability: { ...run.world.markets[area.id].availability },
    };
  }
  return { seed: seedValue, rng_state: run.run.rngState, areas };
}
const initial_markets = [recordInitialMarket(907), recordInitialMarket("907hustle")];
// The static tables the walk depends on, for a data-parity check: the Godot
// side asserts its hand-copied bias/availability/volatility tables equal what
// the oracle actually carries, so a transcription typo cannot hide behind a
// correct formula.
const market_static = {
  products: PRODUCTS.map((p) => ({
    id: p.id, base: p.base, min: p.min, max: p.max, volatility: p.volatility,
  })),
  areas: AREAS.map((a) => ({ id: a.id, role: a.role, bias: a.bias, availability: a.availability })),
};

// ---------------------------------------------------------------------------
// Phone — the bill clock, the deferred restoration, and the inbox.
//
// Everything below is driven through EXPORTED oracle surfaces (createRun,
// reduceGame, advanceRun) and records what canon's own reducer did. Nothing
// here re-implements phone logic; the one small copy — the message id format —
// is proven against a real message the oracle produced before it is used.
const PHONE_BILL = core.PHONE_BILL;
const snapshotPhone = (state) => ({
  active: state.phone.active,
  bill_due_day: state.phone.billDueDay,
  days_past_due: state.phone.daysPastDue,
  // Canon carries null for "nothing scheduled"; the Godot side carries -1.
  reactivate_at_slot: state.phone.reactivateAtSlot == null ? -1 : state.phone.reactivateAtSlot,
  inbox: state.phone.inbox.map((m) => m.id),
  held: state.phone.heldInbox.map((m) => m.id),
});
function driveToDayEnd(state) {
  for (let guard = 0; guard < 30 && !state.run.dayEndPending; guard += 1) {
    if (state.run.pendingEvent) {
      state = core.reduceGame(state, { type: "RESOLVE_EVENT", choiceIndex: 0 }) || state;
      continue;
    }
    state = core.advanceRun(state, { reason: "REST" });
  }
  if (!state.run.dayEndPending) throw new Error("phone: could not reach dayEndPending");
  return core.reduceGame(state, { type: "CONFIRM_END_DAY" }) || state;
}
function freshRun(seed) {
  const run = core.createRun({ seed });
  return core.reduceGame(run, { type: "START_RUN", streetName: "Parity" }) || run;
}

// (a) The bill clock, unpaid, day by day. This is the fixture that pins the
// grace arithmetic: due day 7, the counter starts the morning after the day
// that ENDED on the due date, and the line dies once it exceeds two days.
function recordPhoneClock(days) {
  let state = freshRun(907);
  const frames = [{ day: state.run.day, slot: state.run.slot, phone: snapshotPhone(state) }];
  for (let i = 0; i < days; i += 1) {
    state = driveToDayEnd(state);
    frames.push({ day: state.run.day, slot: state.run.slot, phone: snapshotPhone(state) });
  }
  return { bill: PHONE_BILL, frames };
}

// (b) Paying a dead line, and the beat before it comes back. Canon stamps
// reactivateAtSlot and leaves `active` false; the NEXT advance flips it.
function recordPhoneRestore() {
  let state = freshRun(907);
  for (let i = 0; i < 12; i += 1) state = driveToDayEnd(state);
  if (state.phone.active) throw new Error("phone: line did not die in 12 days");
  const steps = [];
  const mark = (label) => steps.push({
    label, day: state.run.day, slot: state.run.slot,
    cash: state.player.cash, phone: snapshotPhone(state),
  });
  mark("offline");
  state = core.reduceGame(state, { type: "PAY_PHONE_BILL", surface: "store" }) || state;
  mark("paid");
  if (state.run.pendingEvent) state = core.reduceGame(state, { type: "RESOLVE_EVENT", choiceIndex: 0 }) || state;
  state = core.advanceRun(state, { reason: "REST" });
  mark("advanced");
  return { steps };
}

// (c) A real message out of the oracle, used to PROVE the id-format copy.
// game-core does not export pushPhoneMessage, so the Godot port builds the id
// from the format at game-core.js:735 — `day:slot:stringHash(from:text)`. The
// generator recomputes that format from the exported stringHash and requires
// it to equal the id canon actually minted on a message the reducer produced
// (a job offer, three EXPLORE_SPENARD calls and an APPLY_JOB later). A wrong
// format cannot pass that.
function recordPhoneMessage() {
  let state = freshRun(907);
  const step = (action) => {
    state = core.reduceGame(state, action) || state;
    if (state.run.pendingEvent) state = core.reduceGame(state, { type: "RESOLVE_EVENT", choiceIndex: 0 }) || state;
  };
  for (let i = 0; i < 3; i += 1) step({ type: "EXPLORE_SPENARD" });
  const jobId = state.jobs.discovered.find((id) => id !== "day_labor");
  if (!jobId) throw new Error("phone: no non-day-labor job discovered to apply to");
  step({ type: "APPLY_JOB", jobId });
  for (let guard = 0; guard < 8 && !state.phone.inbox.length; guard += 1) {
    if (state.run.dayEndPending) { state = core.reduceGame(state, { type: "CONFIRM_END_DAY" }) || state; continue; }
    if (state.run.pendingEvent) { state = core.reduceGame(state, { type: "RESOLVE_EVENT", choiceIndex: 0 }) || state; continue; }
    state = core.advanceRun(state, { reason: "REST" });
  }
  const message = state.phone.inbox[0];
  if (!message) throw new Error("phone: no message ever reached the inbox");
  const rebuilt = `${message.day}:${message.slot}:${stringHash(`${message.from}:${message.text}`)}`;
  if (rebuilt !== message.id) {
    throw new Error(`phone: id-format copy failed oracle verification (${rebuilt} != ${message.id})`);
  }
  // The dismiss/clear reducers, run against that real inbox.
  const afterDismiss = core.reduceGame(state, { type: "DISMISS_PHONE_MESSAGE", id: message.id });
  const afterClear = core.reduceGame(state, { type: "CLEAR_PHONE_INBOX" });
  return {
    message: {
      id: message.id, from: message.from, text: message.text,
      day: message.day, slot: message.slot, read: message.read,
    },
    inbox_before: state.phone.inbox.map((m) => m.id),
    after_dismiss: (afterDismiss || state).phone.inbox.map((m) => m.id),
    after_clear: (afterClear || state).phone.inbox.map((m) => m.id),
  };
}

// (d) The held-inbox flush, and its ORDER. Canon holds a message sent to a dead
// line and, on restoration, prepends `[...heldInbox.reverse(), ...inbox]` — so
// the newest held text lands on top. Nothing in a fresh run pushes to a dead
// line (job offers require service), so the held stack is seeded by hand and
// canon's own restorePhoneIfReady, reached through advanceRun, does the work.
// The logic under test is entirely the oracle's; only the input is supplied.
function recordHeldFlush() {
  let state = freshRun(907);
  for (let i = 0; i < 12; i += 1) state = driveToDayEnd(state);
  if (state.phone.active) throw new Error("phone: line did not die in 12 days");
  const held = ["held-1", "held-2", "held-3"].map((id, index) => ({
    id, from: `Sender ${index}`, text: `Held text ${index}`,
    day: state.run.day, slot: state.run.slot, read: false,
  }));
  state.phone.inbox = [{ id: "live-1", from: "Live", text: "Live text", day: state.run.day, slot: state.run.slot, read: false }];
  state.phone.heldInbox = held.map((item) => ({ ...item }));
  const before = snapshotPhone(state);
  const at = { day: state.run.day, slot: state.run.slot };
  state = core.reduceGame(state, { type: "PAY_PHONE_BILL", surface: "store" }) || state;
  if (state.run.pendingEvent) state = core.reduceGame(state, { type: "RESOLVE_EVENT", choiceIndex: 0 }) || state;
  state = core.advanceRun(state, { reason: "REST" });
  return { at, before, after: snapshotPhone(state) };
}

// (e) PHONE_INTEL, pure exported oracle data: the Word Around Town pool for
// every area and every slot. The Godot side rebuilds these from the same six
// templates and must land on the identical strings.
const phone_intel = core.NEIGHBORHOODS
  .filter((area) => ["north_star_lot", "downtown", "airport_industrial"].includes(area.id))
  .map((area) => ({ area: area.id, slots: core.PHONE_INTEL[area.id] }));

const phone = {
  bill: PHONE_BILL,
  clock: recordPhoneClock(12),
  restore: recordPhoneRestore(),
  message: recordPhoneMessage(),
  held_flush: recordHeldFlush(),
  intel: phone_intel,
};

// ---------------------------------------------------------------------------
// Attributes — PURE oracle, no copies anywhere.
//
// `attributeSystem` and the `ATTRIBUTES` data module are both exported, so
// every value below is produced by canon's own functions called directly. There
// is no formula copy here to prove, which is the strongest parity position the
// harness has had: the Godot side simply has to agree with the oracle's output.
const A = core.attributeSystem;
const AD = core.ATTRIBUTES;

// A state shaped the way normalizedAttributes reads it. Only player.attributes
// is consulted, so this is the whole surface.
const attrState = (combat, charisma, intelligence) => ({
  player: { attributes: { combat, charisma, intelligence } },
});

// (a) The compatibility scale — the offset this port got wrong from Phase 3d
// until 5c. Every stored value across the clamp range, and the compat value
// canon derives from it.
const attribute_compat = [];
for (let v = -2; v <= 14; v += 1) {
  const state = attrState(v, v, v);
  attribute_compat.push({
    stored: v,
    normalized: A.normalizedAttributes(state).combat,
    compat: A.compatibilityRating(state, "combat"),
    label: A.attributeLabel(A.normalizedAttributes(state).combat),
  });
}
// Non-integer and missing values, because a hand-edited save can carry them.
const attribute_normalize_edge = [
  { input: 2.7, normalized: A.normalizedAttributes(attrState(2.7, 1, 1)).combat },
  { input: -0.5, normalized: A.normalizedAttributes(attrState(-0.5, 1, 1)).combat },
  { input: 99, normalized: A.normalizedAttributes(attrState(99, 1, 1)).combat },
  { input: null, normalized: A.normalizedAttributes({ player: { attributes: {} } }).combat },
];

// (b) The label tiers, read straight off canon's own function.
const attribute_labels = [];
for (let v = 0; v <= 12; v += 1) attribute_labels.push({ value: v, label: A.attributeLabel(v) });

// (c) Growth — the log2 taper, and the cap penalty that kicks in at Dangerous.
// Recorded per activity across a session range so a wrong base rate, a wrong
// diminishing curve and a wrong cap floor each fail distinctly.
const attribute_growth = [];
for (const activity of Object.keys(AD.GROWTH_RATES)) {
  for (const sessions of [0, 1, 2, 3, 7, 15, 40]) {
    for (const current of [0, 1, 5, 6, 8]) {
      attribute_growth.push({
        activity, sessions, current,
        attribute: A.growthAttribute(activity),
        growth: A.attributeGrowth(current, sessions, activity),
      });
    }
  }
}
// An unknown source trains nothing and names nothing — canon's loud failure.
const attribute_growth_unknown = {
  growth: A.attributeGrowth(1, 0, "not_a_real_activity"),
  attribute: A.growthAttribute("not_a_real_activity"),
};

// (d) The three chance formulas at every compat value, computed from canon's
// own compatibilityRating. These are the call sites the pinning got wrong; the
// runner drives the real Godot systems and requires the same numbers.
const clampChance = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
const attribute_formulas = [];
for (let stored = 0; stored <= 8; stored += 1) {
  const state = attrState(stored, stored, stored);
  const combat = A.compatibilityRating(state, "combat");
  const intel = A.compatibilityRating(state, "intelligence");
  const chari = A.compatibilityRating(state, "charisma");
  attribute_formulas.push({
    stored,
    combat_compat: combat,
    intelligence_compat: intel,
    charisma_compat: chari,
    // stickChance's attribute term (game-core.js:2402), isolated.
    stick_term: (combat - 2) * 0.08,
    // boostChance's skill blends (2228-2230), isolated.
    boost_skill_low: (combat + intel) / 2,
    boost_skill_tier3: (intel + chari) / 2,
    boost_term_low: ((combat + intel) / 2 - 2) * 0.1,
    // The shark default-probability term (6560), isolated.
    shark_term: -intel * 0.025,
    // One fully-assembled example of each, so an error in how the port
    // assembles the formula cannot hide behind correct isolated terms.
    stick_tier1_clean: clampChance(0.62 + (combat - 2) * 0.08, 0.15, 0.9),
    boost_tier1: clampChance(0.8 + ((combat + intel) / 2 - 2) * 0.1, 0.1, 0.95),
  });
}

// (e) Street Identity — canon's getStreetIdentity / identityProfile, driven
// directly. The state shape they read is small: player.attributes, run.day, and
// npc.<id>.ledger, which `ledgerOf` walks. Building it by hand supplies the
// input; canon's own functions do every bit of the deriving.
const identityState = (attrs, day, ledgers) => ({
  player: { attributes: attrs },
  run: { day },
  npc: Object.fromEntries(
    core.EXPOSURE_NPC_IDS.map((id) => [id, { ledger: ledgers[id] || [] }])
  ),
});
const obs = (type, day, count = 1) => ({ type, day, count, key: `${type}:${day}`, event: "", source: "witnessed" });

// Cases chosen so each arm of the matrix and each tie rule is exercised:
// a clear lane, a lane inside the balance margin, an empty ledger, a tie
// between two behaviour columns, a count-weighted winner, and rows that have
// aged out of the 7-day window.
const IDENTITY_CASES = [
  { name: "fresh run", attrs: { combat: 1, charisma: 1, intelligence: 1 }, day: 1, ledgers: {} },
  { name: "combat lane, no behaviour", attrs: { combat: 5, charisma: 1, intelligence: 1 }, day: 10, ledgers: {} },
  { name: "combat lane, violence seen", attrs: { combat: 5, charisma: 1, intelligence: 1 }, day: 10,
    ledgers: { yalonda: [obs("violence", 9)] } },
  { name: "combat lane, presence seen", attrs: { combat: 6, charisma: 2, intelligence: 1 }, day: 10,
    ledgers: { mina: [obs("discretion", 8)] } },
  { name: "charisma lane, financial seen", attrs: { combat: 1, charisma: 6, intelligence: 2 }, day: 12,
    ledgers: { dre: [obs("financial", 11, 3)] } },
  { name: "intelligence lane, growth seen", attrs: { combat: 1, charisma: 1, intelligence: 4 }, day: 6,
    ledgers: { juan: [obs("growth", 5)] } },
  { name: "inside the balance margin", attrs: { combat: 4, charisma: 3, intelligence: 2 }, day: 8,
    ledgers: { curtis: [obs("heat_exposure", 7)] } },
  { name: "exact margin is still balanced", attrs: { combat: 4, charisma: 2, intelligence: 1 }, day: 8, ledgers: {} },
  { name: "one over the margin is a lane", attrs: { combat: 5, charisma: 2, intelligence: 1 }, day: 8, ledgers: {} },
  { name: "behaviour tie falls through to default", attrs: { combat: 6, charisma: 1, intelligence: 1 }, day: 10,
    ledgers: { yalonda: [obs("violence", 9)], mina: [obs("presence", 9)] } },
  { name: "count breaks what would be a tie", attrs: { combat: 6, charisma: 1, intelligence: 1 }, day: 10,
    ledgers: { yalonda: [obs("violence", 9, 2)], mina: [obs("presence", 9)] } },
  { name: "rows outside the window do not count", attrs: { combat: 6, charisma: 1, intelligence: 1 }, day: 20,
    ledgers: { yalonda: [obs("violence", 3)] } },
  { name: "boundary day is inside the window", attrs: { combat: 6, charisma: 1, intelligence: 1 }, day: 10,
    ledgers: { yalonda: [obs("violence", 4)] } },
  { name: "unmapped category is ignored", attrs: { combat: 6, charisma: 1, intelligence: 1 }, day: 10,
    ledgers: { yalonda: [obs("not_a_category", 9)] } },
];
const attribute_identity = IDENTITY_CASES.map((testCase) => {
  const state = identityState(testCase.attrs, testCase.day, testCase.ledgers);
  const profile = A.identityProfile(state);
  return {
    name: testCase.name,
    attrs: testCase.attrs,
    day: testCase.day,
    ledgers: testCase.ledgers,
    recent_count: A.getRecentObservations(state, AD.IDENTITY_RECENT_DAYS).length,
    dominant: profile.dominant,
    behavior: profile.behavior,
    label: profile.label,
    description: profile.description,
    identity: A.getStreetIdentity(state),
  };
});

const attributes = {
  ids: AD.ATTRIBUTE_IDS,
  identity_balance_margin: AD.IDENTITY_BALANCE_MARGIN,
  identity_recent_days: AD.IDENTITY_RECENT_DAYS,
  identity_matrix: AD.IDENTITY_MATRIX,
  identity_descriptions: AD.IDENTITY_DESCRIPTIONS,
  identity_behavior_columns: AD.IDENTITY_BEHAVIOR_COLUMNS,
  identity: attribute_identity,
  defaults: AD.ATTRIBUTE_DEFAULTS,
  min: AD.ATTRIBUTE_MIN,
  max: AD.ATTRIBUTE_MAX,
  growth_rates: AD.GROWTH_RATES,
  growth_attributes: AD.GROWTH_ATTRIBUTES,
  growth_cap_penalty_floor: AD.GROWTH_CAP_PENALTY_FLOOR,
  growth_cap_penalty: AD.GROWTH_CAP_PENALTY,
  compat: attribute_compat,
  normalize_edge: attribute_normalize_edge,
  labels: attribute_labels,
  growth: attribute_growth,
  growth_unknown: attribute_growth_unknown,
  formulas: attribute_formulas,
};

// ---------------------------------------------------------------------------
// Recovery — canon's two exported selectors, called directly.
//
// `layLowPreview` and `treatmentCost` are both on the exported `selectors`
// surface, so these are recorded rather than re-derived. The states are built
// with the base system at its neutral (no security track, not watched), which
// is what this build has: no base system at all.
const recoveryState = (heat, area = "north_star_lot") => ({
  player: { heat },
  world: { currentNeighborhoodId: area },
  base: { tracks: { security: 0, recovery: 0 }, watched: false, controlled: false },
  streetRead: null,
});
const lay_low = [];
for (const heat of [0, 0.5, 1, 1.5, 2, 2.4, 3, 7.5, 15]) {
  for (const area of ["north_star_lot", "downtown"]) {
    lay_low.push({
      heat, area,
      heat_reduction: core.selectors.layLowPreview(recoveryState(heat, area)).heatReduction,
      advances: core.selectors.layLowPreview(recoveryState(heat, area)).advances,
    });
  }
}
// treatmentCost with no Street Read: full price, which is every price here.
const treatment_costs = [55, 135, 290].map((base) => ({
  base, cost: core.selectors.treatmentCost(recoveryState(0), base),
}));

const recovery = { lay_low, treatment_costs };

// ---------------------------------------------------------------------------
const fixtures = {
  oracle_version: core.VERSION,
  generated_note: "run scripts/parity/gen_fixtures.mjs against the web oracle; do not hand-edit",
  hashes,
  seeds,
  streams,
  market_static,
  market_walks,
  initial_markets,
  phone,
  attributes,
  recovery,
};

const outPath = join(here, "..", "..", "tests", "parity", "fixtures", "rng_fixtures.json");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(fixtures, null, 1) + "\n");
console.log(
  `wrote ${outPath}: ${hashes.length} hashes, ${seeds.length} seeds, ` +
  `${streams.length} streams, ${market_walks.length} lifecycle walks, ` +
  `${initial_markets.length} oracle initial markets, ` +
  `${phone.clock.frames.length} phone clock frames, ` +
  `${attributes.growth.length} attribute growth rows, ` +
  `${attributes.identity.length} identity cases, ` +
  `${recovery.lay_low.length} lay-low rows (oracle v${core.VERSION}; ` +
  `initialMarket copy verified at offset ${verifiedAtBurn}, ` +
  `evolveMarkets copy verified at offset ${evolveVerifiedAtBurn}; ` +
  `phone message-id format verified against oracle message ${phone.message.message.id})`
);

// ---------------------------------------------------------------------------
// Build 5e — the tiered outcome resolver.
//
// Written to its OWN file (tests/parity/fixtures/outcome_resolver/) rather than
// into rng_fixtures.json, because it is a different kind of fixture: the file
// above records primitives and system reads, this one records the resolution of
// a whole action end to end. Same discipline either way — every value below
// comes out of canon's own exported functions, never re-derived here.
//
// `resolveAction` reads the attribute off state and the streak fields off
// state.player; a state with neither gymStreak nor nileStreakAttribute set
// scores both streak bonuses at 0, which is what this build has (no venues).
const R = core.attributeSystem;
const RD = core.ATTRIBUTES;
const ACTION_TYPES = Object.keys(RD.OUTCOME_SHAPES);
const CHANCE_STEPS = [0, 0.25, 0.5, 0.75, 1];

// The state shape resolveAction reads. All three attributes move together so a
// case is valid whichever attribute its action maps to.
const outcomeState = (value) => ({
  player: { attributes: { combat: value, charisma: value, intelligence: value } },
});

// (a) Pool construction. Order is recorded as well as content: seededPick walks
// cumulative weight in array order, so a pool that is right but reordered
// resolves different tiers from the same hash.
const outcome_pools = [];
for (const actionType of ACTION_TYPES) {
  for (const chance of CHANCE_STEPS) {
    const pool = R.buildOutcomePool(actionType, chance);
    outcome_pools.push({
      action_type: actionType,
      chance,
      pool: pool.map((entry) => ({ tier: entry.tier, value: entry.value, weight: entry.weight })),
      weight_total: pool.reduce((sum, entry) => sum + entry.weight, 0),
    });
  }
}
// An action type canon has never heard of yields an empty pool, and an empty
// pool is what makes resolveAction fall through to a plain failure.
const outcome_pool_unknown = {
  pool: R.buildOutcomePool("not_a_real_action", 0.5),
  resolved: R.resolveAction(outcomeState(4), "not_a_real_action", 0.5, "seed:nope"),
};

// (b) seededPick itself, on hand-built pools — including the zero-total
// fallback, which is the one branch a real chance never reaches.
const PICK_POOLS = {
  even: [{ tier: "clean", value: 3, weight: 1 }, { tier: "messy", value: 2, weight: 1 }],
  skewed: [{ tier: "clean", value: 3, weight: 0.05 }, { tier: "failure", value: 1, weight: 0.95 }],
  zeroed: [{ tier: "clean", value: 3, weight: 0 }, { tier: "messy", value: 2, weight: 0 },
    { tier: "failure", value: 1, weight: 0 }],
  single: [{ tier: "catastrophic", value: 0, weight: 0.4 }],
};
const seeded_picks = [];
for (const [poolName, pool] of Object.entries(PICK_POOLS)) {
  for (let i = 0; i < 12; i += 1) {
    const key = `907hustle:pick:${poolName}:${i}`;
    const picked = Random.seededPick(pool, key);
    seeded_picks.push({ pool: poolName, key, tier: picked ? picked.tier : null });
  }
}
// Both empty-input guards, which return null rather than throwing.
const seeded_pick_empty = {
  empty_array: Random.seededPick([], "907hustle:pick:empty"),
  not_an_array: Random.seededPick(null, "907hustle:pick:null"),
};

// (c) Resolution across the whole grid: every action type, every chance step,
// every attribute value from the floor to the ceiling. This is the check that
// pins the advantage threshold and the immunity threshold at once, because both
// are crossed inside the sweep.
const outcome_resolutions = [];
for (const actionType of ACTION_TYPES) {
  for (const chance of CHANCE_STEPS) {
    for (let value = 0; value <= 12; value += 1) {
      const context = `outcome:${actionType}:${chance}:${value}`;
      const outcome = R.resolveAction(outcomeState(value), actionType, chance, `907hustle:${context}`);
      outcome_resolutions.push({
        action_type: actionType, chance, attribute: value,
        seed: "907hustle", context,
        tier: outcome.tier, value: outcome.value,
      });
    }
  }
}

// (d) Advantage, proven rather than asserted.
//
// A sweep at Combat 2 (one roll) and the same seeds at Combat 3 (two rolls,
// better kept) over a chance where both halves are live. `upgraded` counts the
// seeds where the second look actually changed the answer - if that number is
// ever 0 the fixture has stopped testing anything, so it is recorded and
// checked rather than left implicit.
const ADVANTAGE_SWEEP = 400;
const advantage_cases = [];
let advantage_upgraded = 0;
for (let i = 0; i < ADVANTAGE_SWEEP; i += 1) {
  const context = `advantage:${i}`;
  const key = `907hustle:${context}`;
  const below = R.resolveAction(outcomeState(2), "robbery", 0.5, key);
  const at = R.resolveAction(outcomeState(3), "robbery", 0.5, key);
  if (below.tier !== at.tier) advantage_upgraded += 1;
  advantage_cases.push({
    seed: "907hustle", context,
    below_tier: below.tier, below_value: below.value,
    at_tier: at.tier, at_value: at.value,
  });
}

// (e) Catastrophe immunity. The same 1000 seeds at Combat 5 and Combat 6: the
// first must produce catastrophes, the second must produce none.
const IMMUNITY_SWEEP = 1000;
const immunity_tally = { below: {}, at: {} };
const immunity_cases = [];
for (let i = 0; i < IMMUNITY_SWEEP; i += 1) {
  const context = `immunity:${i}`;
  const key = `907hustle:${context}`;
  const below = R.resolveAction(outcomeState(5), "robbery", 0.35, key);
  const at = R.resolveAction(outcomeState(6), "robbery", 0.35, key);
  immunity_tally.below[below.tier] = (immunity_tally.below[below.tier] || 0) + 1;
  immunity_tally.at[at.tier] = (immunity_tally.at[at.tier] || 0) + 1;
  if (i < 40) {
    immunity_cases.push({
      seed: "907hustle", context, below_tier: below.tier, at_tier: at.tier,
    });
  }
}

// (f) The bonus parameter - crew backup as an effective level, re-clamped to
// the attribute ceiling. Cases straddle both thresholds (2+1 reaches advantage,
// 5+1 reaches immunity) and one that would overflow the clamp.
const BONUS_CASES = [
  { attribute: 2, bonus: 0 }, { attribute: 2, bonus: 1 },
  { attribute: 5, bonus: 0 }, { attribute: 5, bonus: 1 },
  { attribute: 0, bonus: 3 }, { attribute: 12, bonus: 4 },
  { attribute: 4, bonus: -2 },
];
const bonus_cases = [];
for (const testCase of BONUS_CASES) {
  for (let i = 0; i < 20; i += 1) {
    const context = `bonus:${testCase.attribute}:${testCase.bonus}:${i}`;
    const outcome = R.resolveAction(
      outcomeState(testCase.attribute), "robbery", 0.4, `907hustle:${context}`, testCase.bonus);
    bonus_cases.push({
      seed: "907hustle", context,
      attribute: testCase.attribute, bonus: testCase.bonus,
      tier: outcome.tier, value: outcome.value,
    });
  }
}

// (g) Determinism: the same call repeated must not drift, and the same key
// under a different seed must.
const determinism_cases = [];
for (const seed of ["907hustle", "12345", "another-run"]) {
  for (let i = 0; i < 8; i += 1) {
    const context = `determinism:${i}`;
    const first = R.resolveAction(outcomeState(4), "dealer_robbery", 0.6, `${seed}:${context}`);
    const again = R.resolveAction(outcomeState(4), "dealer_robbery", 0.6, `${seed}:${context}`);
    determinism_cases.push({
      seed, context, tier: first.tier, stable: first.tier === again.tier,
    });
  }
}

// (h) The stickup key canon actually builds, resolved at a spread of Combat
// values. This is the one that proves the Godot call site keys its roll the
// same way canon does - a right resolver on a wrong key is still a wrong game.
const stickup_keys = [];
for (const targetId of ["wash_go", "corner_store", "goodie_stash"]) {
  for (const day of [1, 4, 11]) {
    for (const slot of [0, 2]) {
      for (const value of [0, 2, 3, 5, 6, 9]) {
        const context = `stickup:${day}:${slot}:${targetId}`;
        const outcome = R.resolveAction(
          outcomeState(value), "robbery", 0.62, `907hustle:${context}`);
        stickup_keys.push({
          seed: "907hustle", context, target_id: targetId, day, slot,
          attribute: value, chance: 0.62, tier: outcome.tier, value: outcome.value,
        });
      }
    }
  }
}

// (i) isSuccessTier, across every tier plus a nonsense one.
const success_tiers = ["clean", "messy", "failure", "catastrophic", "nonsense"].map((tier) => ({
  tier, success: R.isSuccessTier(tier),
}));

const outcomeFixtures = {
  oracle_version: core.VERSION,
  generated_note: "run scripts/parity/gen_fixtures.mjs against the web oracle; do not hand-edit",
  outcome_values: RD.OUTCOME_VALUES,
  outcome_shapes: RD.OUTCOME_SHAPES,
  action_attribute_map: RD.ACTION_ATTRIBUTE_MAP,
  outcome_observations: RD.OUTCOME_OBSERVATIONS,
  advantage_threshold: RD.ADVANTAGE_THRESHOLD,
  catastrophe_immunity_threshold: RD.CATASTROPHE_IMMUNITY_THRESHOLD,
  attribute_min: RD.ATTRIBUTE_MIN,
  attribute_max: RD.ATTRIBUTE_MAX,
  pools: outcome_pools,
  pool_unknown: outcome_pool_unknown,
  picks: seeded_picks,
  pick_empty: seeded_pick_empty,
  resolutions: outcome_resolutions,
  advantage: { sweep: ADVANTAGE_SWEEP, upgraded: advantage_upgraded, cases: advantage_cases },
  immunity: { sweep: IMMUNITY_SWEEP, tally: immunity_tally, cases: immunity_cases },
  bonus: bonus_cases,
  determinism: determinism_cases,
  stickup_keys,
  success_tiers,
};

const outcomePath = join(
  here, "..", "..", "tests", "parity", "fixtures", "outcome_resolver", "outcome_fixtures.json");
mkdirSync(dirname(outcomePath), { recursive: true });
writeFileSync(outcomePath, JSON.stringify(outcomeFixtures, null, 1) + "\n");
console.log(
  `wrote ${outcomePath}: ${outcome_pools.length} pools, ${seeded_picks.length} picks, ` +
  `${outcome_resolutions.length} resolutions, ${advantage_cases.length} advantage pairs ` +
  `(${advantage_upgraded} upgraded by the second look), ` +
  `${IMMUNITY_SWEEP} immunity pairs (catastrophic at 5: ` +
  `${immunity_tally.below.catastrophic || 0}, at 6: ${immunity_tally.at.catastrophic || 0}), ` +
  `${bonus_cases.length} bonus rows, ${stickup_keys.length} stickup keys`
);

// ---------------------------------------------------------------------------
// FS-001.5 — the shared Requirement Evaluator, and the Crew rank/capability
// foundation it sits beside.
//
// These two modules arrived in web PR #98, which is one commit ahead of the
// oracle checkout's `main`. Rather than move the oracle's HEAD (this generator
// is read-only against it, and every fixture above is recorded from `main`),
// the two files are extracted to a scratch directory and required from there,
// with `requirements.js`'s one relative import repointed at the oracle's real
// `src/data/crew.js`. Nothing about the checkout changes.
//
// Regenerate with FS001_ORACLE_DIR pointing wherever the extracted pair lives:
//   git show a7d9534:src/systems/requirements.js  > $DIR/requirements.js
//   git show a7d9534:src/data/crew-progression.js > $DIR/crew-progression.js
// When PR #98 lands on the oracle's main, delete this dance and require them
// directly.
const fs001Dir = process.env.FS001_ORACLE_DIR
  ?? "/private/tmp/claude-501/-Users-damusthadon-Documents-907HustleGodot/6d9a4a40-7c5c-4e5a-ae64-894f354d24bd/scratchpad/fs001-oracle";
let Req;
let Prog;
try {
  Req = require(join(fs001Dir, "requirements.js"));
  Prog = require(join(fs001Dir, "crew-progression.js"));
} catch (error) {
  // Fail SOFT and loudly. The two fixture files above are already written by
  // this point, and losing them to an exception here would be a worse outcome
  // than skipping the section — especially since the committed
  // fs001_fixtures.json stays valid until the oracle actually changes.
  console.error(
    `\n[fs-001.5] SKIPPED: could not load the PR #98 oracle pair from ${fs001Dir}\n` +
    `  ${error.message}\n` +
    `  tests/parity/fixtures/requirements/fs001_fixtures.json was NOT regenerated.\n` +
    `  To regenerate it, extract the pair from the oracle and point FS001_ORACLE_DIR at them:\n` +
    `    git show a7d9534:src/systems/requirements.js  > $DIR/requirements.js\n` +
    `    git show a7d9534:src/data/crew-progression.js > $DIR/crew-progression.js\n` +
    `  then repoint requirements.js's one relative import at the oracle's src/data/crew.js.\n`
  );
  Req = null;
}

if (Req && Prog) {

// Infinity is a real value here — `crew_tenure_days_min` reports it for a
// record with no recruited day — and JSON.stringify flattens it to null. It is
// recorded as a tagged string instead, so the Godot side asserts INF rather
// than "some missing value".
const encode = (value) => (value === Infinity ? "@Infinity" : value);
const encodeResult = (r) => ({
  ok: r.ok,
  blocker_code: r.blocker_code ?? null,
  blocker_copy_key: r.blocker_copy_key ?? null,
  current: encode(r.current ?? null),
  required: encode(r.required ?? null),
});

// The oracle reads camelCase facts; the Godot port reads snake_case, because
// its crew records already carry `recruited_day` / `wage_missed_since`. Each
// case records BOTH shapes — same data, one translation, and the translation is
// recorded here rather than performed on the Godot side.
function godotFacts(facts) {
  const crew = {};
  for (const [id, record] of Object.entries(facts.crew || {})) {
    crew[id] = {
      recruited: record.recruited,
      status: record.status,
      loyalty: record.loyalty,
      tier: record.tier,
      recruited_day: record.recruitedDay ?? null,
      wage_missed_since: record.wageMissedSince ?? null,
      proofs: record.proofs || {},
    };
  }
  const out = { crew, current_day: facts.currentDay ?? 0 };
  if (facts.timeSlotsToday !== undefined) out.time_slots_today = facts.timeSlotsToday;
  if (facts.wageGraceDays !== undefined) out.wage_grace_days = facts.wageGraceDays;
  if (facts.hustleTiers !== undefined) out.hustle_tiers = facts.hustleTiers;
  if (facts.assignments !== undefined) out.assignments = facts.assignments;
  return out;
}

function godotRequirement(requirement) {
  if (requirement === null || typeof requirement !== "object" || Array.isArray(requirement)) {
    return requirement;
  }
  const rename = {
    crewId: "crew_id", hustleId: "hustle_id",
    blockerCode: "blocker_code", blockerCopyKey: "blocker_copy_key",
  };
  const out = {};
  for (const [key, value] of Object.entries(requirement)) out[rename[key] || key] = value;
  return out;
}

const CREW_BASE = {
  recruited: true, status: "active", loyalty: 8, tier: 2,
  recruitedDay: 1, wageMissedSince: null,
  proofs: { first_route: true, completed_routes: 4 },
};
const baseFacts = (overrides = {}, crewOverrides = {}) => ({
  currentDay: 14,
  timeSlotsToday: 0,
  wageGraceDays: 2,
  crew: { pherris: { ...CREW_BASE, ...crewOverrides } },
  hustleTiers: { "907list": 3 },
  assignments: {},
  ...overrides,
});

// Every type gets a pass, a fail, and its boundary in both directions.
const REQUIREMENT_CASES = [
  ["crew_active pass", { type: "crew_active", crewId: "pherris" }, baseFacts()],
  ["crew_active not recruited", { type: "crew_active", crewId: "pherris" }, baseFacts({}, { recruited: false })],
  ["crew_active departed", { type: "crew_active", crewId: "pherris" }, baseFacts({}, { status: "departed" })],
  ["crew_active unknown id", { type: "crew_active", crewId: "nobody" }, baseFacts()],
  ["crew_active no crew facts", { type: "crew_active", crewId: "pherris" }, { currentDay: 4 }],
  ["crew_loyalty_min exactly at min", { type: "crew_loyalty_min", crewId: "pherris", min: 8 }, baseFacts()],
  ["crew_loyalty_min one below", { type: "crew_loyalty_min", crewId: "pherris", min: 9 }, baseFacts()],
  ["crew_loyalty_min well under", { type: "crew_loyalty_min", crewId: "pherris", min: 10 }, baseFacts({}, { loyalty: 2 })],
  ["crew_loyalty_min zero min", { type: "crew_loyalty_min", crewId: "pherris" }, baseFacts({}, { loyalty: 0 })],
  ["crew_rank_min at rank", { type: "crew_rank_min", crewId: "pherris", min: 2 }, baseFacts()],
  ["crew_rank_min one above rank", { type: "crew_rank_min", crewId: "pherris", min: 3 }, baseFacts()],
  ["crew_rank_min rank 6", { type: "crew_rank_min", crewId: "pherris", min: 6 }, baseFacts({}, { tier: 6 })],
  ["crew_tenure exactly at threshold", { type: "crew_tenure_days_min", crewId: "pherris", min: 13 }, baseFacts()],
  ["crew_tenure one short", { type: "crew_tenure_days_min", crewId: "pherris", min: 14 }, baseFacts()],
  ["crew_tenure recruited today", { type: "crew_tenure_days_min", crewId: "pherris", min: 1 }, baseFacts({}, { recruitedDay: 14 })],
  ["crew_tenure missing recruited day is infinite", { type: "crew_tenure_days_min", crewId: "pherris", min: 99 }, baseFacts({}, { recruitedDay: null })],
  ["crew_tenure negative window clamps to zero", { type: "crew_tenure_days_min", crewId: "pherris", min: 1 }, baseFacts({}, { recruitedDay: 20 })],
  ["hustle_tier_min at tier", { type: "hustle_tier_min", hustleId: "907list", min: 3 }, baseFacts()],
  ["hustle_tier_min above tier", { type: "hustle_tier_min", hustleId: "907list", min: 4 }, baseFacts()],
  ["hustle_tier_min unknown hustle", { type: "hustle_tier_min", hustleId: "nope", min: 1 }, baseFacts()],
  ["hustle_tier_min no hustle facts", { type: "hustle_tier_min", hustleId: "907list", min: 1 }, { currentDay: 2 }],
  ["payroll nothing owed", { type: "payroll_not_delinquent", crewId: "pherris" }, baseFacts()],
  ["payroll within grace", { type: "payroll_not_delinquent", crewId: "pherris" }, baseFacts({}, { wageMissedSince: 12 })],
  ["payroll one past grace", { type: "payroll_not_delinquent", crewId: "pherris" }, baseFacts({}, { wageMissedSince: 11 })],
  ["payroll far past grace", { type: "payroll_not_delinquent", crewId: "pherris" }, baseFacts({}, { wageMissedSince: 4 })],
  ["payroll unknown crew", { type: "payroll_not_delinquent", crewId: "nobody" }, baseFacts()],
  ["payroll custom grace", { type: "payroll_not_delinquent", crewId: "pherris" }, baseFacts({ wageGraceDays: 5 }, { wageMissedSince: 10 })],
  ["unassigned when nothing booked", { type: "crew_unassigned_today", crewId: "pherris" }, baseFacts()],
  ["unassigned blocked by today", { type: "crew_unassigned_today", crewId: "pherris" }, baseFacts({ assignments: { pherris: { day: 14, operationId: "other" } } })],
  ["unassigned ignores yesterday", { type: "crew_unassigned_today", crewId: "pherris" }, baseFacts({ assignments: { pherris: { day: 13 } } })],
  ["planning window open at slot 0", { type: "planning_window_open" }, baseFacts()],
  ["planning window shut at slot 1", { type: "planning_window_open" }, baseFacts({ timeSlotsToday: 1 })],
  ["planning window shut at slot 3", { type: "planning_window_open" }, baseFacts({ timeSlotsToday: 3 })],
  ["proof_flag set", { type: "proof_flag", crewId: "pherris", key: "first_route" }, baseFacts()],
  ["proof_flag unset", { type: "proof_flag", crewId: "pherris", key: "never_happened" }, baseFacts()],
  ["proof_flag no proofs at all", { type: "proof_flag", crewId: "pherris", key: "first_route" }, baseFacts({}, { proofs: {} })],
  ["proof_counter at min", { type: "proof_counter_min", crewId: "pherris", key: "completed_routes", min: 4 }, baseFacts()],
  ["proof_counter one below", { type: "proof_counter_min", crewId: "pherris", key: "completed_routes", min: 5 }, baseFacts()],
  ["proof_counter missing key", { type: "proof_counter_min", crewId: "pherris", key: "absent", min: 1 }, baseFacts()],
  ["custom blocker code", { type: "crew_loyalty_min", crewId: "pherris", min: 9, blockerCode: "pherris_not_ready" }, baseFacts()],
  ["custom copy key", { type: "crew_loyalty_min", crewId: "pherris", min: 9, blockerCopyKey: "crew.pherris.loyalty" }, baseFacts()],
  ["unsupported type", { type: "future_magic_gate" }, baseFacts()],
  ["missing type", { crewId: "pherris" }, baseFacts()],
  ["null requirement", null, baseFacts()],
  ["string requirement", "crew_active", baseFacts()],
  ["number requirement", 7, baseFacts()],
];

const requirement_cases = REQUIREMENT_CASES.map(([name, requirement, facts]) => ({
  name,
  requirement,
  godot_requirement: godotRequirement(requirement),
  godot_facts: godotFacts(facts),
  expected: encodeResult(Req.evaluateRequirement(requirement, facts)),
}));

// evaluateRequirements: the short-circuit, and that ORDER decides which blocker
// the player is shown. The same two gates reversed must report the other
// reason — that is what proves it stops rather than scores.
const LIST_CASES = [
  ["all pass", [
    { type: "crew_active", crewId: "pherris" },
    { type: "crew_loyalty_min", crewId: "pherris", min: 6 },
    { type: "crew_rank_min", crewId: "pherris", min: 1 },
    { type: "crew_tenure_days_min", crewId: "pherris", min: 5 },
    { type: "hustle_tier_min", hustleId: "907list", min: 3 },
    { type: "payroll_not_delinquent", crewId: "pherris" },
    { type: "crew_unassigned_today", crewId: "pherris" },
    { type: "planning_window_open" },
    { type: "proof_flag", crewId: "pherris", key: "first_route" },
    { type: "proof_counter_min", crewId: "pherris", key: "completed_routes", min: 3 },
  ], baseFacts()],
  ["first of two failures wins", [
    { type: "crew_loyalty_min", crewId: "pherris", min: 9 },
    { type: "planning_window_open" },
  ], baseFacts({ timeSlotsToday: 2 })],
  ["order decides the reason", [
    { type: "planning_window_open" },
    { type: "crew_loyalty_min", crewId: "pherris", min: 9 },
  ], baseFacts({ timeSlotsToday: 2 })],
  ["empty list passes", [], baseFacts()],
  ["null list passes", null, baseFacts()],
  ["an unsupported gate blocks the rest", [
    { type: "future_magic_gate" },
    { type: "crew_active", crewId: "pherris" },
  ], baseFacts()],
];

const requirement_lists = LIST_CASES.map(([name, requirements, facts]) => ({
  name,
  requirements,
  godot_requirements: requirements === null ? null : requirements.map(godotRequirement),
  godot_facts: godotFacts(facts),
  expected: encodeResult(Req.evaluateRequirements(requirements, facts)),
}));

const rank_labels = [0, 1, 2, 3, 4, 5, 6, 7, 99].map((rank) => ({
  rank, label: Prog.crewRankLabel(rank),
}));

const CURVES = {
  wage_deshawn: [50, 100, 200],
  wage_tone: [85, 150, 250],
  wage_pherris: [60, 120, 220],
  tone_defense: { 1: 1.15, 2: 1.3, 3: 1.5 },
  deshawn_heat: { 1: 0.8, 2: 0.6, 3: 0.4 },
};
const curve_lookups = [];
for (const [name, curve] of Object.entries(CURVES)) {
  for (const rank of [0, 1, 2, 3, 4, 5, 6, 12]) {
    curve_lookups.push({ curve: name, rank, value: Prog.curveValueForRank(curve, rank) });
  }
}
const curve_empty = {
  array: Prog.curveValueForRank([], 3, 7),
  object: Prog.curveValueForRank({}, 6, 7),
};

const CAPABILITY_CASES = [
  ["pherris", "907list_run_board", 1], ["pherris", "907list_run_board", 2],
  ["pherris", "907list_run_board", 3], ["pherris", "907list_run_board", 6],
  ["pherris", "907list_run_board", 0], ["pherris", "unknown_capability", 3],
  ["tone", "907list_run_board", 3], ["eli", "territory_operations", 3],
  ["deshawn", "network_operations", 3], ["nobody", "907list_run_board", 3],
];
const capabilities = CAPABILITY_CASES.map(([crewId, capabilityId, rank]) => ({
  crew_id: crewId, capability_id: capabilityId, rank,
  has: Prog.crewHasCapability(crewId, capabilityId, rank),
  summary: Prog.crewCapabilitySummary(crewId, capabilityId, rank),
}));

const fs001Fixtures = {
  oracle_version: core.VERSION,
  oracle_source: "web PR #98 (src/systems/requirements.js, src/data/crew-progression.js)",
  oracle_commit: "a7d9534",
  generated_note: "run scripts/parity/gen_fixtures.mjs against the web oracle; do not hand-edit",
  max_crew_rank: Prog.MAX_CREW_RANK,
  base_crew_capacity: Prog.BASE_CREW_CAPACITY,
  crew_capacity: Prog.crewCapacity(),
  displayed_crew_capacity: Prog.crewCapacity(),
  rank_labels,
  curve_lookups,
  curve_empty,
  capabilities,
  requirement_cases,
  requirement_lists,
};

const fs001Path = join(
  here, "..", "..", "tests", "parity", "fixtures", "requirements", "fs001_fixtures.json");
mkdirSync(dirname(fs001Path), { recursive: true });
writeFileSync(fs001Path, JSON.stringify(fs001Fixtures, null, 1) + "\n");
console.log(
  `wrote ${fs001Path}: ${requirement_cases.length} requirement cases, ` +
  `${requirement_lists.length} list cases, ${rank_labels.length} rank labels, ` +
  `${curve_lookups.length} curve lookups, ${capabilities.length} capability reads`
);
}
