class_name Medium
extends RefCounted
## The shared environment pool. Spec §7.1.
##
## At F06 both cells draw from this one object, and that single decision generates most
## of the game's interaction for free: food is contested and depletes, exported toxin
## actually reaches the opponent, and importing what the opponent secreted becomes a
## viable build. Written as shared from the start even though Prototype 1 has one cell —
## nothing here may assume a single consumer.
##
## Delivery is a steady drip. §7.2's pulse patterns are an environment axis for F07;
## the accumulator below is where they will attach.

var food: int = 0

## Fractional food carried between ticks, in [constant Balance.RATE_SCALE] units. Keeps
## a rate like 0.75/tick exact and integer: three units arrive every four ticks, always
## on the same ticks, for the same environment.
var _delivery_remainder: int = 0


## Run one tick of delivery. Returns how many whole units arrived.
func deliver(environment: EnvironmentDef) -> int:
	_delivery_remainder += environment.food_delivery_scaled
	var delivered := _delivery_remainder / Balance.RATE_SCALE
	_delivery_remainder -= delivered * Balance.RATE_SCALE
	food += delivered
	return delivered


## Take up to [param amount], returning how much was actually available. Callers must
## check the return value — at knife-edge density an importer competing for the last
## unit is the normal case, not an error.
func take_food(amount: int) -> int:
	var taken := mini(amount, food)
	food -= taken
	return taken


func add_food(amount: int) -> void:
	food += amount


func clone() -> Medium:
	var copy := Medium.new()
	copy.food = food
	copy._delivery_remainder = _delivery_remainder
	return copy


func _to_string() -> String:
	return "Medium(%d food)" % food
