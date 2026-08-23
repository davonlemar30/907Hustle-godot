# Nested save validator sabotage record

> **Corrected 2026-08-23 (Batch 18 PR 5).** This file's final line claimed
> `save_validation: PASS — 82 checks, 0 failures`, and its own coverage table
> stops at the v10 arm. Neither has been true for a while: the gate has been
> at **114 checks** since Batch 18 PR 3 added the first Territory arm, and the
> schema is **v16**, not v10. The gap between v10 and v16 (the v11-v15 arms —
> Heat's teeth, Wander, `wanders_today`, `boost_targets_discovered`) shipped
> without a sabotage record here, which is itself a finding: PROCESS says
> "documentation ships with the PR," and this file is proof a validator arm
> can ship correctly, covered by real tests, and still leave this specific
> record behind. Not backfilled with invented "Red: ..." lines for those five
> arms — this project's own standing rule is no retro-documentation, because
> retro-documentation writes down the conclusion without the reasoning that
> was live at the time, and a fabricated sabotage transcript would be worse
> than an honest gap. The v16 Territory arm's own record, added contemporaneously
> in the PR that shipped it, is below.

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

The unmodified suite returned `save_validation: PASS — 82 checks, 0 failures` at
the time this line was written. See the correction at the top of this file for
what changed between then and now.

The v16 extension (Batch 18 PR 3, `_validate_territory_nodes` — the root-cause
fix for `86bbjxtab`, an unknown territory node id silently killing nightly
settlement) adds these adversarial cases, run contemporaneously with the PR
that shipped the arm:

| Validator targeted | Temporary mutation | Result |
| --- | --- | --- |
| `territory_nodes` row type | Removed the `row is Dictionary` guard | Red: `SCRIPT ERROR: Invalid cast: could not convert value to 'Dictionary'` at `save_validator.gd:717` — a crash, not a repair, which is exactly the fault the guard exists to prevent |
| Unknown territory node id | (proven at the migration arm, `autoload/save_system.gd`, not the validator — see `docs/BUILD_LOG.md`'s Batch 18 PR 3 entry for the full sabotage log) | — |

The unmodified suite now returns `save_validation: PASS — 114 checks, 0
failures`.
