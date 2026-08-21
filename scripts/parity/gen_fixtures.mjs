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
const fixtures = {
  oracle_version: core.VERSION,
  generated_note: "run scripts/parity/gen_fixtures.mjs against the web oracle; do not hand-edit",
  hashes,
  seeds,
  streams,
  market_static,
  market_walks,
  initial_markets,
};

const outPath = join(here, "..", "..", "tests", "parity", "fixtures", "rng_fixtures.json");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(fixtures, null, 1) + "\n");
console.log(
  `wrote ${outPath}: ${hashes.length} hashes, ${seeds.length} seeds, ` +
  `${streams.length} streams, ${market_walks.length} lifecycle walks, ` +
  `${initial_markets.length} oracle initial markets (oracle v${core.VERSION}; ` +
  `initialMarket copy verified at offset ${verifiedAtBurn}, ` +
  `evolveMarkets copy verified at offset ${evolveVerifiedAtBurn})`
);
