extends RefCounted
## Travel checkpoint content — STR-D4 (0.5.0 PR C).
##
## The gate itself is `WanderSystem.attention_steps()`/`gate_chance()`
## (`data/wander_events.gd`), read rather than re-derived — STR-D4 asks for
## "the same interruption machinery," not a travel-flavored second formula.
## What belongs here is what actually differs: the authored script a fired
## checkpoint plays.
##
## One script, not a pool — Wander's roster (PR B) needed weighting because
## several cards compete for one draw; a checkpoint has exactly one thing to
## be, so there is nothing here to pick among yet. `CHECKPOINT`'s shape
## matches the encounter sub-dictionary `wander_events.gd`'s own cards carry
## under `"encounter"`, so `TravelSystem` builds a chain from it the same way
## `WanderSystem._play_encounter` builds one from a card.
##
## VOX-D1: a patrol stop is business, not a brawl — TALK is the expected
## road, RUN is Combat because breaking away from a stop is a physical act
## even when nobody throws a punch, and HAND OVER only ever costs what is
## actually illegal to be holding. No line here is lifted or paraphrased
## from any outside source; the register is emulated, not quoted.

const CHECKPOINT := {
	"definition_id": "travel_patrol_stop",
	"opponent": "The patrol car",
	# Charisma-default (TALK is the expected road, matching the deepened
	# foot-stop's own precedent of a police-flavored stop defaulting to
	# negotiation's tier bands); RUN overrides to Combat below.
	"shape": "negotiation",
	"choices": ["talk", "run_it", "hand_over"],
	"deterministic": ["hand_over"],
	"base": {"talk": 0.60, "run_it": 0.45},
	"attribute_overrides": {"run_it": "combat"},
	# Police, not criminals: every tier below costs product and, on the worse
	# roads, Heat and health — never cash. A patrol has no reason to take
	# money that is not itself illegal to hold, the same distinction
	# `wander_stopped_on_foot` already draws against `wander_shakedown`'s
	# armed, cash-taking robbery.
	"effects": {
		"talk": {
			"clean": {},
			"messy": {"heat": 0.5},
			"failure": {"heat": 1.0, "goods_fraction": 0.35},
			"catastrophic": {"heat": 1.5, "goods_fraction": 0.75},
		},
		"run_it": {
			"clean": {},
			"messy": {"heat": 1.0, "goods_fraction": 0.15},
			"failure": {"health": 4, "heat": 2.0, "goods_fraction": 0.5},
			"catastrophic": {"health": 10, "heat": 2.5, "goods_fraction": 1.0},
		},
		"hand_over": {
			"deterministic": {"goods_fraction": 1.0},
		},
	},
}

const CHOICE_LABELS := {
	"talk": "TALK YOUR WAY THROUGH",
	"run_it": "RUN FOR IT",
	"hand_over": "HAND IT OVER",
}

const CHOICE_COPY := {
	"talk": "Plates, papers, a reason to be out here. Give them one.",
	"run_it": "Nobody said stop loud enough to matter. Go.",
	"hand_over": "Let them find it. You keep your feet and your health; the bag stays with them.",
}
