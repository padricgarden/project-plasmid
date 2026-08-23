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

	return found


func is_viable() -> bool:
	return problems().is_empty()


func _in_range(index: int) -> bool:
	return index >= 0 and index < _blocks.size()
