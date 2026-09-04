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
		"performance_attribute": "charisma",
		"tiers": ["Attendant", "Keyholder", "Closer"],
		"interview_text": "Baby come by tomorrow and let me look at you. Bring your hands.",
		"questions": [
			{"q": "\"Yalonda's people. Ok. Why here, baby? It's a laundromat.\"",
			 "a": {"text": "Because it's yours, and she said you're fair.", "score": 1, "say": "\"Mm. She talks too much. Sit down.\""},
			 "b": {"text": "Because I need the money.", "score": 0, "say": "\"Honest. Ok. Everybody does.\""}},
			{"q": "\"Man comes in drunk at two in the morning and wants his quarters back. What do you do?\"",
			 "a": {"text": "Give him his quarters and walk him out.", "score": 1, "say": "\"That's right. Quarters are cheaper than police.\""},
			 "b": {"text": "Tell him the machine's not mine.", "score": -1, "say": "\"Baby everything in here is mine.\""}},
			{"q": "\"Can you be here when you say you'll be here?\"",
			 "a": {"text": "Every time.", "score": 1, "say": "\"We'll see. Everybody says that.\""},
			 "b": {"text": "Most of the time.", "score": 0, "say": "\"At least you're honest, baby.\""}},
		],
		"promotion_lines": [
			"Lani puts a key on the counter and slides it across. \"Keyholder. Don't make me take it back, baby.\"",
			"Lani hands you the deposit bag. \"You close. I go home. That's the whole promotion.\"",
		],
		"social": [
			"Miss Pat, who has done her washing here every Tuesday since before you were born, tells you your shirt is wrong. She is right.",
			"A man named Junior teaches you the trick with the change machine. Lani pretends not to see.",
			"Lani's grandson does homework on the folding table and asks if you know any rappers. You do not.",
		],
		"overhear": [
			"Two women folding towels: somebody's cousin got picked up on Northern Lights. Somebody else says the cops are sitting on Spenard Road this week.",
			"A man on the phone by the dryers: Ship Creek is hiring again and paying cash on Fridays.",
			"Somebody says Goodie raised his prices. Somebody else says Goodie always says that.",
		],
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
		"hire_text": "Ok baby. You're on. Come in tomorrow, early, and I'll show you the machines.",
		"reject_text": "Baby I went with somebody who could start today. Come back next month, I mean it.",
		"missed_first": "Baby where you at? Had to run the floor myself.",
		"missed_final": "Two days. I like you, but I don't run a charity. Tomorrow or don't.",
		"fired": "Lani doesn't yell. She takes the key back off your ring and says \"Ok baby,\" and that is worse.",
		"fired_text": "Took you off the board. Come see me when you get it together. Not before.",
	},
	"spenard_chevron": {
		"performance_attribute": "intelligence",
		"tiers": ["Clerk", "Night Clerk", "Assistant Manager"],
		"interview_text": "Come by the station tonight after ten. Ask for Marcus.",
		"questions": [
			{"q": "\"Why nights?\"",
			 "a": {"text": "Nights pay more and I don't sleep anyway.", "score": 1, "say": "\"Neither do I.\""},
			 "b": {"text": "Days were full.", "score": 0, "say": "\"They usually are.\""}},
			{"q": "\"Kid walks out with a case of beer. You chase him?\"",
			 "a": {"text": "No. I write down what he looks like.", "score": 1, "say": "\"Right answer. Beer's insured. You're not.\""},
			 "b": {"text": "Yeah. Nobody steals from me.", "score": -1, "say": "\"It's not from you. That's the thing you have to learn.\""}},
			{"q": "\"Register's short twenty at the end of the shift. Whose fault?\"",
			 "a": {"text": "Mine, until I can show you it isn't.", "score": 1, "say": "\"Ok.\""},
			 "b": {"text": "Depends who was on before me.", "score": 0, "say": "\"That's what they all say. Sometimes they're right.\""}},
		],
		"promotion_lines": [
			"Marcus hands you the night keys without looking up. \"Night clerk. Same job. More keys.\"",
			"Marcus: \"They want an assistant manager. I told them you. Don't make me a liar.\"",
		],
		"social": [
			"A trucker from the Valley talks to you for forty minutes about a moose. Marcus lets you.",
			"The regular who buys one scratcher every night at eleven wins forty dollars and gives you five of it.",
			"Marcus tells you, in the fewest words possible, about the year he did on the slope.",
		],
		"overhear": [
			"Two guys at the pumps: somebody is moving weight through Muldoon and the price downtown dropped because of it.",
			"A cop buys coffee and says to his partner that they're doubling the Spenard Road patrol this weekend.",
			"A kid on the phone: Curtis's people were asking about somebody new. He doesn't say who.",
		],
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
		"hire_text": "Nights. Ten to six. Don't be late the first one.",
		"reject_text": "Not this time.",
		"missed_first": "You weren't on the schedule last night. You were.",
		"missed_final": "Two. I don't do three.",
		"fired": "Marcus hands you your last envelope through the window without opening the door.",
		"fired_text": "Don't come back. Nothing personal. That's the count.",
	},
	"rebel_convenience": {
		"performance_attribute": "intelligence",
		"tiers": ["Counter", "Keyholder", "Manager"],
		"interview_text": "come by tomorrow. bring ID. sonny",
		"questions": [
			{"q": "Sonny counts your hands. \"You ever run a register?\"",
			 "a": {"text": "Yes. Two years at a Fred Meyer outside.", "score": 1, "say": "\"Outside. Ok. Here is smaller and worse.\""},
			 "b": {"text": "No, but I count fast.", "score": 0, "say": "\"We'll see how fast.\""}},
			{"q": "\"Guys smoke by the door. You say what?\"",
			 "a": {"text": "Not here, fellas. Then I mean it.", "score": 1, "say": "\"Good. Mean it every time.\""},
			 "b": {"text": "Nothing. It's cold out.", "score": -1, "say": "\"Then they smoke by my door forever.\""}},
			{"q": "\"Register is short, you're short. You understand that?\"",
			 "a": {"text": "I understand it. I won't be short.", "score": 1, "say": "\"Ok ok.\""},
			 "b": {"text": "What if it's the machine?", "score": 0, "say": "\"The machine has never once been short.\""}},
		],
		"promotion_lines": [
			"Sonny gives you a key and a warning in the same breath. \"Keyholder. My nephew is mad. Good.\"",
			"Sonny: \"You run it Sundays now. I'm going fishing. Don't burn it down.\"",
		],
		"social": [
			"Sonny's daughter beats you at cards on the counter and takes your last dollar with great seriousness.",
			"A regular tells you the Rebel used to be a video store, and before that a bar, and before that nothing.",
			"Sonny shows you a photo of the store the day he bought it. He does not say anything. He does not need to.",
		],
		"overhear": [
			"Two men by the coolers: pills are up because a pharmacy on Northern Lights got strict.",
			"A woman on her phone says the police have a car sitting on the lot at the Chevron every night now.",
			"Somebody says a guy named Dre is fronting money to anybody who asks, and somebody else says that's the problem.",
		],
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
		"hire_text": "ok you start tomorrow. dont be late and dont let them smoke by the door",
		"reject_text": "my nephew wants the hours. sorry",
		"missed_first": "no show no pay. tomorrow?",
		"missed_final": "two days. one more and the shift is somebody else's",
		"fired": "Sonny has already put the ad back in the window.",
		"fired_text": "gave the shift to my nephew. good luck",
	},
	"northern_value": {
		"performance_attribute": "intelligence",
		"tiers": ["Floor", "Lead", "Department Lead"],
		"interview_text": "Interview tomorrow at 9. Ask for Denise at customer service. Wear closed shoes.",
		"questions": [
			{"q": "\"Corporate asks me to ask: why Northern Value?\"",
			 "a": {"text": "Because it's steady, and I need steady.", "score": 1, "say": "\"That's the answer. Nobody says it.\""},
			 "b": {"text": "Because you're hiring.", "score": 0, "say": "\"Fair.\""}},
			{"q": "\"A pallet comes off the truck wrong. Your coworker is under it. What's first?\"",
			 "a": {"text": "The coworker.", "score": 1, "say": "\"Yes. Then the paperwork.\""},
			 "b": {"text": "Stop the truck.", "score": 0, "say": "\"The truck already stopped.\""}},
			{"q": "\"Break is fifteen minutes. I count. That a problem?\"",
			 "a": {"text": "No. Fifteen is fifteen.", "score": 1, "say": "\"Good.\""},
			 "b": {"text": "Depends how the day's going.", "score": -1, "say": "\"It's fifteen regardless of the day.\""}},
		],
		"promotion_lines": [
			"Denise hands you a different vest. This one fits. \"Lead. It's fifty cents an hour and everybody's problems.\"",
			"Denise: \"Department lead. Corporate signed it. I signed it first.\"",
		],
		"social": [
			"The woman who runs the fitting rooms has worked here nineteen years and knows everybody in Spenard by their pants size.",
			"A coworker named Tavita shows you a picture of his church's choir. He's the tall one. They're all the tall one.",
			"Denise eats lunch alone in her car. You knock. She lets you in. Neither of you says much.",
		],
		"overhear": [
			"Two cashiers: somebody's brother got stopped at a checkpoint on the road to the airport and they took everything.",
			"A customer says the dispensary on Spenard Road is undercutting everybody and weed on the street is down.",
			"A kid stocking shelves says Curtis's people are hiring, and the kid next to him tells him to shut up.",
		],
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
		"hire_text": "Corporate cleared you. Orientation is tomorrow at eight. Bring your ID.",
		"reject_text": "Corporate didn't clear the background check. Nothing I can do from here.",
		"missed_first": "You were on the schedule today. Call me.",
		"missed_final": "Second no-call. Third is automatic. That's corporate, not me.",
		"fired": "Denise walks you to the door the way she'd walk anybody. \"Take the vest off before you go out. It's the rule.\"",
		"fired_text": "System terminated you this morning. Nothing I could do. Take care of yourself.",
	},
	"night_owl": {
		"performance_attribute": "charisma",
		"tiers": ["Counter", "Regular", "Closer"],
		"interview_text": "come by tonight before close. no interview. i just want to see you work a rush",
		"questions": [
			{"q": "Mina slides you an apron. \"Rush is in ten minutes. What do you do when three people order at once?\"",
			 "a": {"text": "Take all three, make them in order, keep talking.", "score": 1, "say": "\"ok. show me.\""},
			 "b": {"text": "Ask you.", "score": 0, "say": "\"ill be busy.\""}},
			{"q": "\"A regular tells you something he shouldn't. What do you do with it?\"",
			 "a": {"text": "Nothing. It stays at the counter.", "score": 1, "say": "\"good.\""},
			 "b": {"text": "Tell you.", "score": 0, "say": "\"maybe. depends what it is.\""}},
			{"q": "\"Why do you want to work next to me?\"",
			 "a": {"text": "Because you don't waste words and neither do I.", "score": 1, "say": "\"we'll see about the second part.\""},
			 "b": {"text": "Because it's evenings.", "score": 0, "say": "\"ok.\""}},
		],
		"promotion_lines": [
			"Mina stops telling you which regulars pay. You already know. \"youre a regular now. it means something here.\"",
			"Mina hands you the closing key and does not say anything, which from Mina is a speech.",
		],
		"social": [
			"A regular named Old Pete tells you about Anchorage in 1964, the earthquake, and the bar that fell into the inlet.",
			"Mina lets you pick the music for an hour. You pick wrong. She lets it play.",
			"A girl at the counter asks if Mina is single. Mina, from the back, without looking up: \"no.\"",
		],
		"overhear": [
			"Two men at the counter, quiet: Curtis is moving something through Ship Creek Thursday. They stop when Mina looks up.",
			"A woman says the police sat on the Chevron lot all night and nobody came.",
			"A regular says pills are cheap on the east side this week, then says he heard that from somebody.",
		],
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
		"hire_text": "youre on. tomorrow night. dont make me regret it",
		"reject_text": "not right now. its not you",
		"missed_first": "you werent here tonight. its fine. just tell me next time",
		"missed_final": "two nights. i covered. i wont cover a third",
		"fired": "Mina takes you off the schedule. She does it kindly, which is the part that lands.",
		"fired_text": "i took you off the schedule. its ok. come by when youre ready. as a customer",
	},
	"juan_warehouse": {
		"performance_attribute": "intelligence",
		"tiers": ["Dock", "Lead Hand", "Foreman's Second"],
		"interview_text": "Juan says you're solid. Dock, six a.m., tomorrow. I'll ask you three things and watch you lift one.",
		"questions": [
			{"q": "\"You ever thrown out your back?\"",
			 "a": {"text": "No. I lift with my legs.", "score": 1, "say": "\"Everybody says that until they don't.\""},
			 "b": {"text": "Once. Learned from it.", "score": 0, "say": "\"Ok. Then you know.\""}},
			{"q": "\"Driver from the Valley says your count is wrong. It isn't.\"",
			 "a": {"text": "Show him the sheet. Twice if he needs it.", "score": 1, "say": "\"That's the job.\""},
			 "b": {"text": "Tell him to take it up with you.", "score": -1, "say": "\"Then I'm doing your job.\""}},
			{"q": "\"Juan vouched. That means if you don't show, it's on him. You good with that?\"",
			 "a": {"text": "I'll show.", "score": 1, "say": "\"Six a.m.\""},
			 "b": {"text": "That's a lot to put on Juan.", "score": 0, "say": "\"It is. He did it anyway.\""}},
		],
		"promotion_lines": [
			"Ray hands you a radio. \"Lead hand. When I'm not here, you are.\"",
			"Ray, without ceremony: \"When I go up to the slope in March, the dock is yours. Don't lose anybody.\"",
		],
		"social": [
			"A forklift driver named Bear has a rule about coffee and teaches it to you like scripture.",
			"Juan works four bays down and neither of you mentions the apartment for eight hours. It's nice.",
			"Ray tells you about the year the port shut. Half the dock went to Prudhoe. \"The other half went to jail.\"",
		],
		"overhear": [
			"Two drivers: a container came in short and the guy who signed for it is not around anymore.",
			"A railroad man says the price of coke downtown jumped because a package didn't make the Seattle flight.",
			"Somebody says Curtis has a guy at the port, and somebody else says Curtis has a guy everywhere.",
		],
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
		"hire_text": "Juan vouched. Dock at six. Wear boots.",
		"reject_text": "No room on the dock this week. Ask Juan to ask me again in a while.",
		"missed_first": "Truck came at six. You didn't. Juan vouched for you.",
		"missed_final": "Two. I told Juan. Don't make me say three.",
		"fired": "Ray doesn't give you the speech. He gives it to Juan, and Juan gives it to you.",
		"fired_text": "You're off the dock. I'm sorry to do it. Juan will hear about it from me, not you.",
	},
	"ship_creek": {
		"performance_attribute": "intelligence",
		"tiers": ["Freight", "Route", "Lead"],
		"interview_text": "Five a.m. Post Road gate. If you're late I already know what I need to know.",
		"questions": [
			{"q": "Big Mike checks the clipboard. \"You know what freight is?\"",
			 "a": {"text": "Things that don't wait.", "score": 1, "say": "\"Huh. Ok.\""},
			 "b": {"text": "Trucks.", "score": 0, "say": "\"Trucks. Sure.\""}},
			{"q": "\"Wind's blowing forty off the inlet. Your hands don't work. What do you do?\"",
			 "a": {"text": "Keep going till the truck's loaded, then feel it.", "score": 1, "say": "\"That's the job.\""},
			 "b": {"text": "Warm up in the cab.", "score": -1, "say": "\"Cab's for drivers.\""}},
			{"q": "\"On time every day for a month. Can you do that?\"",
			 "a": {"text": "Every day.", "score": 1, "say": "\"We'll see.\""},
			 "b": {"text": "Most days.", "score": -1, "say": "\"Most days the truck leaves without you.\""}},
		],
		"promotion_lines": [
			"Big Mike puts you on the good route. It's the same route with a heater that works. \"Route. Don't get comfortable.\"",
			"Big Mike crosses out a name on the clipboard and writes yours above it. \"Lead. The name I crossed out was mine.\"",
		],
		"social": [
			"A guy named Tino has worked freight since before the port had a fence. He shows you where the fence is weak. Just information.",
			"Big Mike brings a thermos of something that is not coffee and pours you one at four a.m. without asking.",
			"Two Samoan brothers from Mountain View load beside you and sing the whole shift. Nobody tells them to stop.",
		],
		"overhear": [
			"Two drivers: a manifest didn't match and the container is sitting in Curtis's lot, not the port's.",
			"Somebody says the checkpoint on the airport road is every night now.",
			"A railroad man says Mountain View is where the pills go, and the Gate is where they come from.",
		],
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
		"hire_text": "You're on the crew. Truck leaves at five. It doesn't wait.",
		"reject_text": "List is full. Try again when somebody quits, which is weekly.",
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

## BR-D3 (0.9.0 PR 2): the rungs. Each job has three titles; a rung is
## earned when every gate on it is met, not when the XP bar fills.
static func tiers_for(job_id: String) -> Array:
	return manager_for(job_id).get("tiers", [])

static func title_for(job_id: String, rank: int) -> String:
	var tiers: Array = tiers_for(job_id)
	if tiers.is_empty():
		return ""
	return str(tiers[clampi(rank, 0, tiers.size() - 1)])

static func questions_for(job_id: String) -> Array:
	return manager_for(job_id).get("questions", [])

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
