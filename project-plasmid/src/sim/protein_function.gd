class_name ProteinFunction
extends RefCounted
## One thing an effector domain does, resolved from its neighbours. Spec §5.3.
##
## Produced by [Adjacency]; never stored on a block. The same Transporter block is an
## importer, an exporter, an exchanger or dead weight depending entirely on what sits
## next to it, which is the property §5.3 exists to create.
##
## Carries no costs. What an action costs is M05's, partly because §2.2 makes exchange
## free while §5.3 rule 2 doubles a two-target effector — two rules that would fight if
## a multiplier lived here.

enum Kind {
	## Destroys its target; on food, yields metabolites (§5.1).
	CATABOLISE,
	## Moves the target inward. Target sits on the extracellular side (§5.3 rule 4).
	IMPORT,
	## Moves the target outward. Target sits on the cytoplasmic side (§5.3 rule 4).
	EXPORT,
	## Bidirectional, both targets required, free (§2.2, §5.3 rule 4).
	EXCHANGE,
	## Present but doing nothing. [member reason] says why, because "this block is dead
	## weight" is exactly what the build phase has to be able to tell the player (§9.2).
	INERT,
}

var kind: Kind

## Position of the effector within its protein, for the topology preview (F02-M02).
var effector_index: int

## Distinct [enum Block.Kind] targets, in block order. Empty when inert.
var targets: Array

## Plain reason this effector does nothing. Empty unless [member kind] is INERT.
var reason: String


func _init(
	p_kind: Kind, p_effector_index: int, p_targets: Array = [], p_reason: String = ""
) -> void:
	kind = p_kind
	effector_index = p_effector_index
	targets = p_targets
	reason = p_reason


static func inert(effector_index: int, reason: String) -> ProteinFunction:
	return ProteinFunction.new(Kind.INERT, effector_index, [], reason)


func is_active() -> bool:
	return kind != Kind.INERT


func _to_string() -> String:
	if kind == Kind.INERT:
		return "INERT@%d (%s)" % [effector_index, reason]
	var names := targets.map(func(t): return Block.Kind.keys()[t])
	return "%s@%d[%s]" % [Kind.keys()[kind], effector_index, "+".join(names)]
