# 907Hustle — Asset Generation Prompt Guide  (v2)

Two separate style spines — **portraits** and **environments** — so studio
portraits don't inherit "anamorphic snowfall" and locations don't inherit
"charcoal studio backdrop." Within a category, keep lighting / lens / framing
identical and change only the subject (portraits) or the place (locations).

**Procedural rule #1 — pull ClickUp canon before generating any portrait.**
Character bios (origin, work, family, temperament) drive posture, wardrobe,
grooming, age, and demeanor. Do not generate a face from a name alone.

**Seed note:** our in-app image generator exposes no seed control, so
`--seed` does nothing here — consistency comes from identical prompt language,
the same model, and passing the **first approved portrait as a visual
reference** into later ones. (If you switch to Midjourney etc., seeds help —
use `--seed 907` portraits / `--seed 1907` locations.)

Shared negative prompt (photographic assets):
> daylight, sunny, cheerful, cartoon, anime, illustration, low detail,
> deformed face, extra fingers, watermark, text, signature, oversaturated,
> HDR halos, blurry

---

## ★ PORTRAIT SPINE  → `portraits/`  · PNG **1024×1024**

Master specs (identical for the whole cast — this is the cohesion):
- **Lens/light:** 85mm equivalent, Rembrandt key from camera-left, soft red
  rim light from camera-right, dark charcoal studio backdrop with falloff,
  shallow depth of field, restrained film grain.
- **Framing:** head centered, upper chest visible, ~10–15% headroom, generous
  side margin so Godot can crop to circle / square / rectangle. Camera at eye
  height. Direct eye contact.
- **Expression VARIES per character** (personality), everything else fixed.

**Template:**
`Portrait of {CHARACTER — age, origin/heritage, build, hair, wardrobe, grooming}, {EXPRESSION}. 85mm, Rembrandt key camera-left, soft red rim camera-right, dark charcoal studio backdrop, shallow depth of field, restrained film grain, photorealistic, cinematic. Head centered, upper chest, ~12% headroom. --ar 1:1`

### Portrait priority order (current playable surfaces)
1. **Yalonda** 2. **Juan** 3. Goodie 4. Tasha 5. Malik 6. Eli 7. Pherris
8. Tone 9. Deshawn 10. Curtis — then Cal, Nia. Secondary (Renata, Boone, Mina,
Selam, Biniam, etc.) as their screens arrive.

> Generate **Yalonda first, Juan second.** Those two set the "visual bible":
> if the system can show two people from the same household as clearly related
> without looking like copies, it's working. Approve both, then batch the rest
> against that standard.

### Expression notes (from canon)
- **Yalonda** — observant and controlled, warmth buried underneath; the face of
  someone who listens closely and remembers what you told her; some fatigue
  around the eyes; difficult to bullshit.
- **Juan** — curious and energetic, sociable, still figuring himself out.
- **Curtis** — composed, difficult to read.
- **Eli** — alert, operational, watchful.
- Others — set from their ClickUp bio at generation time.

### LOCKED concept — Yalonda Hernandez (regenerate to this)
> Yalonda Hernandez, early 40s, Dominican (from Villa Mella, came up through New
> York), now in Anchorage. Grounded adult attractiveness, working-class
> practicality. Dark winter coat with signs of regular use, simple gold jewelry,
> neat maintainable hair, restrained makeup, composed posture. Raises her son
> Juan alone; runs informal rooms like a disciplined business; strong
> boundaries. Direct eye contact, faint work-fatigue around the eyes, capable
> and warm-once-invited-in. 85mm, Rembrandt key camera-left, soft red rim
> camera-right, dark charcoal studio backdrop, shallow DOF, restrained film
> grain, photorealistic, cinematic. Head centered, upper chest, ~12% headroom.
> --ar 1:1

---

## ★ ENVIRONMENT SPINE  → `photos/…`

Append to every location/atmosphere prompt:
> Gritty neo-noir, Spenard neighborhood of Anchorage Alaska in deep winter.
> 35mm anamorphic lens, wet asphalt reflecting neon, snow banks, power lines,
> distant Chugach mountains, cold desaturated palette, deep blacks, red neon
> (#ff4a3d) + amber sodium light, atmospheric haze, light snowfall,
> photorealistic. Empty street, no people.

### Split by FUNCTION — don't force one crop to do both jobs
- **Gameplay backgrounds → `photos/atmosphere/` · 9:16 (`--ar 9:16`)**
  - `bg-spenard-home.webp` ← the tall night-street shot already made (keep 9:16).
    Full-bleed behind the Home shell; also center-crops fine to the banner.
- **Location headers → `photos/locations/` · 16:9 (`--ar 16:9`)**
  - `location-spenard.webp` — rundown strip, red neon liquor sign, graffiti.
  - `location-downtown.webp` — low downtown skyline, bar/hotel lights, snow.
  - `location-industrial.webp` — Industrial Service Roads: warehouse docks,
    chain-link, sodium-lit loading bays, truck yards, snow berms.

(Midtown / U-Med / Mountain View are minor ambient references, not primary
travel areas — skip dedicated headers until/unless they get real screens.)

---

## LOGO  → `logo/`
**Recommended:** built in-engine from the Anton font + grunge overlay (crisp,
editable). Generate only if you want a raster version — models mangle text.

## ICONS  → `icons/**`  ✅ DONE
Authored as 36 monochrome white SVGs on a 24×24 grid (nav 5 / hud 6 /
products 7 / ui 18). One file per glyph; Godot tints per-state via `modulate`
(e.g. active nav = red `#ff4a3d`, idle = grey). Product note: `coke` and
`cocaine` share `icon-coke.svg`.

---

## Export checklist
- Portraits → PNG, **1024×1024**, head centered, upper chest, ~12% headroom.
- Gameplay bg → WebP, **9:16**.  Location headers → WebP, **16:9**.
- Logo → transparent.  Icons → done.
- Filenames exactly as above / in ASSET_MANIFEST.md.
