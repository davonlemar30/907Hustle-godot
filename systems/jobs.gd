extends RefCounted
## Jobs system — the legitimate income ladder.
##
## Ported from the web build's job reducer (game-core.js resolveJobShift /
## applyAttendance, src/data/jobs.js). The parts that matter:
##
##   - Pay is a band, not a rate. A shift rolls inside [min, max], the band
##     scales by rank (1 + rank*0.10), and the approach multiplies the result.
##   - Attendance counts CONSECUTIVE days ended without working, not total.
##     Working any shift resets the ladder. This punishes ghosting, not an
##     irregular schedule.
##   - Day labour has no attendance at all, which is why it is the floor you
##     land on after being fired.
##
## Not ported (each its own feature): coworkers and their relationships, shift
## dialogue, workplace details from `learn_job`, job discovery beyond the
## starter set.
##
## ## The interview (Build 5e)
##
## Applying used to be a formality — every application became a job. Canon makes
## it a real interview read through Charisma, and this is that landing:
##
##   chance = clamp(0.62 - max(0, heat - 4) * 0.04, 0.25, 0.95)
##
## Heat costs you here too: a manager who has heard things is a harder room.
## The roll resolves on canon's `job_interview` shape, which is the one shape in
## the table with NO catastrophic tier — the worst case of an interview is not
## being hired, and canon says so in the data rather than in a special case.
##
## **Where this diverges, and why.** Canon queues the application and resolves
## it two slots later over the phone, then offers the job rather than granting
## it. That pipeline is `state.jobs.applications` / `offers` plus a phone-gated
## callback, none of which this build has — its Jobs screen hires on the tap. So
## the interview resolves at apply time instead, keyed on the day and slot the
## application was made, which is exactly what canon keys on. Everything else —
## the chance formula, the shape, the attribute, the observation footprint — is
## canon's. Turned down is not a lockout: canon's line is that nothing stops you
## applying again, and a later slot is a different key.

## BR-D2 (0.9.0): how many slots an application waits before the answer
## comes. Two: apply in the morning, hear back by evening; apply at night,
## hear back tomorrow afternoon.
const APPLICATION_WAIT_SLOTS := 2

## BR-D3 (0.9.0 PR 2): the rungs. XP still fills the bar (canon's ladder),
## but the rung is earned only when the manager would give it: days in the
## role, showing up in a row, rapport with whoever runs the place, and the
## attribute the job actually uses. Index is the rung being reached.
## Tuned against the economy sweep: the first cut (days 3/7, streak 3/5,
## rapport 4/8, attribute 2/3) held a plain worker at the bottom rung for
## the whole run and cut the job yardstick 28%. These reach the second
## rung inside a week of showing up and the third with one point of the
## job's attribute, which the floor buttons can earn.
const TIER_MIN_DAYS := [0, 2, 6]
const TIER_STREAK := [0, 2, 4]
const TIER_RAPPORT := [0, 3, 6]
const TIER_ATTRIBUTE := [0, 1, 2]
## An interview offer that sits unanswered this long lapses.
const INTERVIEW_LAPSE_SLOTS := 8
## What a good interview is worth on the chance, per point of score.
const INTERVIEW_SCORE_CHANCE := 0.08
## Rapport at hire: this plus the interview score.
const RAPPORT_AT_HIRE := 3
## What the floor buttons are worth.
const SOCIALIZE_CHARISMA := 0.34
const LEARN_INTELLIGENCE := 0.25
const BREAK_ROOM_HEALTH := 3
const OVERHEAR_CHANCE := 0.5
const MUTED := Color(0.608, 0.608, 0.608)

## Canon thresholds. Warnings at 1 and 2, gone at 3.
const MISSED_FIRST_WARNING := 1
const MISSED_FINAL_WARNING := 2
const MISSED_FIRING := 3

const MANAGERS := preload("res://data/job_managers.gd")

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var rng: Node
var time_system: RefCounted
var gm: Node
var attributes: RefCounted

func setup(game_state: Node, rng_manager: Node, time: RefCounted, manager: Node,
		attribute_system: RefCounted) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	gm = manager
	attributes = attribute_system
	# Settlement is driven by DayLifecycle in declared order, not by a signal
	# whose handlers run in connection order. See systems/day_lifecycle.gd.


## The exposure layer, or null before it exists. Every system reaches it the
## same way so the null-check lives in one shape rather than five.
func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func _curtis_node() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Curtis")

