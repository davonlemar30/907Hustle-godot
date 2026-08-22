# Nested save validator sabotage record

The validator suite was run with five temporary mutations. Each mutation made
the suite fail, then was reverted before the final verification run.

| Validator targeted | Temporary mutation | Result |
| --- | --- | --- |
| `crew_records.status` | Changed the missing-status default from `active` to `sabotaged` | Red: `crew status defaults` |
| `markets` null entry | Replaced the empty market default with a non-empty sentinel price map | Red: `market defaults prices` |
| Canonical shark `amount` | Changed the wrong-type default from `0` to `-1` | Red: `loan amount repairs to safe int` |
| Observation `npc_id` | Changed the wrong-type default from empty string to `bad` | Red: `observation npc id defaults` |
| Consequence queue | Kept a malformed null row instead of dropping it | Red: `null consequence queue row drops` |

The unmodified suite then returned `save_validation: PASS — 47 checks, 0
failures`.

The v9 extension adds these adversarial cases:

| Validator targeted | Temporary mutation | Result |
| --- | --- | --- |
| `arrest_record.cooldown_until_day` | Removed the wrong-type fallback to `-1` | Red: `wrong-type cooldown defaults inactive` |
| `consequence_flags.retaliation_first_expiry_seen` | Removed the bool type repair | Red: `wrong-type expiry flag defaults false` |
| `consequence_flags.retaliation_last_ambient_day` | Removed the lower-bound repair | Red: `out-of-range ambient day defaults inactive` |

The v10 extension adds these adversarial cases:

| Validator targeted | Temporary mutation | Result |
| --- | --- | --- |
| `districts_unlocked` home turf | Removed the `north_star_lot` restore | Red: `home turf is restored when missing` |
| `districts_unlocked` rows | Kept non-String rows instead of dropping them | Red: `non-string district rows drop` |
| `job_contacts` | Removed the negative clamp | Red: `negative job contacts default to none` |
| `pressure_clean_credits` | Removed the negative clamp | Red: `a negative credit cannot add pressure` |
| Absent v10 fields | Defaulted them in instead of leaving them absent | Red: `absent v10 districts stay absent` + `absent v10 fields need no repair` |

The unmodified suite returns `save_validation: PASS — 82 checks, 0 failures`.
