extends RefCounted
## Phone replies -- the player speaks (The World Speaks, PR 3, WS-D3).
##
## Every text from a named NPC carries two answers. A leans toward the
## person (disposition up); B keeps distance (neutral, or a little down for
## the people who notice). Under fifteen words, no capital letters where a
## thumb would not bother, no complete sentences where a person would not.
## The NPC answers back once, in their own voice, and the exchange is over --
## this is not a tree, it is a person hearing you.
##
## Voices, from the character pages: Mina careful (short, observant), Dre
## smooth (always closing), Deshawn community (the block), Tone blunt
## (fewest words), Goodie transactional, Pherris a connector (networks),
## Eli a runner (routes), Juan the roommate (plain), Yalonda the landlord
## (dry, exact).
##
## `CONTEXTS` are the specific texts the game sends, keyed by the site that
## sends them; `DEFAULTS` cover every other text from that NPC. Each entry
## is `{a: {text, reaction}, b: {text, reaction}}`. `GHOST_OPENERS` are what
## an NPC prepends the next time they text somebody who left them on read.

const NPC_FOR_SENDER := {
	"Mina": "mina", "Dre": "dre", "Juan": "juan", "Yalonda": "yalonda",
	"Pherris": "pherris", "Eli": "eli", "Tone": "tone", "Deshawn": "deshawn",
	"Goodie": "goodie", "Lani": "lani", "Marcus": "marcus",
	"Sonny": "sonny", "Denise": "denise", "Ray": "ray", "Big Mike": "big_mike",
}

## Who cares about being left on read. A ghosted text costs these people;
## the rest shrug.
const CARES_ABOUT_SILENCE := ["mina", "dre", "yalonda", "lani", "marcus", "sonny",
	"denise", "ray", "big_mike"]

const CONTEXTS := {
	# Juan, the day he mentions Dre (dre_lender.gd).
	"juan_dre_mention": {
		"a": {"text": "appreciate you. ill ask around", "reaction": "cool. dont borrow more than you can pay tho. seen how that goes"},
		"b": {"text": "im good on that", "reaction": "ok. its there if it gets bad"},
	},
	# Dre, due tomorrow.
	"dre_due_tomorrow": {
		"a": {"text": "say less. ill have it", "reaction": "Good. I like a man who answers."},
		"b": {"text": "yeah", "reaction": "Yeah is not a number. Tomorrow."},
	},
	# Dre, due today.
	"dre_due_today": {
		"a": {"text": "omw with it", "reaction": "I'll be where I always am."},
		"b": {"text": "working on it", "reaction": "Work faster."},
	},
	# Dre, the money did not come.
	"dre_missed": {
		"a": {"text": "my bad. lets talk", "reaction": "Talking is free. Come see me before it isn't."},
		"b": {"text": "i know", "reaction": "Knowing was never the problem."},
	},
	# Dre, the account suspended.
	"dre_suspended": {
		"a": {"text": "ill make it right", "reaction": "Then make it right. I'm not going anywhere."},
		"b": {"text": "we'll see", "reaction": "We will."},
	},
	# Mina, the counter is short a night (venues.gd).
	"mina_counter": {
		"a": {"text": "say the word. im in", "reaction": "word. come by tomorrow, ill show you the register"},
		"b": {"text": "let me think on it", "reaction": "sure. its not going anywhere"},
	},
	# Mina mentions the board (wander.gd day_start_mentions).
	"mina_list": {
		"a": {"text": "good looking out", "reaction": "dont get scammed. everyone on there is somebody's cousin"},
		"b": {"text": "maybe", "reaction": "ok"},
	},
	"juan_list": {
		"a": {"text": "bet. show me how you list stuff", "reaction": "photos, real price, dont answer the first three guys. thats the whole trick"},
		"b": {"text": "im straight", "reaction": "your loss bro"},
	},
	"yalonda_list": {
		"a": {"text": "thank you. for real", "reaction": "Don't thank me. Pay me on Friday."},
		"b": {"text": "ok", "reaction": "Mm."},
	},
	"dre_list": {
		"a": {"text": "say less", "reaction": "That's what I like to hear."},
		"b": {"text": "not really my thing", "reaction": "Everything is your thing when the rent is due."},
	},
	# OG-D2: somebody noticed the name (exposure.gd).
	"rank_notice": {
		"a": {"text": "good. let em know", "reaction": ""},
		"b": {"text": "keep it quiet", "reaction": ""},
	},
	# OG-D1: the rent, late (obligations.gd).
	"yalonda_rent_due": {
		"a": {"text": "ill have it tomorrow. im sorry", "reaction": "Tomorrow, then."},
		"b": {"text": "i know", "reaction": "Knowing isn't paying."},
	},
	"yalonda_rent_late": {
		"a": {"text": "please. two more days. i swear", "reaction": "I don't do swearing. I do Friday."},
		"b": {"text": "im working on it", "reaction": "Work faster."},
	},
	"yalonda_rent_paid_late": {
		"a": {"text": "it wont. thank you", "reaction": "Mm-hm."},
		"b": {"text": "ok", "reaction": ""},
	},
	"juan_rent": {
		"a": {"text": "im good for it. tell her", "reaction": "i did. thats the problem"},
		"b": {"text": "stay out of it", "reaction": "bro i live here too"},
	},
	# Yalonda's first text: the terms (name_entry.gd).
	"yalonda_rent": {
		"a": {"text": "yes maam. thank you for the room", "reaction": "Mm-hm. Lock the door."},
		"b": {"text": "got it", "reaction": ""},
	},
	# The managers (jobs.gd, PR 4).
	"manager_missed_first": {
		"a": {"text": "my bad. ill be in tomorrow", "reaction": "See that you are."},
		"b": {"text": "something came up", "reaction": "Something always does."},
	},
	"manager_missed_final": {
		"a": {"text": "im sorry. wont happen again", "reaction": "It happened twice. That's the count."},
		"b": {"text": "ok", "reaction": "Ok."},
	},
	"manager_interview": {
		"a": {"text": "ill be there. thank you", "reaction": "Good."},
		"b": {"text": "ok", "reaction": ""},
	},
	"manager_promoted": {
		"a": {"text": "appreciate you. i wont", "reaction": "See that you don't."},
		"b": {"text": "ok", "reaction": ""},
	},
	"manager_hired": {
		"a": {"text": "thank you. ill be there early", "reaction": "Good. See you then."},
		"b": {"text": "ok", "reaction": ""},
	},
	"manager_rejected": {
		"a": {"text": "i understand. thank you for looking", "reaction": "Take care of yourself."},
		"b": {"text": "ok", "reaction": ""},
	},
	"manager_fired": {
		"a": {"text": "i understand. thank you for the chance", "reaction": "Take care of yourself."},
		"b": {"text": "whatever", "reaction": ""},
	},
}