## BR-D3: what stands between this run and the next rung, in words the
## Jobs screen can print. Empty when the next rung is open (or there is
## none).
func promotion_gaps(job_id: String) -> Array:
	var rec: Dictionary = gs.job_records.get(job_id, {})
	var rank: int = int(rec.get("rank", 0))
	var tiers: Array = MANAGERS.tiers_for(job_id)
	if tiers.is_empty() or rank >= tiers.size() - 1:
		return []
	var next: int = rank + 1
	var gaps: Array = []
	var xp_need: float = float(gs.JOB_RANK_THRESHOLDS[mini(next - 1, gs.JOB_RANK_THRESHOLDS.size() - 1)])
	if float(rec.get("xp", 0.0)) < xp_need:
		gaps.append("more shifts")
	var days: int = int(gs.day) - int(rec.get("hired_day", gs.day))
	if days < int(TIER_MIN_DAYS[next]):
		gaps.append("%d more day%s" % [int(TIER_MIN_DAYS[next]) - days,
			"" if int(TIER_MIN_DAYS[next]) - days == 1 else "s"])
	if int(rec.get("streak", 0)) < int(TIER_STREAK[next]):
		gaps.append("%d in a row" % int(TIER_STREAK[next]))
	if int(rec.get("rapport", 0)) < int(TIER_RAPPORT[next]):
		gaps.append("a word with %s" % str(MANAGERS.manager_for(job_id).get("name", "the boss")))
	var attribute := str(MANAGERS.manager_for(job_id).get("performance_attribute", "charisma"))
	if int(attributes.value(attribute)) < int(TIER_ATTRIBUTE[next]):
		gaps.append("more %s" % attribute)
	return gaps

## BR-D3: the rung this record has earned -- the XP ladder's rung, held
## back by whichever gate is not met. Never lower than the rung already
## held: a promotion is not taken back for a slow week.
func _earned_rank(job_id: String, rec: Dictionary) -> int:
	var held: int = int(rec.get("rank", 0))
	var by_xp: int = gs.job_rank_for_xp(float(rec.get("xp", 0.0)))
	var tiers: Array = MANAGERS.tiers_for(job_id)
	if tiers.is_empty():
		return maxi(held, by_xp)
	var ceiling: int = tiers.size() - 1
	var rank: int = held
	var attribute := str(MANAGERS.manager_for(job_id).get("performance_attribute", "charisma"))
	# One rung per shift: a promotion is a moment, and two in one night is
	# not two moments.
	if rank < mini(by_xp, ceiling):
		var next: int = rank + 1
		var days: int = int(gs.day) - int(rec.get("hired_day", gs.day))
		if days >= int(TIER_MIN_DAYS[next]) and int(rec.get("streak", 0)) >= int(TIER_STREAK[next]) \
				and int(rec.get("rapport", 0)) >= int(TIER_RAPPORT[next]) \
				and int(attributes.value(attribute)) >= int(TIER_ATTRIBUTE[next]):
			rank = next
	return rank

