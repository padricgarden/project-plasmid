class_name GeneExpression
extends RefCounted
## Compiles a plasmid into what its promoters will express. Spec §2.2, §3.5, §4.
##
## Transcription (M02) says which blocks become which proteins; adjacency (M03) says
## what those proteins do; this puts the two together and prices the result, once, so
## the tick loop only has to check a period and pay a bill.


static func compile(plasmid: Plasmid) -> Array[ExpressionUnit]:
	var units: Array[ExpressionUnit] = []
	for transcript in plasmid.transcribe():
		var products: Array[GeneProduct] = []
		for protein in transcript.proteins:
			products.append(
				GeneProduct.new(
					protein,
					Adjacency.resolve(protein),
					transcript.promoter_index,
					synthesis_cost(protein),
					build_ticks(protein)
				)
			)
		units.append(ExpressionUnit.new(transcript.promoter_index, transcript.period, products))
	return units


## One metabolite per three blocks, rounded up (§2.2).
##
## Counts the protein's own blocks — what is actually synthesised — not the gene's
## blocks on the ring. A promoter is not translated, and counting it would make an
## operon cost more than the identical fused transcript.
static func synthesis_cost(protein: ProteinDef) -> int:
	if protein.is_empty():
		return 0
	return ceili(float(protein.length()) / float(Balance.BLOCKS_PER_SYNTHESIS_UNIT))


## Ticks from firing to occupying a slot (§3.5). At least one, so a protein never
## appears on the same tick it was paid for.
static func build_ticks(protein: ProteinDef) -> int:
	return maxi(1, protein.length() * Balance.BUILD_TICKS_PER_BLOCK)
