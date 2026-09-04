extends RefCounted
## Job managers -- every job is a person (The World Speaks, PR 4, WS-D4).
##
## A job used to be a name and a pay band. Now somebody runs it: they hire
## you in two or three lines, they text you when you don't show, and every
## three or four shifts something small happens on the floor. The pay bands
## are content and were re-cut so the jobs actually differ; the mechanics
## underneath (band, rank scaling, approach multiplier, attendance ladder)
## are untouched.
##
## Voices: Lani (Wash & Go) calls everybody baby and means it. Marcus
## (Spenard Chevron, nights) says as little as the shift lets him. Mina is
## Mina -- careful, short. The rest are drawn to fit the building. Day
## labor has nobody: a truck stops, somebody nods, cash at the end.
##
## `night_bonus` is a flat differential on the NIGHT slot. `regular_bonus`
## is a flat bump once you have worked `regular_after` shifts -- the Night
## Owl's version of becoming somebody's regular.

const MANAGERS := {
	"wash_go": {
		"name": "Lani", "title": "runs the Wash & Go",
		"hire": [
			"Lani looks you up and down over the counter, then past you at the door.",
			"\"Yalonda's people? Ok baby. It's minimum, but I pay every day, cash, and nobody bothers you here.\"",
			"\"Be here when you say you'll be here. That's the whole job.\"",
		],
		"perk": "Cash every day. Nobody bothers you.",
		"micro": [
			{"text": "Lani slides you a plate from the back. \"Eat, baby. You look like you don't.\"", "health": 2},
			{"text": "A dryer eats a man's quarters and he wants to fight the machine. You talk him down. Lani watches the whole thing and doesn't say a word, which is how she says thank you.", "cash": 10},
			{"text": "Slow night. Lani tells you about the first year she opened, when the pipes froze in January and she washed the towels in her tub. \"Everybody starts somewhere, baby.\"", "cash": 0},
			{"text": "Somebody left a jacket. Lani goes through the pockets, then hands you the twenty. \"Finder's.\"", "cash": 20},
		],
		"missed_first": "Baby where you at? Had to run the floor myself.",
		"missed_final": "Two days. I like you, but I don't run a charity. Tomorrow or don't.",
		"fired": "Lani doesn't yell. She takes the key back off your ring and says \"Ok baby,\" and that is worse.",
		"fired_text": "Took you off the board. Come see me when you get it together. Not before.",
	},
	"spenard_chevron": {
		"name": "Marcus", "title": "night manager",
		"night_bonus": 12,
		"hire": [
			"Marcus doesn't look up from the register.",
			"\"Nights pay more because nights are worse. Drunks, kids, somebody's cousin trying to walk out with a case.\"",
			"\"You handle it or you call me. Don't call me.\"",
		],
		"perk": "Nights pay a differential.",
		"micro": [
			{"text": "Three in the morning. A man in a hospital bracelet buys a single beer and a lottery ticket and tells you his whole life. You listen. Marcus, from the back: \"You get used to it.\"", "cash": 0},
			{"text": "A kid palms a Red Bull and you let it go, because it's a Red Bull. Marcus saw. He says nothing, and rings you out ten short at the end of the night.", "cash": -10},
			{"text": "Pump 4 drives off on a full tank. Marcus writes the plate down without looking at it. \"Third time this month. He'll be back. They're always back.\"", "cash": 0},
			{"text": "Marcus locks the door for ten minutes and lets you sit. \"You're all right,\" he says. From him, that's a raise.", "health": 2},
		],
		"missed_first": "You weren't on the schedule last night. You were.",
		"missed_final": "Two. I don't do three.",
		"fired": "Marcus hands you your last envelope through the window without opening the door.",
		"fired_text": "Don't come back. Nothing personal. That's the count.",
	},
	"rebel_convenience": {
		"name": "Sonny", "title": "owns the Rebel",
		"hire": [
			"Sonny counts your hands before he looks at your face.",
			"\"Register's short, you're short. That's the rule. Otherwise, easy. Sit, sell, don't let them smoke by the door.\"",
		],
		"perk": "Any shift. Simple rules.",
		"micro": [
			{"text": "Sonny's daughter does her homework on the counter next to you for two hours. She corrects your math. Sonny grins.", "cash": 0},
			{"text": "The ice machine goes and Sonny hands you a wrench like you'd know what to do. You figure it out. He gives you fifteen and doesn't say for what.", "cash": 15},
			{"text": "A regular comes in every day at four for one thing. Today he doesn't come. Sonny looks at the door at four, then at four-fifteen. Nobody says anything.", "cash": 0},
		],
		"missed_first": "no show no pay. tomorrow?",
		"missed_final": "two days. one more and the shift is somebody else's",
		"fired": "Sonny has already put the ad back in the window.",
		"fired_text": "gave the shift to my nephew. good luck",
	},
	"northern_value": {
		"name": "Denise", "title": "floor lead",
		"hire": [
			"Denise hands you a vest that fit somebody else.",
			"\"Floor, freight, whatever's on fire. Break is fifteen and I count.\"",
			"\"You'll be fine. Everybody's fine till they're not.\"",
		],
		"perk": "Days only. Steadiest check in Spenard.",
		"micro": [
			{"text": "A pallet of dog food comes off the truck wrong and you catch it before it catches somebody. Denise: \"That's why you're on days.\"", "health": -1, "cash": 10},
			{"text": "A woman pays for diapers in quarters, counting twice. You wait. Denise, behind you, waits too. Nobody hurries her.", "cash": 0},
			{"text": "Denise catches you on your phone and takes your fifteen off the top. Then she gives you a store coupon for a rotisserie chicken. Both things are her.", "health": 1},
			{"text": "Somebody from your old life comes through the line and pretends not to know you. You ring them up. Denise clocks it and says nothing.", "cash": 0},
		],
		"missed_first": "You were on the schedule today. Call me.",
		"missed_final": "Second no-call. Third is automatic. That's corporate, not me.",
		"fired": "Denise walks you to the door the way she'd walk anybody. \"Take the vest off before you go out. It's the rule.\"",
		"fired_text": "System terminated you this morning. Nothing I could do. Take care of yourself.",
	},
	"night_owl": {
		"name": "Mina", "title": "the counter",
		"regular_after": 4, "regular_bonus": 5,
		"hire": [
			"Mina slides an apron across the counter without looking up.",
			"\"It's not much. But you're next to me, and I pay out of the drawer at close.\"",
			"\"Don't make me regret it.\"",
		],
		"perk": "Next to Mina. After a few nights, you're her regular.",
		"micro": [
			{"text": "Dead hour. Mina makes two coffees and doesn't ask how you take yours. She already knows.", "cash": 0},
			{"text": "A man at the counter won't stop talking to Mina. You move one stool closer. He finishes his coffee and leaves. She doesn't thank you, and she doesn't have to.", "cash": 0},
			{"text": "Close. Mina counts the drawer twice, then splits the tip jar down the middle without counting that.", "cash": 12},
			{"text": "Mina tells you which regulars pay and which ones only talk. She's never told anybody that.", "cash": 0},
		],
		"missed_first": "you werent here tonight. its fine. just tell me next time",
		"missed_final": "two nights. i covered. i wont cover a third",
		"fired": "Mina takes you off the schedule. She does it kindly, which is the part that lands.",
		"fired_text": "i took you off the schedule. its ok. come by when youre ready. as a customer",
	},
	"juan_warehouse": {
		"name": "Ray", "title": "dock foreman",
		"hire": [
			"Ray shakes your hand like he's testing it.",
			"\"Juan says you're solid. Dock starts at six. Lift with your legs, don't talk to the drivers.\"",
			"\"You'll make more here than anywhere in Spenard that doesn't get you arrested.\"",
		],
		"perk": "Mornings. The best legal money in Spenard.",
		"micro": [
			{"text": "A driver from Wasilla tries to argue a count. Ray lets you handle it. You handle it. He nods once.", "cash": 15},
			{"text": "Juan works the same shift and doesn't say a word to you for four hours, then buys you a Gatorade. Roommates.", "health": 2},
			{"text": "Ray pulls you off the line to run a forklift you've never touched. \"You'll learn.\" You do, mostly.", "health": -2, "cash": 20},
			{"text": "Lunch. Ray talks about the year the port shut and half the dock went to Prudhoe. \"You stay where the money is. It's not always here.\"", "cash": 0},
		],
		"missed_first": "Truck came at six. You didn't. Juan vouched for you.",
		"missed_final": "Two. I told Juan. Don't make me say three.",
		"fired": "Ray doesn't give you the speech. He gives it to Juan, and Juan gives it to you.",
		"fired_text": "You're off the dock. I'm sorry to do it. Juan will hear about it from me, not you.",
	},
	"ship_creek": {
		"name": "Big Mike", "title": "freight",
		"hire": [
			"Big Mike checks a clipboard with your name spelled wrong on it.",
			"\"Freight don't wait. You're late, the truck leaves, you don't get paid.\"",
			"\"On time every day for a month, I put you on the good route.\"",
		],
		"perk": "Mornings only. The biggest check in the game, if you can hold the hours.",
		"micro": [
			{"text": "Wind off the inlet cuts through the coat you thought was warm. Mike tosses you a pair of gloves off the truck. \"Keep 'em.\"", "health": 1},
			{"text": "A container manifest doesn't match. Mike watches to see if you say something. You say something.", "cash": 25},
			{"text": "Four a.m. and the light is coming up over the water and for one minute nobody says anything, and it's the best part of the day.", "health": 2},
			{"text": "Mike puts you on the good route for a day. It's the same route with a heater that works.", "cash": 20},
		],
		"missed_first": "Truck left without you. That's a day's pay you didn't make.",
		"missed_final": "Two. I've got a list of people who want this shift.",
		"fired": "Big Mike crosses your name off the clipboard with the same pen he wrote it with.",
		"fired_text": "You're off the crew. I don't do it twice.",
	},
	"day_labor": {
		"name": "", "title": "",
		"hire": [
			"The truck stops. Somebody in the back nods you in.",
			"Cash at the end of the day. No names, no schedule, no questions in either direction.",
		],
		"perk": "No schedule. No boss. No future.",
		"micro": [],
	},
}

static func manager_for(job_id: String) -> Dictionary:
	return MANAGERS.get(job_id, {})

static func has_manager(job_id: String) -> bool:
	return not str(manager_for(job_id).get("name", "")).is_empty()

## Every three or four shifts something happens on the floor. Seeded on the
## shift count so it replays.
static func micro_event_due(shifts: int, last_event_shift: int) -> bool:
	if shifts < 3:
		return false
	var gap: int = 3 if (shifts % 2 == 1) else 4
	return shifts - last_event_shift >= gap

static func micro_event(job_id: String, shifts: int) -> Dictionary:
	var events: Array = manager_for(job_id).get("micro", [])
	if events.is_empty():
		return {}
	return events[(shifts / 3) % events.size()]
