extends RefCounted
## Obligations — the bills that arrive whether or not you earned anything.
##
## Ported from the web build's day-end settlement (game-core.js ~5518-5570,
## householdWarning at 6397). Two clocks run:
##
##   Rent — $150 to Yalonda every 7 days, for the spare room the run opens in.
##   Canon does NOT auto-deduct it; rent is paid deliberately, and a due day that
##   passes unpaid is a miss. Two missed weeks earn a household warning, and
##   three warnings is eviction — the game's primary lose condition.
##
##   Phone — $75. Once past due the counter climbs, and after two days of grace
##   the line goes dead. Paying restores it.
##
## Not ported (each its own feature): Deshawn's grace that defers a miss by a
## day, contraband and danger-brought-home as warning sources, Yalonda's trust
## and Exposure observations.

const RED := Color(0.827, 0.161, 0.125)
const AMBER := Color(0.882, 0.651, 0.227)
const BLUE := Color(0.373, 0.663, 0.847)

## Canon: phone.daysPastDue > 2 kills the line.
const PHONE_GRACE_DAYS := 2
const RENT_PERIOD_DAYS := 7
## Both happen to be 7 in canon, but they are separate clocks — paying the phone
## bill sets billDueDay = day + 7 independently of the rent period.
const PHONE_PERIOD_DAYS := 7

var gs: Node
var phone: RefCounted
## Reached for the wallet. Rent and the phone bill are the two spends
## TI-003 §6 names as high-visibility, so both go through it.
var gm: Node

func setup(game_state: Node, phone_system: RefCounted, manager: Node) -> void:
	gs = game_state
	phone = phone_system
	gm = manager
	# Driven by DayLifecycle in declared order. See systems/day_lifecycle.gd.

func can_handle(action: String) -> bool:
	return action in ["pay_rent", "pay_phone_bill"]

func handle(action: String, payload: Dictionary) -> Dictionary:
	match action:
		"pay_rent":
			return _pay_rent()
		"pay_phone_bill":
			return _pay_phone(payload)
	return {"ok": false, "reason": "Unknown obligation action."}

func _pay_rent() -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	if gs.cash < gs.WEEKLY_RENT:
		return {"ok": false, "reason": "Need $%d for rent." % gs.WEEKLY_RENT}
	# TI-003 §6 names rent as high-visibility: it is paid to somebody who keeps
	# records, so clean money goes first and dirty money above $400 is what
	# Financial Pressure measures.
	var wallet: Object = gm.system("wallet")
	wallet.spend(gs.WEEKLY_RENT, wallet.HIGH_VISIBILITY_CLEAN_FIRST,
		{"source_id": "rent"})
	# Paying rolls the due day forward a full period, which is what makes the
	# nightly check go quiet.
	gs.rent_due_day = _current_rent_due() + RENT_PERIOD_DAYS
	var was_late: bool = int(gs.rent_arrears_day) >= 0
	gs.rent_arrears_day = -1
	gs.log_activity("Rent, $%d, in the envelope on the table. Yalonda doesn't count it in front of you." % gs.WEEKLY_RENT, BLUE)
	# Yalonda's lens gives rent_paid its own event weight of 3.0, well above the
	# financial category — paying her is the single loudest good thing she sees.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null:
		exposure.record_observation("yalonda", {"type": "financial", "event": "rent_paid", "source": "household"})
		# OG-D1: late is accepted, and remembered.
		if was_late:
			exposure.record_observation("yalonda", {"type": "financial", "event": "rent_late", "source": "household"})
	if was_late and phone != null:
		phone.push_text("Yalonda", "You got it. Don't make this a habit.", "yalonda_rent_paid_late")
	return {"ok": true}

