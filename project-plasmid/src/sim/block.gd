class_name Block
extends RefCounted
## One block on the plasmid. Spec §5.
##
## Scoped to the Prototype 1 grammar: the structural blocks, plus Membrane Domain,
## Transporter, Catabolic Enzyme and the Food target. Toxin, Metabolite, Sensing, TF,
## Anabolic, Anchor, Degron and the Extracellular Domain arrive with F05 — left out
## rather than stubbed, so no code half-handles a kind it cannot resolve.

enum Kind {
	## Fires on a fixed period, transcribing what follows it (§4.2).
	PROMOTER,
	## Ends a transcript. Without one, transcription reads through into the next gene
	## and around the ring (§4).
	TERMINATOR,
	## Starts a new protein inside a transcript — the operon, and the pressure valve
	## for the per-promoter penalty (§4).
	RBS,
	## Embeds the protein in the membrane. Blocks to its left are cytoplasmic, blocks
	## to its right extracellular (§5.1).
	MEMBRANE_DOMAIN,
	## Unified import / export / exchange. Which one is read off topology in M03 (§5.3),
	## never off the block itself.
	TRANSPORTER_DOMAIN,
	## Destroys its target. On food, yields metabolites (§5.1).
	CATABOLIC_ENZYME,
	## Target block. Sets the target for [i]both[/i] its neighbours (§5.3).
	FOOD,
}

## Blocks that direct transcription but are never part of a protein.
const STRUCTURAL := [Kind.PROMOTER, Kind.TERMINATOR, Kind.RBS]

var kind: Kind

## Ticks between firings. Promoters only; 0 on every other kind. Must be one of
## [constant Balance.PROMOTER_PERIODS] — the family is closed, see docs/balance.md.
var period: int = 0


func _init(p_kind: Kind, p_period: int = 0) -> void:
	kind = p_kind
	period = p_period


func is_structural() -> bool:
	return kind in STRUCTURAL


func clone() -> Block:
	return Block.new(kind, period)


func _to_string() -> String:
	if kind == Kind.PROMOTER:
		return "Block(PROMOTER/%d)" % period
	return "Block(%s)" % Kind.keys()[kind]