func can_handle(action: String) -> bool:
	return action in ["apply_job", "work_shift", "quit_job", "start_interview", "finish_interview", "negotiate_pay"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"apply_job":
			return _apply(str(payload.get("job_id", "")))
		"work_shift":
			return _work(str(payload.get("approach", "work_hard")))
		"quit_job":
			return _quit()
		"negotiate_pay":
			return _negotiate(str(payload.get("job_id", "")), str(payload.get("mode", "ask")))
		"start_interview":
			return _start_interview(str(payload.get("job_id", "")))
		"finish_interview":
			return _finish_interview(str(payload.get("job_id", "")), int(payload.get("score", 0)))
	return {"ok": false, "reason": "Unknown job action."}

## Canon's interview chance. Charisma is read by the resolver, not by this
## formula — the term canon dropped when the action moved onto the tier engine.
func interview_chance() -> float:
	return clampf(0.62 - maxf(0.0, gs.heat - 4.0) * 0.04, 0.25, 0.95)

func _apply(job_id: String) -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	var job: Dictionary = gs.job_by_id(job_id)
	if job.is_empty():
		return {"ok": false, "reason": "No such job."}
	if not job_id in gs.jobs_discovered:
		return {"ok": false, "reason": "You haven't heard about that one."}
	if gs.active_job_id == job_id:
		return {"ok": false, "reason": "You already work there."}
	var manager: Dictionary = MANAGERS.manager_for(job_id)
	var who := str(manager.get("name", ""))
	# BR-D2: day labor takes walk-ins -- no application, no wait. Everybody
	# else is a state on the board and an answer by text a couple of slots
	# later. The tap is acknowledged the moment it happens.
	if not bool(job.get("day_labor", false)):
		if gs.job_applications.has(job_id):
			return {"ok": false, "reason": "You already applied. %s will let you know."
				% (who if not who.is_empty() else "They")}
		gs.job_applications[job_id] = {"day": int(gs.day), "slot": int(gs.time_slots_today),
			"status": "pending"}
		gs.log_activity("Applied at %s. %s will let you know." % [job["name"],
			who if not who.is_empty() else "They"], AMBER)
		return {"ok": true, "applied": job_id}
	return _hire(job_id, "clean")

## BR-D2: the clock moved. Every application that has waited its slots is
## rolled -- canon's interview chance, keyed on the day and slot it was made
## -- and answered by text from whoever runs the place. Hired is `_hire` plus
## the text; turned down is the text and the board opening back up.
func resolve_applications() -> void:
	if gs.game_over or gs.job_applications.is_empty():
		return
	var resolver: Object = gm.system("outcome_resolver") if gm != null else null
	if resolver == null:
		return
	var phone: Object = gm.system("phone") if gm != null else null
	var now: int = int(gs.day) * 4 + int(gs.time_slots_today)
	for job_key in gs.job_applications.keys().duplicate():
		var job_id := str(job_key)
		var row: Dictionary = gs.job_applications[job_id]
		var then: int = int(row.get("day", gs.day)) * 4 + int(row.get("slot", 0))
		var job: Dictionary = gs.job_by_id(job_id)
		if job.is_empty():
			gs.job_applications.erase(job_id)
			continue
		var manager: Dictionary = MANAGERS.manager_for(job_id)
		var who := str(manager.get("name", ""))
		var status := str(row.get("status", "pending"))
		# BR-D3: a place with a manager interviews. Pending becomes an offer
		# to come in (a text); the offer waits on the player and lapses if
		# ignored; interviewed resolves a slot later with the score on it.
		if status == "pending":
			if now - then < APPLICATION_WAIT_SLOTS:
				continue
			if not MANAGERS.questions_for(job_id).is_empty() and not who.is_empty():
				row["status"] = "interview"
				row["day"] = int(gs.day)
				row["slot"] = int(gs.time_slots_today)
				gs.job_applications[job_id] = row
				gs.log_activity("%s wants to see you. The interview is yours to go to." % who, AMBER)
				if phone != null:
					phone.push_text(who, str(manager.get("interview_text",
						"Come in tomorrow and we'll talk.")), "manager_interview")
				continue
		elif status == "interview":
			if now - then < INTERVIEW_LAPSE_SLOTS:
				continue
			gs.job_applications.erase(job_id)
			gs.log_activity("You never went in to see %s. The offer lapses." % who, RED)
			if phone != null and not who.is_empty():
				phone.push_text(who, "You didn't come in. I filled it.", "manager_rejected")
			continue
		elif status == "interviewed":
			if now - then < 1:
				continue
		var score: int = int(row.get("score", 0))
		var key := "%d:%d:job_interview:%s" % [int(row.get("day", gs.day)),
			int(row.get("slot", 0)), job_id]
		var chance: float = clampf(interview_chance() + float(score) * INTERVIEW_SCORE_CHANCE, 0.2, 0.97)
		var outcome: Dictionary = resolver.resolve_action(
			"job_interview", chance, attributes.effective("charisma"), gs.run_seed, key)
		var tier: String = str(outcome["tier"])
		resolver.broadcast_outcome("job_interview", tier, gs.current_district_id)
		gs.job_applications.erase(job_id)
		if not resolver.is_success_tier(tier):
			gs.log_activity("%s passed. Nothing stops you applying again." % job["name"], RED)
			if phone != null and not who.is_empty():
				phone.push_text(who, str(manager.get("reject_text",
					"We went with somebody else. Good luck out there.")), "manager_rejected")
			continue
		_hire(job_id, tier)
		gs.job_records[job_id]["rapport"] = RAPPORT_AT_HIRE + score
		if phone != null and not who.is_empty():
			phone.push_text(who, str(manager.get("hire_text", "You're on. Come in tomorrow.")),
				"manager_hired")

## BR-D3: the player goes in. The interview is a sheet (three questions, two
## answers each, the manager reacting to each); this only opens it.
func _start_interview(job_id: String) -> Dictionary:
	var row: Dictionary = gs.job_applications.get(job_id, {})
	if str(row.get("status", "")) != "interview":
		return {"ok": false, "reason": "Nobody is waiting to see you there."}
	if gs.current_district_id != "north_star_lot":
		return {"ok": false, "reason": "The interview is in Spenard."}
	var nav: Node = _screen_manager()
	if nav != null:
		nav.enqueue_flow_sheet({"kind": "interview", "job_id": job_id})
	return {"ok": true, "job_id": job_id}

## The sheet hands back the score. Resolves on the next advance.
func _finish_interview(job_id: String, score: int) -> Dictionary:
	var row: Dictionary = gs.job_applications.get(job_id, {})
	if str(row.get("status", "")) != "interview":
		return {"ok": false, "reason": "There is no interview to finish."}
	row["status"] = "interviewed"
	row["score"] = clampi(score, -3, 3)
	row["day"] = int(gs.day)
	row["slot"] = int(gs.time_slots_today)
	gs.job_applications[job_id] = row
	var who := str(MANAGERS.manager_for(job_id).get("name", "They"))
	gs.log_activity("%s walks you out. \"I'll let you know.\"" % who, AMBER)
	return {"ok": true, "score": row["score"]}

## The hire itself: the record, the ladder reset, the feed, the sheet.
## TU-D5 (1.3.0): the rung you start on. Somebody who held the second rung
## anywhere else does not start at the bottom here.
func experience_rank(job_id: String) -> int:
	var best := 0
	for other in gs.job_records.keys():
		if str(other) == job_id:
			continue
		best = maxi(best, int((gs.job_records[other] as Dictionary).get("rank", 0)))
	return 1 if best >= 2 else 0

## Whether the hire sheet offers a word about money: you came from a job,
## or you have done this before, and you have not already had the word.
func negotiation_open(job_id: String) -> bool:
	var rec: Dictionary = gs.job_records.get(job_id, {})
	if rec.is_empty() or not str(rec.get("negotiated", "")).is_empty():
		return false
	return not str(rec.get("came_from", "")).is_empty() or experience_rank(job_id) > 0

func _hire(job_id: String, tier: String) -> Dictionary:
	var job: Dictionary = gs.job_by_id(job_id)
	var came_from: String = gs.active_job_id if gs.active_job_id != job_id else ""
	var start_rank: int = experience_rank(job_id)
	gs.active_job_id = job_id
	if not gs.job_records.has(job_id):
		gs.job_records[job_id] = {"xp": 0.0, "rank": start_rank, "last_worked_day": -1, "hired_day": gs.day}
	else:
		gs.job_records[job_id]["hired_day"] = gs.day
		gs.job_records[job_id]["rank"] = maxi(int(gs.job_records[job_id].get("rank", 0)), start_rank)
	gs.job_records[job_id]["came_from"] = came_from
	gs.job_records[job_id].erase("negotiated")
	gs.job_records[job_id].erase("raise")
	if start_rank > 0:
		gs.log_activity("They put you on as %s, not at the bottom. You have done this before, and it shows." % MANAGERS.title_for(job_id, start_rank), GREEN)
	gs.job_missed[job_id] = 0
	# Clean and messy both got the job; what separates them is the room. Only
	# the clean read is worth telling the house about, which is canon's single
	# `household` observation in the whole outcome table.
	if tier == "clean":
		gs.log_activity("Hired on at %s. They liked you." % job["name"], GREEN)
	else:
		gs.log_activity("Hired on at %s. It was not pretty, but it is a job." % job["name"], GREEN)
	# WS-D4: the hire is a moment -- whoever runs the place says their two
	# or three lines on a sheet before the board comes back.
	var nav: Node = _screen_manager()
	if nav != null:
		nav.enqueue_flow_sheet({"kind": "hire", "job_id": job_id, "tier": tier})
	return {"ok": true, "hired": job["name"], "tier": tier}

## TU-D5: the word about money, on the hire sheet. ASK is charisma against
## a fair chance for ten percent; NAME A NUMBER is intelligence against a
## worse chance for twenty, and a miss costs a point with the manager.
const NEGOTIATE := {
	"ask": {"attribute": "charisma", "chance": 0.55, "raise": 0.10, "miss_rapport": 0},
	"number": {"attribute": "intelligence", "chance": 0.40, "raise": 0.20, "miss_rapport": -1},
}

func _negotiate(job_id: String, mode: String) -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	if not NEGOTIATE.has(mode):
		return {"ok": false, "reason": "That is not a way to ask."}
	if not negotiation_open(job_id):
		return {"ok": false, "reason": "That conversation already happened."}
	var spec: Dictionary = NEGOTIATE[mode]
	var rec: Dictionary = gs.job_records[job_id]
	var level: int = int(attributes.effective(str(spec["attribute"])))
	var chance: float = clampf(float(spec["chance"]) + float(level) * 0.04, 0.1, 0.95)
	var key := "%d:%s:negotiate:%s" % [int(gs.day), job_id, mode]
	var won: bool = rng.seeded_random(gs.run_seed, key) < chance
	var manager: Dictionary = MANAGERS.manager_for(job_id)
	var who := str(manager.get("name", "They"))
	rec["negotiated"] = mode
	if won:
		rec["raise"] = float(spec["raise"])
		gs.log_activity("%s: \"Fine. %d percent. But you earn it.\"" % [who, int(round(float(spec["raise"]) * 100.0))], GREEN)
	else:
		rec["rapport"] = maxi(0, int(rec.get("rapport", 0)) + int(spec["miss_rapport"]))
		gs.log_activity("%s: \"That's the number.\"%s" % [who, " They remember you asked." if int(spec["miss_rapport"]) < 0 else ""], AMBER)
	gs.job_records[job_id] = rec
	return {"ok": true, "won": won, "raise": float(rec.get("raise", 0.0))}

## TU-D5: something happens every shift. The manager's own moments still
## come round; between them, the floor has its own -- a short register,
## a regular who asks for you, a write-up. Standing moves, and a write-up
## is a strike on the same count as a missed day.
const SHIFT_EVENTS := [
	# Ordered: a new hire's first moments are the good ones; the write-ups
	# come once you have been there a while and should know better.
	{"text": "A regular asks for you by name. %s hears it.", "rapport": 1},
	{"text": "You cover the back half of somebody's shift without being asked. %s notices without saying.", "rapport": 1, "cash": 15},
	{"text": "A delivery comes in short and you count it before signing. %s would have signed.", "rapport": 2},
	{"text": "A card declines three times and the man takes it out on you. You take it. %s takes it out of your tip jar for the trouble.", "health": -2, "rapport": 1},
	{"text": "The register comes up twenty short and %s looks at you first, then at the new kid. Then back.", "rapport": -1},
	{"text": "%s catches you on your phone on the floor. \"First one's free.\"", "rapport": -1},
	{"text": "Late back from the break. %s says nothing, which is the write-up.", "strike": 1},
	{"text": "Somebody walks out with a cart. You saw it and did nothing. So did %s.", "strike": 1, "cash": -10},
]

func _shift_event(job_id: String, rec: Dictionary) -> Dictionary:
	var shifts: int = int(rec.get("shifts", 0))
	if shifts % 2 == 0:
		var own: Dictionary = MANAGERS.micro_event(job_id, shifts)
		if not own.is_empty():
			return own
	return SHIFT_EVENTS[(shifts / 2) % SHIFT_EVENTS.size()]

## A write-up: the same count a missed day uses, the same door at three.
func _strike(job_id: String) -> void:
	var missed: int = int(gs.job_missed.get(job_id, 0)) + 1
	gs.job_missed[job_id] = missed
	gs.log_activity("Written up. %d of 3." % missed, RED)
	if missed >= MISSED_FIRING:
		_fire(job_id)

func _fire(job_id: String) -> void:
	var job: Dictionary = gs.job_by_id(job_id)
	var rec: Dictionary = gs.job_records.get(job_id, {})
	var manager: Dictionary = MANAGERS.manager_for(job_id)
	var phone: Object = gm.system("phone") if gm != null else null
	if phone != null and manager.has("fired_text"):
		phone.push_text(str(manager["name"]), str(manager["fired_text"]), "manager_fired")
	var nav: Node = _screen_manager()
	if nav != null and manager.has("fired"):
		nav.enqueue_flow_sheet({"kind": "fired", "job_id": job_id})
	gs.active_job_id = ""
	if job_id != "night_owl":
		rec["xp"] = 0.0
		rec["rank"] = 0
		rec["hired_day"] = -1
		gs.job_records[job_id] = rec
	gs.job_missed.erase(job_id)
	gs.log_activity("%s is done with you." % str(job.get("name", "The job")), RED)

func _screen_manager() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("/root/ScreenManager")

## The person who runs this job, or {} for day labor.
func manager_for(job_id: String) -> Dictionary:
	return MANAGERS.manager_for(job_id)

func _quit() -> Dictionary:
	if gs.active_job_id.is_empty():
		return {"ok": false, "reason": "You don't have a job."}
	var name: String = gs.active_job().get("name", "the job")
	gs.active_job_id = ""
	gs.log_activity("You quit %s. Nobody tries to talk you out of it." % name, AMBER)
	return {"ok": true}

## Why a shift can't be worked right now, or "" if it can. Shared by the system
## and the Jobs screen so the button's reason and the rejection never disagree.
func shift_blocker() -> String:
	if gs.game_over:
		return "The run is over."
	if gs.active_job_id.is_empty():
		return "You don't have a job."
	var job: Dictionary = gs.active_job()
	# Every canon job is in Spenard, so this is really "are you home".
	if gs.current_district_id != "north_star_lot":
		return "Your shift is in Spenard."
	if not gs.time_slots_today in job.get("slots", []):
		return "%s doesn't run a %s shift." % [job["name"], gs.time_slot.capitalize()]
	var rec: Dictionary = gs.job_records.get(gs.active_job_id, {})
	if int(rec.get("last_worked_day", -1)) == gs.day:
		return "You already worked today."
	return ""

func _work(approach_id: String) -> Dictionary:
	var blocked := shift_blocker()
	if not blocked.is_empty():
		return {"ok": false, "reason": blocked}
	var approach: Dictionary = gs.approach_by_id(approach_id)
	if approach.is_empty():
		return {"ok": false, "reason": "Unknown approach."}

	var job_id: String = gs.active_job_id
	var job: Dictionary = gs.job_by_id(job_id)
	var band: Dictionary = gs.job_pay_range(job_id)

	# Seeded so the same run replays identically. Keyed by day and slot as well
	# as the job, matching how canon keys its own rolls.
	var key := "job_shift_day%d_slot%d_%s" % [gs.day, gs.time_slots_today, job_id]
	var payout: int = rng.seeded_int_range(gs.run_seed, key, int(band["min"]), int(band["max"]))
	payout = int(round(float(payout) * float(approach["pay_mult"])))
	# WS-D4: what makes this job this job. The Chevron pays nights extra;
	# the Night Owl pays its regular a little more once you are one.
	var manager: Dictionary = MANAGERS.manager_for(job_id)
	var rec_before: Dictionary = gs.job_records.get(job_id, {})
	if gs.time_slots_today == 3:
		payout += int(manager.get("night_bonus", 0))
	if manager.has("regular_after") \
			and int(rec_before.get("shifts", 0)) >= int(manager.get("regular_after", 0)):
		payout += int(manager.get("regular_bonus", 0))

	# TI-003 §6 Clean: "legal job wages". Canon agrees — WORK_JOB is one of the
	# only two `addCleanCash` call sites in the whole build (game-core.js:7311).
	gm.system("wallet").credit(payout, gm.system("wallet").CLEAN,
		{"source_id": "job_%s" % job_id})
	gs.record_earning("jobs", payout)
	gs.health = clampi(gs.health + int(approach["health"]), 1, gs.health_max)

	var rec: Dictionary = gs.job_records[job_id]
	rec["xp"] = float(rec.get("xp", 0.0)) + float(approach["xp"])
	var old_rank: int = int(rec.get("rank", 0))
	rec["last_worked_day"] = gs.day
	rec["shifts"] = int(rec.get("shifts", 0)) + 1
	# BR-D3: the floor buttons do something you can see. SOCIALIZE is a
	# coworker and a point with the boss and a little charisma; BREAK ROOM
	# is health and half a chance to overhear something; LEARN THE JOB is a
	# little intelligence; WORK HARD is the pay it always was, and the boss
	# notices that too.
	var floor_line := ""
	match approach_id:
		"socialize":
			rec["rapport"] = int(rec.get("rapport", 0)) + 1
			attributes.improve("charisma", SOCIALIZE_CHARISMA)
			floor_line = _floor_line(job_id, "social", int(rec["shifts"]))
		"take_it_easy":
			gs.health = clampi(gs.health + BREAK_ROOM_HEALTH, 1, gs.health_max)
			if rng.seeded_int_range(gs.run_seed, "%d:%d:break_room" % [gs.day, gs.time_slots_today], 0, 99) \
					< int(OVERHEAR_CHANCE * 100.0):
				floor_line = _overhear_line(job_id, int(rec["shifts"]))
		"learn_job":
			attributes.improve("intelligence", LEARN_INTELLIGENCE)
		"work_hard":
			if int(rec["shifts"]) % 3 == 0:
				rec["rapport"] = int(rec.get("rapport", 0)) + 1
	if not floor_line.is_empty():
		gs.log_activity(floor_line, MUTED)
	rec["rank"] = _earned_rank(job_id, rec)
	# Working resets the attendance ladder, whatever rung it was on.
	gs.job_missed[job_id] = 0

	gs.log_activity("Shift at %s. $%d, and your feet hurt in the honest way." % [job["name"], payout], GREEN)
	# WS-D4: every three or four shifts something small happens on the
	# floor. A line, sometimes a few dollars or a little health; never a
	# decision. Seeded on the shift count, so a run replays its own floor.
	var micro := ""
	# TU-D5: every shift, not every third.
	if true:
		var event: Dictionary = _shift_event(job_id, rec)
		if not event.is_empty():
			rec["last_event_shift"] = int(rec["shifts"])
			micro = str(event.get("text", "")).replace("%s", str(manager.get("name", "The manager")))
			if int(event.get("rapport", 0)) != 0:
				rec["rapport"] = maxi(0, int(rec.get("rapport", 0)) + int(event.get("rapport", 0)))
			if int(event.get("strike", 0)) > 0:
				gs.job_records[job_id] = rec
				_strike(job_id)
				if gs.active_job_id != job_id:
					gs.log_activity(micro, RED)
					return {"ok": true, "payout": payout, "fired": true}
			var tip: int = int(event.get("cash", 0))
			if tip > 0:
				gm.system("wallet").credit(tip, gm.system("wallet").CLEAN,
					{"source_id": "job_%s" % job_id})
				gs.record_earning("jobs", tip)
			elif tip < 0:
				gm.system("wallet").spend(-tip, gm.system("wallet").ROUTINE_DIRTY_FIRST,
					{"source_id": "job_%s" % job_id})
			if int(event.get("health", 0)) != 0:
				gs.health = clampi(gs.health + int(event.get("health", 0)), 1, gs.health_max)
			gs.log_activity(micro, AMBER if tip < 0 else GREEN)
	# The Night Owl is Mina's counter; a night beside her is a night she
	# noticed. Small, direct, and only there.
	if job_id == "night_owl":
		var mina_ledger: Node = _exposure()
		if mina_ledger != null:
			mina_ledger.record_observation("mina", {"type": "presence",
				"event": "worked_beside", "source": "direct",
				"location": gs.current_district_id})
	# Canon tags WORK_SHIFT as presence/steady_work on the neighbourhood channel.
	var exposure: Node = _exposure()
	if exposure != null:
		exposure.broadcast_observation({
			"type": "presence", "event": "steady_work",
			"location": gs.current_district_id, "channel": "neighborhood",
		})
	var ranked_up: bool = int(rec["rank"]) > old_rank
	if ranked_up:
		# BR-D3: a promotion is a moment -- the manager's line, and a text.
		var lines: Array = manager.get("promotion_lines", [])
		var title := MANAGERS.title_for(job_id, int(rec["rank"]))
		if not lines.is_empty():
			gs.log_activity(str(lines[clampi(int(rec["rank"]) - 1, 0, lines.size() - 1)]), GREEN)
		else:
			gs.log_activity("%s moved you up to rank %d." % [job["name"], int(rec["rank"])], GREEN)
		var phone: Object = gm.system("phone") if gm != null else null
		if phone != null and manager.has("name") and not title.is_empty():
			phone.push_text(str(manager["name"]), "%s. It's yours. Don't make me regret it." % title,
				"manager_promoted")

	# A shift is a slot, the same as any other district action.
	time_system.handle("advance_time", {})
	return {"ok": true, "payout": payout, "ranked_up": ranked_up, "micro_event": micro}

## BR-D3: a coworker line, seeded on the shift count so a run replays it.
func _floor_line(job_id: String, key: String, shifts: int) -> String:
	var lines: Array = MANAGERS.manager_for(job_id).get(key, [])
	if lines.is_empty():
		return ""
	return str(lines[shifts % lines.size()])

## BR-D3: what the break room overhears. Half the time it is the block
## (authored); the other half it is the board, live -- the best route the
## economy knows about right now, in a coworker's mouth.
func _overhear_line(job_id: String, shifts: int) -> String:
	if shifts % 2 == 0:
		return _floor_line(job_id, "overhear", shifts / 2)
	var economy: Object = gm.system("economy") if gm != null else null
	if economy != null and bool(gs.phone_active):
		var routes: Array = economy.known_routes()
		if not routes.is_empty():
			var route: Dictionary = routes[0]
			return "Somebody in the break room says %s is paying $%d over on %s. Somebody else says that was last week." \
				% [str(route.get("product_name", route.get("product_id", "it"))).to_lower(),
					int(route.get("edge", 0)), str(route.get("name", "the other side of town"))]
	return _floor_line(job_id, "overhear", shifts)

## Attendance settles when a day ends. Canon runs this inside the day-end
## settlement, counting the day that just finished.
## Attendance for the day that just ended.
##
## `ended_day` arrives as a parameter — this used to derive `gs.day - 1`, which
## only worked because the handler happened to run after the increment. Canon
## passes it explicitly for the same reason (`applyAttendance(state, oldDay)`).
func settle_night(ended_day: int) -> void:
	if gs.game_over:
		return
	var job_id: String = gs.active_job_id
	if job_id.is_empty():
		return
	var job: Dictionary = gs.job_by_id(job_id)
	# Day labour keeps no roster, so there is nothing to miss.
	if bool(job.get("day_labor", false)):
		return
	var rec: Dictionary = gs.job_records.get(job_id, {})
	if int(rec.get("last_worked_day", -1)) == ended_day:
		# BR-D3: a day worked is a day in a row.
		rec["streak"] = int(rec.get("streak", 0)) + 1
		gs.job_records[job_id] = rec
		return
	# Grace on the day you were hired.
	if int(rec.get("hired_day", -1)) == ended_day:
		return

	var missed: int = int(gs.job_missed.get(job_id, 0)) + 1
	gs.job_missed[job_id] = missed
	# BR-D3: a miss breaks the streak and costs a point with the boss.
	rec["streak"] = 0
	rec["rapport"] = maxi(0, int(rec.get("rapport", 0)) - 2)
	gs.job_records[job_id] = rec

	var manager: Dictionary = MANAGERS.manager_for(job_id)
	var phone: Object = gm.system("phone") if gm != null else null
	if missed >= MISSED_FIRING:
		# WS-D4: being let go is a moment, not a log line -- the manager's
		# last text, and a sheet with what they did.
		if phone != null and manager.has("fired_text"):
			phone.push_text(str(manager["name"]), str(manager["fired_text"]), "manager_fired")
		var nav: Node = _screen_manager()
		if nav != null and manager.has("fired"):
			nav.enqueue_flow_sheet({"kind": "fired", "job_id": job_id})
		# Canon carves the Night Owl out: Mina stops scheduling you rather than
		# firing you, because that relationship was never employment.
		if job_id == "night_owl":
			gs.active_job_id = ""
			gs.log_activity("Mina takes you off the schedule.", RED)
		else:
			gs.active_job_id = ""
			# The standing was with them, not with you.
			rec["xp"] = 0.0
			rec["rank"] = 0
			rec["hired_day"] = -1
			gs.job_missed.erase(job_id)
			gs.log_activity("%s is done with you. Three days and nobody heard from you." % job["name"], RED)
			# Canon broadcasts this on BOTH channels the block hears — losing a
			# job is household news and street news at the same time.
			var exposure: Node = _exposure()
			if exposure != null:
				for channel in ["household", "neighborhood"]:
					exposure.broadcast_observation({
						"type": "financial", "event": "job_lost",
						"location": gs.current_district_id, "channel": channel,
					})
	elif missed == MISSED_FINAL_WARNING:
		gs.log_activity("%s: last warning about attendance." % job["name"], RED)
		if phone != null and manager.has("missed_final"):
			phone.push_text(str(manager["name"]), str(manager["missed_final"]), "manager_missed_final")
	elif missed == MISSED_FIRST_WARNING:
		gs.log_activity("%s noticed you weren't in." % job["name"], AMBER)
		if phone != null and manager.has("missed_first"):
			phone.push_text(str(manager["name"]), str(manager["missed_first"]), "manager_missed_first")