const DEFAULTS := {
	"mina": {
		"a": {"text": "yeah just moving. appreciate you", "reaction": "ok. be careful out there"},
		"b": {"text": "im good", "reaction": "ok"},
	},
	"dre": {
		"a": {"text": "say less, omw", "reaction": "That's what I like."},
		"b": {"text": "busy rn", "reaction": "Busy is fine. Broke isn't."},
	},
	"juan": {
		"a": {"text": "bet. thanks bro", "reaction": "no doubt"},
		"b": {"text": "k", "reaction": "k"},
	},
	"yalonda": {
		"a": {"text": "got it. thank you", "reaction": "Mm-hm."},
		"b": {"text": "ok", "reaction": "Lock the door when you come in."},
	},
	"pherris": {
		"a": {"text": "good look. im on it", "reaction": "thats why I text you first"},
		"b": {"text": "not tonight", "reaction": "somebody else will then"},
	},
	"eli": {
		"a": {"text": "bet. moving now", "reaction": "go before it changes"},
		"b": {"text": "maybe later", "reaction": "later the road wont be quiet"},
	},
	"tone": {
		"a": {"text": "im there", "reaction": "Good."},
		"b": {"text": "not tonight", "reaction": "."},
	},
	"deshawn": {
		"a": {"text": "appreciate you looking out", "reaction": "thats the block. we look out"},
		"b": {"text": "ok", "reaction": "aight"},
	},
	"goodie": {
		"a": {"text": "bet. what you got", "reaction": "same as always. bring money not questions"},
		"b": {"text": "im good today", "reaction": "tomorrow then. or not"},
	},
	"lani": {
		"a": {"text": "yes maam. thank you", "reaction": "Baby, I know. Come in early."},
		"b": {"text": "ok", "reaction": "Ok baby."},
	},
	"marcus": {
		"a": {"text": "got it. ill be there", "reaction": "Good."},
		"b": {"text": "yeah", "reaction": ""},
	},
	"sonny": {
		"a": {"text": "my bad. ill be in", "reaction": "ok ok. dont be late"},
		"b": {"text": "k", "reaction": ""},
	},
	"denise": {
		"a": {"text": "sorry denise. ill be in tomorrow", "reaction": "Tomorrow then. On time."},
		"b": {"text": "ok", "reaction": ""},
	},
	"ray": {
		"a": {"text": "my fault ray. wont happen again", "reaction": "See that it doesn't. Six a.m."},
		"b": {"text": "yeah", "reaction": ""},
	},
	"big_mike": {
		"a": {"text": "understood. ill be on time", "reaction": "Truck leaves at five."},
		"b": {"text": "ok", "reaction": ""},
	},
}

## What an NPC says first, the next time they text somebody who left their
## last one on read. Once, then it clears.
const GHOST_OPENERS := {
	"mina": "you dont text back. thats fine. ",
	"dre": "You went quiet on me. Don't. ",
	"yalonda": "You could answer a text. ",
	"juan": "",
	"lani": "Baby you don't answer your phone. ",
	"marcus": "", "sonny": "", "denise": "You could answer a text. ", "ray": "", "big_mike": "",
	"pherris": "", "eli": "", "tone": "", "deshawn": "", "goodie": "",
}

static func npc_for(sender: String) -> String:
	return str(NPC_FOR_SENDER.get(sender, ""))

## The two answers for a text: the context's own if it has one, else the
## NPC's defaults, else nothing (a sender nobody authored replies for).
static func replies_for(npc_id: String, context: String) -> Dictionary:
	if not context.is_empty() and CONTEXTS.has(context):
		return CONTEXTS[context]
	return DEFAULTS.get(npc_id, {})

static func cares_about_silence(npc_id: String) -> bool:
	return npc_id in CARES_ABOUT_SILENCE
