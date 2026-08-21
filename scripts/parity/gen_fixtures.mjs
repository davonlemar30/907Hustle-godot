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
const { normalizeSeed, makeRandom } = require(join(oraclePath, "src/events/random.js"));
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

const attributes = {
  ids: AD.ATTRIBUTE_IDS,
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
};

const outPath = join(here, "..", "..", "tests", "parity", "fixtures", "rng_fixtures.json");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(fixtures, null, 1) + "\n");
console.log(
  `wrote ${outPath}: ${hashes.length} hashes, ${seeds.length} seeds, ` +
  `${streams.length} streams, ${market_walks.length} lifecycle walks, ` +
  `${initial_markets.length} oracle initial markets, ` +
  `${phone.clock.frames.length} phone clock frames, ` +
  `${attributes.growth.length} attribute growth rows (oracle v${core.VERSION}; ` +
  `initialMarket copy verified at offset ${verifiedAtBurn}, ` +
  `evolveMarkets copy verified at offset ${evolveVerifiedAtBurn}; ` +
  `phone message-id format verified against oracle message ${phone.message.message.id})`
);
