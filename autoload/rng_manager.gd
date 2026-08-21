extends Node
## RngManager — deterministic, replay-stable RNG.
##
## Port of the web build's FNV-1a string hash (src/hash.js) and its xorshift32
## stream (src/events/random.js makeRandom) so every seeded roll matches the JS
## oracle bit-for-bit. NOTHING else in the project may use randf()/randi() — all
## probability routes through here.
##
## Two DIFFERENT randomness shapes exist in canon, and they are not
## interchangeable:
## - **Keyed** (`stringHash(key)` normalised to 0..1): one value per unique key,
##   independent of call order. Used where a replay of the same day must resolve
##   the same way regardless of what else ran first.
## - **Stream** (`makeRandom(rngState)`, xorshift32): consecutive draws from a
##   cursor carried in run state. Order and COUNT of draws matter — an extra
##   draw anywhere shifts every draw after it. Canon's market walk
##   (evolveMarkets) and crew assignment resolution consume from the stream.
## Pick the shape canon used at the call site, never by preference.

const FNV_OFFSET_BASIS := 2166136261
const FNV_PRIME := 16777619
const MASK_32 := 0xFFFFFFFF
const HASH_CEILING := 4294967296.0  # 2^32
## Canon normalizeSeed fallback (src/events/random.js): 0x9072026.
const SEED_FALLBACK := 0x9072026

## FNV-1a over a string → unsigned 32-bit int. Matches JS stringHash() exactly,
## including its UTF-16 quirk: JS iterates code points but hashes
## `charCodeAt(0)`, which for an astral character (> U+FFFF) is the HIGH
## SURROGATE, not the code point. No game key contains one, but bit-exact means
## bit-exact — so code points past the BMP hash their high surrogate here too.
func string_hash(value: String) -> int:
	var h := FNV_OFFSET_BASIS
	for i in value.length():
		var cp := value.unicode_at(i)
		if cp > 0xFFFF:
			cp = 0xD800 + ((cp - 0x10000) >> 10)
		h = (h ^ cp) & MASK_32
		h = (h * FNV_PRIME) & MASK_32
	return h

## Deterministic float in [0, 1) from seed + context (web: stringHash(key)/2^32).
func seeded_random(seed: String, context: String) -> float:
	return float(string_hash(seed + ":" + context)) / HASH_CEILING

## Deterministic int in [min_v, max_v] (web rollRange).
func seeded_int_range(seed: String, context: String, min_v: int, max_v: int) -> int:
	if max_v <= min_v:
		return min_v
	return min_v + int(floor(seeded_random(seed, context) * (max_v - min_v + 1)))

## Deterministic float in [0, 1) using the web's OTHER normalisation:
## `stringHash(key) % 10000 / 10000`. Canon uses this form for some rolls (the
## Shark default check at game-core.js:6561 among them) and `hash / 2^32` for
## others. The two produce different values from the same hash, so the roll has
## to use whichever form canon used or Phase 5's dual-run parity will not hold.
func seeded_unit_10k(seed: String, context: String) -> float:
	return float(string_hash(seed + ":" + context) % 10000) / 10000.0

# --- Stream RNG (canon: src/events/random.js makeRandom) --------------------

## Port of canon's normalizeSeed: coerce anything to a uint32 seed, falling back
## to 0x9072026 for non-numeric input ("907hustle" → fallback, exactly as JS
## Number("907hustle") → NaN → fallback) and for a zero result.
static func normalize_seed(seed_value: Variant) -> int:
	var numeric := NAN
	match typeof(seed_value):
		TYPE_INT, TYPE_FLOAT:
			numeric = float(seed_value)
		TYPE_BOOL:
			# JS Number(true) is 1. Nothing passes a bool, but exact is exact.
			numeric = 1.0 if seed_value else 0.0
		TYPE_STRING:
			# JS Number(""): empty/whitespace strings are 0; otherwise a full
			# float parse or NaN.
			var s := (seed_value as String).strip_edges()
			if s.is_empty():
				numeric = 0.0
			elif s.is_valid_float() or s.is_valid_int():
				numeric = s.to_float()
	if not is_finite(numeric):
		return SEED_FALLBACK
	# JS ToUint32: truncate toward zero, then wrap into [0, 2^32).
	var wrapped := posmod(int(numeric), 1 << 32)
	return wrapped if wrapped != 0 else SEED_FALLBACK

## One xorshift32 stream — canon's makeRandom. Draws are order- and
## count-sensitive: the caller owns reading `.state` back into run state after a
## batch, exactly as canon does (`state.run.rngState = random.state`).
##
## Constants are duplicated as literals here rather than read off the RngManager
## global: a script referencing its own autoload identifier at parse time is the
## chicken-and-egg the HANDOFF warns about.
class Xorshift:
	extends RefCounted
	const _MASK_32 := 0xFFFFFFFF
	const _CEILING := 4294967296.0
	var state: int

	func _init(seed_state: int) -> void:
		state = seed_state & _MASK_32

	## value ^= value<<13; value ^= value>>>17; value ^= value<<5; value>>>=0;
	## return value / 2^32. Masking each step is bit-equivalent to JS's int32
	## intermediate representation because XOR and logical shifts only ever read
	## the low 32 bits.
	func next() -> float:
		state = (state ^ (state << 13)) & _MASK_32
		state = (state ^ (state >> 17)) & _MASK_32
		state = (state ^ (state << 5)) & _MASK_32
		return float(state) / _CEILING

	## Canon random.int(min, max) — inclusive both ends.
	func next_int(min_v: int, max_v: int) -> int:
		return int(floor(next() * float(max_v - min_v + 1))) + min_v

	## Canon random.pick(items).
	func pick(items: Array) -> Variant:
		return items[int(floor(next() * float(items.size())))]

## Build a stream. Canon's makeRandom runs normalizeSeed on whatever it is
## given — a fresh seed AND a carried rngState cursor alike — so this does too.
## (Identity for any nonzero uint32, which a carried cursor always is: xorshift
## never reaches 0 from a nonzero state.)
func make_stream(seed_value: Variant) -> Xorshift:
	return Xorshift.new(normalize_seed(seed_value))
