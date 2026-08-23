class_name PlasmidDraft
extends RefCounted
## The plasmid being edited in the build phase. Spec §4, §7.0.
##
## Deliberately not a [Node]: the whole of the editor's behaviour — inserting, removing,
## reordering, validating — lives here and is tested headlessly, leaving the scene layer
## with nothing to do but draw a draft and forward input. Keep it that way. A rule that
## only exists inside a `_gui_input` handler cannot be tested and will drift.
##
## Holds its own block array rather than mutating a [Plasmid]. A plasmid is fixed for the
## duration of a battle (§7.0), so committing takes a snapshot via [method to_plasmid]
## and the sim never sees a half-finished edit.

signal changed

var _blocks: Array[Block] = []


static func from_notation(text: String) -> PlasmidDraft:
	var result := PlasmidNotation.parse(text)
	var draft := PlasmidDraft.new()
	if result.ok():
		draft._blocks = result.plasmid.blocks.duplicate()
	return draft


func size() -> int:
	return _blocks.size()


func is_empty() -> bool:
	return _blocks.is_empty()


func at(index: int) -> Block:
	return _blocks[index]


func blocks() -> Array[Block]:
	return _blocks.duplicate()


## Insert before [param index]. An index at or past the end appends, which is what makes
## "drop onto empty ring space" mean "add at the end" without a special case.
func insert_at(index: int, block: Block) -> void:
	_blocks.insert(clampi(index, 0, _blocks.size()), block)
	changed.emit()


func append(block: Block) -> void:
	insert_at(_blocks.size(), block)


func remove_at(index: int) -> Block:
	if not _in_range(index):
		return null
	var removed: Block = _blocks[index]
	_blocks.remove_at(index)
	changed.emit()
	return removed


## Move one block to sit where another currently is.
##
## Removing before inserting means the target index refers to the list *after* the block
## has left it — dragging a block one place to the right would otherwise put it back where
## it started, which reads as the editor ignoring the drag.
func move(from_index: int, to_index: int) -> void:
	if not _in_range(from_index) or from_index == to_index:
		return
	var moved: Block = _blocks[from_index]
	_blocks.remove_at(from_index)
	_blocks.insert(clampi(to_index, 0, _blocks.size()), moved)
	changed.emit()


## A snapshot the sim can run. The draft keeps editing its own copy afterwards.
func to_plasmid() -> Plasmid:
	var copied: Array[Block] = []
	for block in _blocks:
		copied.append(block.clone())
	return Plasmid.new(copied)


func notation() -> String:
	return PlasmidNotation.serialise(to_plasmid())


## What this plasmid would express, for the topology preview (M02) and the function
## readout (M03). Derived every call rather than cached — an editor that shows a stale
## preview is worse than one that shows none.
func transcripts() -> Array[Transcript]:
	return to_plasmid().transcribe()


func resolved_proteins() -> Array[ResolvedProtein]:
	var resolved: Array[ResolvedProtein] = []
	for transcript in transcripts():
		for protein in transcript.proteins:
			resolved.append(Adjacency.resolve(protein))
	return resolved


## Every protein translated from the block at [param ring_index].
##
## Usually one, but genuinely more than one when readthrough is in play: an unterminated
## gene is transcribed by its own promoter *and* by the upstream one, so its blocks end
## up in two different proteins (§4). The editor should be able to say so rather than
## silently picking a favourite.
func proteins_containing(ring_index: int) -> Array[ProteinDef]:
	var found: Array[ProteinDef] = []
	if ring_index < 0 or ring_index >= size():
		return found
	for transcript in transcripts():
		for protein in transcript.proteins:
			if protein.covers(ring_index):
				found.append(protein)
	return found


## The protein to show when this block is selected, or null if the block is not part of
## any. Selecting a promoter shows the first protein it expresses, since picking a gene's
## promoter obviously means "show me that gene".
func protein_containing(ring_index: int) -> ProteinDef:
	var found := proteins_containing(ring_index)
	if not found.is_empty():
		return found[0]

	if ring_index >= 0 and ring_index < size() and at(ring_index).kind == Block.Kind.PROMOTER:
		for transcript in transcripts():
			if transcript.promoter_index == ring_index and not transcript.proteins.is_empty():
				return transcript.proteins[0]
	return null


## Reasons this plasmid would not do anything useful, in plain language. Not errors —
## a half-built plasmid is a normal state to be in halfway through building one — but
## the things the commit button (M04) should refuse or warn about.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if _blocks.is_empty():
		found.append("The plasmid is empty.")
		return found

	if to_plasmid().promoter_indices().is_empty():
		found.append("No promoter, so nothing is ever expressed.")

	var expressed := 0
	var inert := 0
	for protein in resolved_proteins():
		expressed += 1
		if protein.is_inert():
			inert += 1
	if expressed == 0:
		found.append("No promoter produces a protein.")
	elif inert == expressed:
		found.append("Every protein this expresses is inert — none of them do any work.")

	var dead := dead_weight_blocks()
	if not dead.is_empty():
		# Pure cost: §4.1 charges growth for every block on the ring whether or not any
		# promoter ever reads it, so an untranscribed domain is worse than no block at all.
		found.append(
			"%d block(s) are never transcribed. They still raise your growth target."
			% dead.size()
		)

	return found


## Ring positions holding a domain or target that no promoter ever reads — typically
## blocks placed after the last terminator, where transcription never reaches them.
func dead_weight_blocks() -> PackedInt32Array:
	var covered := {}
	for transcript in transcripts():
		for protein in transcript.proteins:
			for index in protein.ring_indices:
				covered[index] = true

	var dead := PackedInt32Array()
	for i in range(_blocks.size()):
		if _blocks[i].is_structural():
			continue
		if not covered.has(i):
			dead.append(i)
	return dead


func is_viable() -> bool:
	return problems().is_empty()


func _in_range(index: int) -> bool:
	return index >= 0 and index < _blocks.size()
