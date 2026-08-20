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

func setup(game_state: Node) -> void:
	gs = game_state
	gs.day_crossed.connect(_on_day_crossed)

func can_handle(action: String) -> bool:
	return action in ["pay_rent", "pay_phone_bill"]

func handle(action: String, _payload: Dictionary) -> Dictionary:
	match action:
		"pay_rent":
			return _pay_rent()
		"pay_phone_bill":
			return _pay_phone()
	return {"ok": false, "reason": "Unknown obligation action."}

func _pay_rent() -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	if gs.cash < gs.WEEKLY_RENT:
		return {"ok": false, "reason": "Need $%d for rent." % gs.WEEKLY_RENT}
	gs.cash -= gs.WEEKLY_RENT
	# Paying rolls the due day forward a full period, which is what makes the
	# nightly check go quiet.
	gs.rent_due_day = _current_rent_due() + RENT_PERIOD_DAYS
	gs.log_activity("Rent paid: -$%d." % gs.WEEKLY_RENT, BLUE)
	return {"ok": true}

func _pay_phone() -> Dictionary:
	if gs.game_over:
		return {"ok": false, "reason": "The run is over."}
	if gs.cash < gs.PHONE_BILL:
		return {"ok": false, "reason": "Need $%d for the phone bill." % gs.PHONE_BILL}
	gs.cash -= gs.PHONE_BILL
	gs.phone_due_day = gs.day + PHONE_PERIOD_DAYS
	gs.phone_days_past_due = 0
	var was_dead: bool = not gs.phone_active
	gs.phone_active = true
	gs.log_activity("Phone bill paid: -$%d." % gs.PHONE_BILL, BLUE)
	if was_dead:
		gs.log_activity("The bars come back.", BLUE)
	return {"ok": true}

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
func _on_day_crossed() -> void:
	if gs.game_over:
		return
	var ended_day: int = gs.day - 1
	_settle_phone(ended_day)
	_settle_rent(ended_day)

func _settle_phone(ended_day: int) -> void:
	if ended_day < gs.phone_due_day:
		return
	gs.phone_days_past_due += 1
	if gs.phone_days_past_due > PHONE_GRACE_DAYS and gs.phone_active:
		gs.phone_active = false
		gs.log_activity("The signal bars vanish. Calls and texts stop leaving.", RED)
	elif gs.phone_days_past_due == 1:
		gs.log_activity("Phone bill overdue: $%d." % gs.PHONE_BILL, AMBER)

func _settle_rent(ended_day: int) -> void:
	if ended_day < gs.rent_due_day:
		return
	gs.rent_missed += 1
	# Roll the due day so the next period is what gets checked from here.
	gs.rent_due_day = _current_rent_due() + RENT_PERIOD_DAYS
	gs.log_activity("Yalonda leaves the rent envelope on the table, still empty.", RED)
	# Canon: two unpaid weeks is what makes the house warning explicit.
	if gs.rent_missed >= 2:
		_household_warning("Two rent weeks pass unpaid. Yalonda makes the house warning explicit.")

func _household_warning(reason: String) -> void:
	gs.household_warnings += 1
	gs.log_activity("%s (warning %d/%d)" % [reason, gs.household_warnings, gs.HOUSEHOLD_WARNING_LIMIT], RED)
	if gs.household_warnings >= gs.HOUSEHOLD_WARNING_LIMIT:
		gs.game_over = true
		# Canon names the specific obligation that broke, because that is what
		# the player needs told.
		gs.game_over_reason = reason
