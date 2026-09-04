# Asset checklist — every image the display system looks for

_1.0.0 (One Good Run, PR 7). The display system (`data/portraits.gd`) resolves
every image by name at runtime and renders without it when the file is
absent: a missing portrait is no portrait, a missing header is the screen
without a banner. Nothing below is required for the game to run; everything
below is shown the moment it exists._

All files: **WebP**, in `assets/img/`, lowercase stem exactly as listed.
Godot imports them on the next editor open (a `.import` sidecar appears);
commit both.

## Portraits — 750 × 750

Shown at 64px on People, 48px on Phone text headers, 64px on the encounter
sheet when the opponent is a named NPC, 96px on the hire and interview
sheets. Direction per character is in `docs/NPC_CHARACTER_PROFILES.md`.

| File | Who | Where it shows |
|---|---|---|
| `yalonda.webp` | Yalonda Hernandez, the landlord | People, Phone, the welcome sheet |
| `juan.webp` | Juan Hernandez, the roommate | People, Phone |
| `mina.webp` | Mina Vale, the Night Owl counter | People, Phone, hire and interview sheets |
| `curtis.webp` | Curtis Foyer, the rival | People, Phone, encounter sheets ("Curtis's two") |
| `dre.webp` | Dre Smooth, the note | People, Phone, encounter sheets |
| `goodie.webp` | Goodie, the corner | Phone, encounter sheets |
| `deshawn.webp` | Deshawn, the fixer | Phone, Crew |
| `eli.webp` | Eli, the runner | Phone, Crew |
| `pherris.webp` | Pherris Dickens, the connector | Phone, Crew |
| `tone.webp` | Anton "Tone" Bell, the enforcer | Phone, Crew |
| `lani.webp` | Lani, the Wash & Go | Phone, hire and interview sheets |
| `marcus.webp` | Marcus, the Chevron's nights | Phone, hire and interview sheets |
| `sonny.webp` | Sonny, the Rebel | Phone, hire and interview sheets |
| `denise.webp` | Denise, Northern Value | Phone, hire and interview sheets |
| `ray.webp` | Ray, the dock | Phone, hire and interview sheets |
| `bigmike.webp` | Big Mike, Ship Creek freight | Phone, hire and interview sheets |
| `reggie.webp` | Reggie, the barbershop on the Drive | encounter sheets ("Reggie, and the block") |
| `biniam.webp` | Biniam Tesfaye, the Nile | reserved (the Nile's interior) |
| `selam.webp` | Selam Tesfaye, wellness | reserved |

## District headers — 750 × 300

Shown as Home's hero photo for the district you are standing in, on the
ride card between districts, and on the arrival sheet the first time.

| File | District |
|---|---|
| `district_spenard.webp` | Spenard (`north_star_lot`) |
| `district_downtown.webp` | Downtown |
| `district_shipcreek.webp` | Ship Creek (`airport_industrial`) |
| `district_mountainview.webp` | Mountain View |

## Venue interiors — 750 × 400

Shown as the background of a venue's own screen, where one exists. Venues
without a screen yet are listed so the file is ready when the screen is.

| File | Venue | Screen |
|---|---|---|
| `venue_nightowl.webp` | Night Owl | `ui/screens/night_owl.tscn` |
| `venue_gym.webp` | Spenard Gym | `ui/screens/spenard_gym.tscn` |
| `venue_washgo.webp` | The Wash & Go | reserved |
| `venue_chevron.webp` | Spenard Chevron | reserved |
| `venue_humpys.webp` | Humpy's | reserved |
| `venue_williwaw.webp` | Williwaw | reserved |
| `venue_nile.webp` | The Nile | reserved |
| `venue_redapple.webp` | Red Apple Market | reserved |
| `venue_barbershop.webp` | Reggie's barbershop | reserved |

## Vehicles — 750 × 400

Shown on Home's car card once the player has the car.

| File | Vehicle |
|---|---|
| `beater.webp` | The '04 Corolla from Sonny's nephew |

## Adding a new one

1. Drop the WebP in `assets/img/` with the stem above (or a new stem).
2. Add the stem to the matching table in `data/portraits.gd` (`PORTRAITS`,
   `NAMES` for any display name that should find it, `DISTRICT_HEADERS`,
   `VENUES`, `VEHICLES`).
3. The parity arm `_check_the_kit` asserts every lens NPC, every manager,
   every district and the Night Owl resolve to a file; extend it if the new
   image is one the game should never ship without.
