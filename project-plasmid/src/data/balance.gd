class_name Balance
extends RefCounted
## Global balance constants. Never instantiated.
##
## Registered in docs/balance.md — any constant added here gets a row there in the
## same change, with its spec section and this file as its location.
##
## Only genuinely global values belong here. Per-block, per-promoter and especially
## per-environment values (food delivery rate, ambient toxin) live in Resources under
## src/data/, because spec §7.4 varies them per battle.


## Ticks an immature metabolite ages before it converts to +1 banked growth and
## leaves the pool permanently. Spec §2.1.
##
## Paired with environmental shock frequency, this is the primary difficulty knob
## (§7.5): at 5 ticks, toxin pulses every ~20 ticks leave buffers intact, while
## pulses every ~6 shred them and force just-in-time play.
const MATURATION_AGE := 5


## Promoter firing periods in ticks, slowest first. Spec §4.2.
##
## The divisors of 12, and the family is [b]closed on purpose[/b]. Steady-state slot
## count is `slots × rate / total_rate` (§3.1), so a rack lands on whole numbers only
## when competing rates are small integers over a common base. A period from outside —
## 8 against 12, say — gives 4.8 : 3.2 and a rack that cycles forever instead of
## settling, undoing the stability §3.4 guarantees.
##
## [method PlasmidNotation.parse] rejects anything outside this list, so the rule is
## enforced rather than merely written down. Read docs/balance.md before adding a tier;
## the answer is usually to redesign around a new base, not to append one.
const PROMOTER_PERIODS: Array[int] = [12, 6, 4, 3, 2]
