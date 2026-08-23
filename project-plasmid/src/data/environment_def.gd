class_name EnvironmentDef
extends Resource
## One battle's environment. Spec §7.2, §7.3, §7.4.
##
## [b]These values must never migrate into [Balance].[/b] §7.4 makes food delivery the
## primary balance lever precisely because it varies per battle — with 24 slots the
## binding constraint is meant to sit in the environment rather than on the plasmid, and
## a global constant would put it back on the plasmid.
##
## §7.2's other axes — pulses versus drip, ambient toxin, radiation, antibiotics,
## osmotic stress — belong here too and arrive with F05 and F07.

@export var display_name: String = "Unnamed"

## Food units delivered per [constant Balance.RATE_SCALE] ticks, so the drip stays
## integer. §7.4's three working points are 150 abundant, 75 knife-edge, 40 scarce.
@export var food_delivery_scaled: int = 75

## Metabolites yielded per unit catabolised inside the cell. Simple sugar 3, complex
## polymer 6 (§7.3, as amended in spec v0.3.1).
@export var food_yield: int = 3

## Food already sitting in the medium at tick 0.
@export var starting_food: int = 0


static func _make(
	name: String, delivery: int, yield_per_unit: int, starting: int
) -> EnvironmentDef:
	var env := EnvironmentDef.new()
	env.display_name = name
	env.food_delivery_scaled = delivery
	env.food_yield = yield_per_unit
	env.starting_food = starting
	return env


## ~1.5 food/tick. Engine-building wins outright and denial is pointless (§7.4). Early
## battles.
static func abundant() -> EnvironmentDef:
	return _make("Abundant", 150, 3, 4)


## ~0.75 food/tick. The default, and the knife-edge §7.4 says to design around: both
## cells can theoretically finish, so whoever captures more than half wins.
static func knife_edge() -> EnvironmentDef:
	return _make("Knife-edge", 75, 3, 2)


## ~0.4 food/tick. Neither cell can finish honestly, forcing parasitism, toxin offence
## or polymer access (§7.4). Late battles.
static func scarce() -> EnvironmentDef:
	return _make("Scarce", 40, 3, 0)


## Food the environment will deliver over a whole battle. §7.4 reasons in these terms —
## the total budget, not the rate — so it is worth being able to ask for it directly.
func total_delivery_over(ticks: int) -> int:
	return food_delivery_scaled * ticks / Balance.RATE_SCALE
