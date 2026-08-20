extends Node
## RngManager — deterministic, replay-stable RNG.
##
## Port of the web build's FNV-1a string hash (src/hash.js) so every seeded roll
## matches the JS oracle bit-for-bit. NOTHING else in the project may use
## randf()/randi() — all probability routes through here, keyed by a seed + a
## context string (the web's per-decision keying), which keeps outcomes stable on
## replay of the same day.

const FNV_OFFSET_BASIS := 2166136261
const FNV_PRIME := 16777619
const MASK_32 := 0xFFFFFFFF
const HASH_CEILING := 4294967296.0  # 2^32

## FNV-1a over a string → unsigned 32-bit int. Matches JS stringHash().
func string_hash(value: String) -> int:
	var h := FNV_OFFSET_BASIS
	for i in value.length():
		h = (h ^ value.unicode_at(i)) & MASK_32
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
