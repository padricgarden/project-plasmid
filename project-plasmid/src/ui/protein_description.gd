class_name ProteinDescription
extends RefCounted
## Plain language for what a protein actually does. Spec §5.3, §9.
##
## [b]Describes; does not draw.[/b] The topology preview already shows where the membrane
## sits and which way the arrow points, so this says what the arrangement *means* rather
## than painting a second picture in words. Two explanations of the same thing drift.
##
## Every sentence is derived from a [ResolvedProtein], so the words cannot disagree with
## the arrow above them or with what the sim will do.


## One line per effector, plus a line saying where the protein sits.
static func lines(
	resolved: ResolvedProtein, environment: EnvironmentDef = null
) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(compartment_line(resolved))

	if resolved.functions.is_empty():
		out.append("It has no enzyme or transporter, so it does no work at all.")
		return out

	for function in resolved.functions:
		out.append(function_line(function, resolved, environment))
	return out


## A single sentence, for somewhere there is only room for one.
static func summary(resolved: ResolvedProtein, environment: EnvironmentDef = null) -> String:
	if resolved.functions.is_empty():
		return "Does nothing — no enzyme or transporter."
	var active := resolved.active_functions()
	if active.is_empty():
		return "Does nothing. " + resolved.functions[0].reason.capitalize() + "."
	return function_line(active[0], resolved, environment)


static func compartment_line(resolved: ResolvedProtein) -> String:
	match resolved.compartment:
		ResolvedProtein.Compartment.MEMBRANE:
			return "Sits in the membrane, so it can move things across it."
		ResolvedProtein.Compartment.EXTERNAL:
			return "Is secreted outside the cell."
		_:
			return "Sits in the cytoplasm, inside the cell."


static func function_line(
	function: ProteinFunction, resolved: ResolvedProtein, environment: EnvironmentDef = null
) -> String:
	var targets := _target_names(function)

	match function.kind:
		ProteinFunction.Kind.IMPORT:
			return "Pulls %s in from the medium, for %d metabolite per unit." % [
				targets, Balance.TRANSPORT_COST
			]
		ProteinFunction.Kind.EXPORT:
			return "Pushes %s out into the medium, for %d metabolite per unit." % [
				targets, Balance.TRANSPORT_COST
			]
		ProteinFunction.Kind.EXCHANGE:
			return "Swaps %s across the membrane, free of charge." % targets
		ProteinFunction.Kind.CATABOLISE:
			return _catabolism_line(function, resolved, targets, environment)
		_:
			# The expensive mistake: it still occupies a slot and still pays synthesis
			# upkeep every time its promoter fires (§3.2).
			return "Does nothing — %s. It still costs a slot and its upkeep." % function.reason


static func _catabolism_line(
	function: ProteinFunction,
	resolved: ResolvedProtein,
	targets: String,
	environment: EnvironmentDef
) -> String:
	if resolved.is_outside(function.effector_index):
		# §8's denial elite, falling out of topology: the metabolites are released
		# outside the cell, where this cell cannot reach them.
		return (
			"Destroys %s out in the medium. The metabolites are released outside, "
			+ "so nobody gets them — this starves rivals rather than feeding you."
		) % targets

	if environment == null:
		return "Digests %s inside the cell, yielding metabolites." % targets
	return "Digests %s inside the cell, yielding %d metabolites per unit." % [
		targets, environment.food_yield
	]


static func _target_names(function: ProteinFunction) -> String:
	if function.targets.is_empty():
		return "nothing"
	var names := PackedStringArray()
	for kind in function.targets:
		names.append(str(BlockStyle.of(kind)["name"]).to_lower())
	if names.size() == 1:
		return names[0]
	return " and ".join(names)
