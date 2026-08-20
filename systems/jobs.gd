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
## starter set, Exposure broadcasts.

## Canon thresholds. Warnings at 1 and 2, gone at 3.
const MISSED_FIRST_WARNING := 1
const MISSED_FINAL_WARNING := 2
const MISSED_FIRING := 3

const GREEN := Color(0.451, 0.722, 0.404)
const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)

var gs: Node
var rng: Node
var time_system: RefCounted

func setup(game_state: Node, rng_manager: Node, time: RefCounted) -> void:
	gs = game_state
	rng = rng_manager
	time_system = time
	gs.day_crossed.connect(_on_day_crossed)


## The exposure layer, or null before it exists. Every system reaches it the
## same way so the null-check lives in one shape rather than five.
func _exposure() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Exposure")

func _curtis_node() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Curtis")

func can_handle(action: String) -> bool:
	return action in ["apply_job", "work_shift", "quit_job"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"apply_job":
			return _apply(str(payload.get("job_id", "")))
		"work_shift":
			return _work(str(payload.get("approach", "work_hard")))
		"quit_job":
			return _quit()
	return {"ok": false, "reason": "Unknown job action."}

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

	gs.active_job_id = job_id
	if not gs.job_records.has(job_id):
		gs.job_records[job_id] = {"xp": 0.0, "rank": 0, "last_worked_day": -1, "hired_day": gs.day}
	else:
		gs.job_records[job_id]["hired_day"] = gs.day
	gs.job_missed[job_id] = 0
	gs.log_activity("Hired on at %s." % job["name"], GREEN)
	return {"ok": true, "hired": job["name"]}

func _quit() -> Dictionary:
	if gs.active_job_id.is_empty():
		return {"ok": false, "reason": "You don't have a job."}
	var name: String = gs.active_job().get("name", "the job")
	gs.active_job_id = ""
	gs.log_activity("Quit %s." % name, AMBER)
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

	gs.cash += payout
	gs.health = clampi(gs.health + int(approach["health"]), 1, gs.health_max)

	var rec: Dictionary = gs.job_records[job_id]
	rec["xp"] = float(rec.get("xp", 0.0)) + float(approach["xp"])
	var old_rank: int = int(rec.get("rank", 0))
	rec["rank"] = gs.job_rank_for_xp(float(rec["xp"]))
	rec["last_worked_day"] = gs.day
	# Working resets the attendance ladder, whatever rung it was on.
	gs.job_missed[job_id] = 0

	gs.log_activity("%s shift: +$%d." % [job["name"], payout], GREEN)
	# Canon tags WORK_SHIFT as presence/steady_work on the neighbourhood channel.
	var exposure: Node = _exposure()
	if exposure != null:
		exposure.broadcast_observation({
			"type": "presence", "event": "steady_work",
			"location": gs.current_district_id, "channel": "neighborhood",
		})
	var ranked_up: bool = int(rec["rank"]) > old_rank
	if ranked_up:
		gs.log_activity("%s moved you up to rank %d." % [job["name"], int(rec["rank"])], GREEN)

	# A shift is a slot, the same as any other district action.
	time_system.handle("advance_time", {})
	return {"ok": true, "payout": payout, "ranked_up": ranked_up}

## Attendance settles when a day ends. Canon runs this inside the day-end
## settlement, counting the day that just finished.
func _on_day_crossed() -> void:
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
	var ended_day: int = gs.day - 1
	if int(rec.get("last_worked_day", -1)) == ended_day:
		return
	# Grace on the day you were hired.
	if int(rec.get("hired_day", -1)) == ended_day:
		return

	var missed: int = int(gs.job_missed.get(job_id, 0)) + 1
	gs.job_missed[job_id] = missed

	if missed >= MISSED_FIRING:
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
			gs.log_activity("%s let you go for not showing up." % job["name"], RED)
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
	elif missed == MISSED_FIRST_WARNING:
		gs.log_activity("%s noticed you weren't in." % job["name"], AMBER)