## Canon PAY_PHONE_BILL (game-core.js:7846). Three things the first pass of this
## port got wrong, corrected here against the oracle:
##
##  1. **You cannot pay early.** Canon gates on `due` — the day has reached the
##     bill date, or the counter is already running, or the line is dead. Paying
##     a week ahead to bank a due day is not a move the game offers.
##  2. **Paying does not turn the phone back on.** It stamps the current absolute
##     slot into `reactivateAtSlot`; the next slot advance flips it (see
##     phone.restore_if_ready). The old immediate restore skipped the beat the
##     carrier takes, and skipped the held-inbox flush that rides with it.
##  3. **The due day rolls off TODAY, not off the old due day.** Rent rolls in
##     whole periods from the date it was owed; the phone bill just moves a week
##     out from when you paid it. They are separate clocks that both happen to
##     be 7 days long.
##
## `surface` is canon's, and canon only reads it to refuse an ONLINE payment
## without a laptop, an active line, and knowledge of 907List. No laptop item
## exists in this build, so the online surface is not offered and the reducer
## does not gate on it; "store" and "phone" both land here. The one behavioural
## difference canon keeps between them is time cost — paying at the Phone Store
## is a world action that burns a slot — and this build has no store screen to
## spend it from yet, so both are free. Named, not silently dropped.
func _pay_phone(payload: Dictionary) -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	var due: bool = gs.day >= gs.phone_due_day or gs.phone_days_past_due > 0 or not gs.phone_active
	if not due:
		return {"ok": false, "reason": "Due Day %d." % gs.phone_due_day}
	if gs.cash < gs.PHONE_BILL:
		return {"ok": false, "reason": "Need $%d for the phone bill." % gs.PHONE_BILL}
	# High-visibility for the same reason as rent (TI-003 §6): a billed account
	# in your name is a record.
	var wallet: Object = gm.system("wallet")
	wallet.spend(gs.PHONE_BILL, wallet.HIGH_VISIBILITY_CLEAN_FIRST,
		{"source_id": "phone_bill"})
	gs.phone_due_day = gs.day + PHONE_PERIOD_DAYS
	gs.phone_days_past_due = 0
	if not gs.phone_active:
		gs.phone_reactivate_at_slot = phone.now_slot_number()
	gs.log_activity("Phone bill, $%d. The line stays on." % gs.PHONE_BILL, BLUE)
	return {"ok": true, "surface": str(payload.get("surface", "phone"))}

## Why the Pay button is dead, in canon's own words (the `reason` strings on
## phoneBills' rows, ui.built.js:15738). Empty means the payment will go through.
##
## `surface` matters here in a way it does not in the reducer: canon's Bills row
## sits ON the phone, so it refuses while the line is dead and points at the
## Phone Store instead. The store's own button has no such check — that is the
## whole point of walking there.
func pay_phone_blocker(surface: String = "phone") -> String:
	if gs.game_over:
		return "The run is over"
	if surface != "store":
		if not gs.phone_active:
			return "Pay at the Phone Store"
		if gs.day < gs.phone_due_day and gs.phone_days_past_due == 0:
			return "Due Day %d" % gs.phone_due_day
	if gs.cash < gs.PHONE_BILL:
		return "Need $%d" % gs.PHONE_BILL
	return ""

func pay_rent_blocker() -> String:
	if gs.game_over:
		return "The run is over"
	if gs.day < gs.rent_due_day:
		return "Due Day %d" % gs.rent_due_day
	if gs.cash < gs.WEEKLY_RENT:
		return "Need $%d" % gs.WEEKLY_RENT
	return ""

## Canon's currentRentDue: the due day, rolled forward in whole periods for as
## long as it has been sitting unpaid.
func _current_rent_due() -> int:
	var due: int = gs.rent_due_day
	if gs.day < due:
		return due
	return due + int(floor(float(gs.day - due) / float(RENT_PERIOD_DAYS))) * RENT_PERIOD_DAYS

## True when rent is owed right now — the Home screen uses this to show pressure.
func rent_is_due() -> bool:
	return gs.day >= gs.rent_due_day

func days_until_rent() -> int:
	return gs.rent_due_day - gs.day

