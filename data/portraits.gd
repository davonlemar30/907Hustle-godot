extends RefCounted
## Faces and places (One Good Run PR 3, OG-D3). Every image the game can
## show, by the id the game already uses, and one lookup that returns the
## texture or null. Null is a first-class answer: every surface that shows
## a portrait or a header renders without it, because assets arrive on
## their own schedule and the display system shipped before some of them.
##
## Files live in `res://assets/img/` as WebP. Portraits are 750x750, district
## headers 750x300, venue interiors 750x400 (`docs/ASSET_CHECKLIST.md`).

const IMG := "res://assets/img/"

## NPC id -> file stem. Display names and opponent titles resolve through
## `NAMES` first, so "Curtis's two" finds Curtis and "Big Mike" finds his.
const PORTRAITS := {
	"yalonda": "yalonda", "juan": "juan", "mina": "mina", "curtis": "curtis", "dre": "dre",
	"goodie": "goodie", "deshawn": "deshawn", "eli": "eli", "pherris": "pherris", "tone": "tone",
	"lani": "lani", "marcus": "marcus", "sonny": "sonny", "denise": "denise", "ray": "ray",
	"big_mike": "bigmike", "reggie": "reggie", "biniam": "biniam", "selam": "selam",
}
const NAMES := {
	"Yalonda": "yalonda", "Juan": "juan", "Mina": "mina", "Curtis": "curtis", "Curtis Foyer": "curtis",
	"Dre": "dre", "Dre Smooth": "dre", "Goodie": "goodie", "Deshawn": "deshawn", "Eli": "eli",
	"Pherris": "pherris", "Tone": "tone", "Lani": "lani", "Marcus": "marcus", "Sonny": "sonny",
	"Denise": "denise", "Ray": "ray", "Big Mike": "big_mike", "Reggie": "reggie",
	"Biniam": "biniam", "Selam": "selam",
}
const DISTRICT_HEADERS := {
	"north_star_lot": "district_spenard", "downtown": "district_downtown",
	"airport_industrial": "district_shipcreek", "mountain_view": "district_mountainview",
}
const VENUES := {
	"night_owl": "venue_nightowl", "spenard_gym": "venue_gym", "wash_go": "venue_washgo",
	"spenard_chevron": "venue_chevron", "humpys": "venue_humpys", "williwaw": "venue_williwaw",
	"the_nile": "venue_nile", "red_apple": "venue_redapple", "barbershop": "venue_barbershop",
}
const VEHICLES := {"beater": "beater"}

static var _cache: Dictionary = {}

static func _load(stem: String) -> Texture2D:
	if stem.is_empty():
		return null
	if _cache.has(stem):
		return _cache[stem]
	var path := IMG + stem + ".webp"
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Variant = load(path)
		if loaded is Texture2D:
			texture = loaded
	_cache[stem] = texture
	return texture

## Which NPC a name refers to, or "". Exact first; then a name the string
## starts with ("Curtis's two", "Reggie, and the block").
static func npc_for(name: String) -> String:
	if PORTRAITS.has(name):
		return name
	if NAMES.has(name):
		return str(NAMES[name])
	for key in NAMES.keys():
		if name.begins_with(str(key)):
			return str(NAMES[key])
	return ""

static func portrait_for(name_or_id: String) -> Texture2D:
	var npc := npc_for(name_or_id)
	if npc.is_empty():
		return null
	return _load(str(PORTRAITS.get(npc, "")))

static func district_header(district_id: String) -> Texture2D:
	return _load(str(DISTRICT_HEADERS.get(district_id, "")))

## TU-D1 (1.3.0): the same banner at a time of day -- `district_spenard_night`
## and so on -- falling back to the plain banner, then to nothing.
## The Home variants are named `home_<district>_<slot>` (the first four are
## Spenard's, 750x300); `district_<x>_<slot>` is honoured too.
const HOME_STEMS := {
	"north_star_lot": "home_spenard", "downtown": "home_downtown",
	"airport_industrial": "home_shipcreek", "mountain_view": "home_mountainview",
}

static func district_header_at(district_id: String, slot: String) -> Texture2D:
	var stem := str(DISTRICT_HEADERS.get(district_id, ""))
	if stem.is_empty():
		return null
	var suffix := slot.to_lower()
	if not suffix.is_empty():
		var home_stem := str(HOME_STEMS.get(district_id, ""))
		if not home_stem.is_empty():
			var home: Texture2D = _load("%s_%s" % [home_stem, suffix])
			if home != null:
				return home
		var timed: Texture2D = _load("%s_%s" % [stem, suffix])
		if timed != null:
			return timed
	return _load(stem)

## TU-D4 (1.3.0): the scene behind an encounter -- street, police, robbery,
## crew, deal -- or nothing.
static func encounter_scene(key: String) -> Texture2D:
	return _load("encounter_%s" % key)

static func venue_image(venue_id: String) -> Texture2D:
	return _load(str(VENUES.get(venue_id, "")))

static func vehicle_image(vehicle_id: String) -> Texture2D:
	return _load(str(VEHICLES.get(vehicle_id, "")))

## A square portrait control at `px`, or null when there is no face to show.
static func portrait_rect(name_or_id: String, px: int) -> TextureRect:
	var texture := portrait_for(name_or_id)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## A wide header control at `height`, or null.
static func header_rect(texture: Texture2D, height: int) -> TextureRect:
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(0, height)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
