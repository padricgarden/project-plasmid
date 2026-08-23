class_name Transcript
extends RefCounted
## Everything one promoter produces when it fires. Spec §4, §4.2.
##
## Grouping proteins under their promoter is what M04 needs: the promoter owns the
## period, and each firing pays for and racks every protein in the transcript at once.
## Operon members therefore share a clock and share regulation, which is the tradeoff
## §4 names for using an RBS instead of a second promoter.

## Where on the ring the driving promoter sits.
var promoter_index: int

## Ticks between firings, copied from the promoter.
var period: int

## In transcript order. Empty if the promoter reads straight into a terminator.
var proteins: Array[ProteinDef]


func _init(
	p_promoter_index: int, p_period: int, p_proteins: Array[ProteinDef] = []
) -> void:
	promoter_index = p_promoter_index
	period = p_period
	proteins = p_proteins


## Total blocks translated across every protein in this transcript. Not the same as the
## number of blocks read — structural blocks are consumed but never translated.
func translated_length() -> int:
	var total := 0
	for protein in proteins:
		total += protein.length()
	return total


func _to_string() -> String:
	return "Transcript(@%d, every %d ticks, %d protein(s))" % [
		promoter_index, period, proteins.size()
	]
