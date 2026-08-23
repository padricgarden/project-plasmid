class_name Plasmid
extends RefCounted
## The circular plasmid: an ordered ring of blocks. Spec §4.
##
## Absolute position carries no meaning — gene dosage is uniform and the origin of
## replication was cut from the design. [b]Order and adjacency are everything.[/b] The
## ring still matters, because transcription wraps: an unterminated gene at the end of
## the ring reads straight into the first.

var blocks: Array[Block]


func _init(p_blocks: Array[Block] = []) -> void:
	blocks = p_blocks


func size() -> int:
	return blocks.size()


func is_empty() -> bool:
	return blocks.is_empty()


## Block at an index, wrapping in both directions. The ring has no ends.
func at(index: int) -> Block:
	assert(not blocks.is_empty(), "cannot index into an empty plasmid")
	return blocks[posmod(index, blocks.size())]


## Ring positions of every promoter, ascending.
func promoter_indices() -> PackedInt32Array:
	var found := PackedInt32Array()
	for i in range(blocks.size()):
		if blocks[i].kind == Block.Kind.PROMOTER:
			found.append(i)
	return found


## What every promoter on the ring produces, in ring order — which keeps the result
## deterministic, as §4.2 requires of everything the sim does.
func transcribe() -> Array[Transcript]:
	var transcripts: Array[Transcript] = []
	for i in promoter_indices():
		transcripts.append(transcribe_from(i))
	return transcripts


## Read forward from one promoter and split what it reads into proteins.
##
## Reading stops after a terminator, or on returning to the promoter it started from.
## That second guard is what makes a ring with no terminator anywhere transcribe itself
## exactly once instead of looping forever.
##
## Promoters met along the way are read [i]through[/i], not stopped at: that is what
## "one promoter drives two genes" means in §4. The downstream promoter still fires its
## own transcript independently — omitting a terminator adds a transcript, it does not
## replace one.
##
## Structural blocks are consumed but never translated, so a fused readthrough protein
## is the concatenation of both genes' domains with the promoter between them dropped.
func transcribe_from(promoter_index: int) -> Transcript:
	var promoter := at(promoter_index)
	assert(
		promoter.kind == Block.Kind.PROMOTER,
		"transcribe_from was given index %d, which is not a promoter" % promoter_index
	)

	var proteins: Array[ProteinDef] = []
	var current: Array[Block] = []
	var current_indices := PackedInt32Array()

	for offset in range(1, blocks.size()):
		var ring_index := posmod(promoter_index + offset, blocks.size())
		var block := blocks[ring_index]
		match block.kind:
			Block.Kind.TERMINATOR:
				break
			Block.Kind.RBS:
				# An RBS starts a new protein inside the same transcript (§4). A leading
				# one is a no-op rather than an empty protein.
				if not current.is_empty():
					proteins.append(ProteinDef.new(current.duplicate(), current_indices.duplicate()))
					current.clear()
					current_indices.clear()
			Block.Kind.PROMOTER:
				pass  # read through, per §4
			_:
				current.append(block)
				current_indices.append(ring_index)

	if not current.is_empty():
		proteins.append(ProteinDef.new(current.duplicate(), current_indices.duplicate()))

	return Transcript.new(promoter_index, promoter.period, proteins)


func clone() -> Plasmid:
	var copied: Array[Block] = []
	for block in blocks:
		copied.append(block.clone())
	return Plasmid.new(copied)


func _to_string() -> String:
	return "Plasmid(%d blocks)" % blocks.size()