## Settlement is about the day that just ENDED, not the one starting. Canon gates
## it behind a dayEndPending step for the same reason: a bill due on day 7 has to
## be payable during day 7. Comparing against gs.day would mark it missed the
## instant the day began.
## Rent and the phone bill for the day that just ended. Settled LAST in the
## declared order: these are what end a run, so everything that could still pay
## them has already had its turn.
func settle_night(ended_day: int) -> void:
	if gs.game_over:
		return
	_settle_phone(ended_day)
	_settle_rent(ended_day)

func _settle_phone(ended_day: int) -> void:
	if ended_day < gs.phone_due_day:
		return
	gs.phone_days_past_due += 1
	if gs.phone_days_past_due > PHONE_GRACE_DAYS and gs.phone_active:
		gs.phone_active = false
		gs.log_activity("The bars go. Everything you typed today is sitting in the phone, not sent.", RED)
	elif gs.phone_days_past_due == 1:
		gs.log_activity("$%d phone bill, overdue. The carrier texts you about it, which is funny for one more day." % gs.PHONE_BILL, AMBER)

## OG-D1 (1.0.0): the rent day does not come and go. The night it passes
## unpaid Yalonda texts, firm; a day late is a feed line and a point with
## her; two days is a second text, angrier, and Juan mentions it; three is
## the house warning, and every three after. Paying late is accepted and
## remembered. `rent_arrears_day` is the clock; paying clears it.
const ARREARS_WARNING_EVERY := 3

func _settle_rent(ended_day: int) -> void:
	if ended_day < gs.rent_due_day:
		_settle_arrears(ended_day)
		return
	gs.rent_missed += 1
	if int(gs.rent_arrears_day) < 0:
		gs.rent_arrears_day = int(gs.rent_due_day)
	# Roll the due day so the next period is what gets checked from here.
	gs.rent_due_day = _current_rent_due() + RENT_PERIOD_DAYS
	gs.log_activity("The rent envelope is on the table where you left it. Yalonda moved it two inches closer to your door.", RED)
	var phone_now: Object = phone
	if phone_now != null:
		phone_now.push_text("Yalonda", "Rent was due today. I haven't seen it. I'll see it tomorrow.",
			"yalonda_rent_due")
	# Canon's ESCALATING_EVENT: the weight is negative and the count grows
	# linearly, so each additional miss hurts more than the last. Yalonda is the
	# one who sees it, first-hand, in her own house.
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if exposure != null:
		exposure.record_observation("yalonda", {"type": "financial", "event": "missed_obligation", "source": "household"})
	# Canon: two unpaid weeks is what makes the house warning explicit.
	if gs.rent_missed >= 2:
		_household_warning("Two rent weeks pass unpaid. Yalonda makes the house warning explicit.")

## The days after the due day, while it stays unpaid.
func _settle_arrears(ended_day: int) -> void:
	if int(gs.rent_arrears_day) < 0:
		return
	var late: int = ended_day - int(gs.rent_arrears_day)
	if late < 1:
		return
	var exposure: Node = Engine.get_main_loop().root.get_node_or_null("/root/Exposure")
	if late == 1:
		gs.log_activity("A day late on the rent. Yalonda hasn't said anything, which is how you know she noticed.", RED)
		if exposure != null:
			exposure.record_observation("yalonda", {"type": "financial", "event": "missed_obligation", "source": "household"})
		return
	if late == 2:
		if phone != null:
			phone.push_text("Yalonda", "Two days. I don't chase people for money. I change locks.", "yalonda_rent_late")
			phone.push_text("Juan", "yalonda asked me if youre good for it. i said yeah. dont make me a liar", "juan_rent")
		return
	if late % ARREARS_WARNING_EVERY == 0:
		_household_warning("%d days late on the rent. Yalonda says the next conversation is about the room." % late)

func _household_warning(reason: String) -> void:
	gs.household_warnings += 1
	gs.log_activity("%s (warning %d/%d)" % [reason, gs.household_warnings, gs.HOUSEHOLD_WARNING_LIMIT], RED)
	if gs.household_warnings >= gs.HOUSEHOLD_WARNING_LIMIT:
		gs.game_over = true
		# Canon names the specific obligation that broke, because that is what
		# the player needs told.
		gs.game_over_reason = reason
