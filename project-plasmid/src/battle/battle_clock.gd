class_name BattleClock
extends RefCounted
## How fast ticks are consumed. Spec §7.0.
##
## [b]This is the whole of what a speed control is allowed to be.[/b] CLAUDE.md's rule —
## "presentation never mutates sim state; speed controls change how fast ticks are
## consumed, never what a tick does" — is enforced by shape here: this class converts
## elapsed real seconds into a number of ticks and knows nothing else. It cannot alter an
## outcome because it never touches one.
##
## Pure and headless, so the claim that 4x and instant agree with 1x is testable rather
## than merely intended.

enum Speed { PAUSED, NORMAL, DOUBLE, QUADRUPLE, INSTANT }

const MULTIPLIERS := {
	Speed.PAUSED: 0,
	Speed.NORMAL: 1,
	Speed.DOUBLE: 2,
	Speed.QUADRUPLE: 4,
	Speed.INSTANT: 0,
}

var speed: Speed = Speed.NORMAL

## Guards against float drift. Summing many small frame times lands a hair under the
## exact total, which without this silently drops roughly one tick in every ten at high
## frame rates — the battle would quietly run slow.
const EPSILON := 0.0001

## Real seconds banked but not yet worth a whole tick. Carried rather than discarded, so
## a slow frame does not silently lose time and 2x really is twice 1x.
var _carried: float = 0.0


func multiplier() -> int:
	return MULTIPLIERS[speed]


func is_instant() -> bool:
	return speed == Speed.INSTANT


func is_paused() -> bool:
	return speed == Speed.PAUSED


## How many ticks this frame is worth. Instant is handled by the caller, not by returning
## a huge number here — "run it all now" is a different instruction from "run fast".
func advance(delta: float) -> int:
	if is_paused() or is_instant():
		return 0
	_carried += delta * float(multiplier())
	var ticks := int((_carried + EPSILON) / Balance.TICK_SECONDS)
	_carried = maxf(0.0, _carried - float(ticks) * Balance.TICK_SECONDS)
	return ticks


func reset() -> void:
	_carried = 0.0


static func speed_name(value: Speed) -> String:
	match value:
		Speed.PAUSED:
			return "Paused"
		Speed.DOUBLE:
			return "2x"
		Speed.QUADRUPLE:
			return "4x"
		Speed.INSTANT:
			return "Instant"
		_:
			return "1x"
