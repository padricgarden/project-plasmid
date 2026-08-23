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
