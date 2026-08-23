class_name BlockStyle
extends RefCounted
## How each block kind looks and reads on screen. Presentation only — no rules here.
##
## Structural blocks are deliberately drab and effectors are deliberately loud. §5.3
## makes arrangement the whole puzzle, so the eye should land on the domains that do
## work and on the target blocks that aim them, not on the punctuation between genes.

const STYLES := {
	Block.Kind.PROMOTER: {
		"label": "P",
		"name": "Promoter",
		"colour": Color("6c7a89"),
		"blurb": "Fires on a fixed clock, expressing everything downstream of it.",
	},
	Block.Kind.TERMINATOR: {
		"label": "T",
		"name": "Terminator",
		"colour": Color("4a5560"),
		"blurb": "Ends a transcript. Without one, the gene reads on into the next.",
	},
	Block.Kind.RBS: {
		"label": "R",
		"name": "RBS",
		"colour": Color("5b6b7a"),
		"blurb": "Starts a second protein inside the same transcript.",
	},
	Block.Kind.MEMBRANE_DOMAIN: {
		"label": "MEM",
		"name": "Membrane Domain",
		"colour": Color("d98e32"),
		"blurb": "Embeds the protein in the membrane. Blocks left of it sit inside the cell, blocks right of it outside.",
	},
	Block.Kind.TRANSPORTER_DOMAIN: {
		"label": "TRA",
		"name": "Transporter",
		"colour": Color("3fa7d6"),
		"blurb": "Moves its target across the membrane. Which way depends on where the target sits.",
	},
	Block.Kind.CATABOLIC_ENZYME: {
		"label": "CAT",
		"name": "Catabolic Enzyme",
		"colour": Color("59c27a"),
		"blurb": "Destroys its target. On food, that yields metabolites.",
	},
	Block.Kind.FOOD: {
		"label": "FOOD",
		"name": "Food",
		"colour": Color("e2c044"),
		"blurb": "Aims the domains on both sides of it at food.",
	},
}

const UNKNOWN := {"label": "?", "name": "Unknown", "colour": Color("ff00ff"), "blurb": ""}


static func of(kind: Block.Kind) -> Dictionary:
	return STYLES.get(kind, UNKNOWN)


## Promoters carry their period in the label, since the tier is the whole decision
## (§3.1) and hiding it behind a colour would make two very different genes look alike.
static func label_for(block: Block) -> String:
	if block.kind == Block.Kind.PROMOTER:
		return "P%d" % block.period
	return of(block.kind)["label"]


static func colour_for(block: Block) -> Color:
	return of(block.kind)["colour"]


static func name_for(block: Block) -> String:
	if block.kind == Block.Kind.PROMOTER:
		return "Promoter (every %d ticks)" % block.period
	return of(block.kind)["name"]


## The palette, grouped so the three kinds of block read as three different jobs:
## punctuation that directs transcription, domains that do work, and targets that aim
## them. §5.3 makes aiming a domain the core move, so a target must not look like just
## another domain.
static func palette_groups() -> Array:
	var promoters: Array[Block] = []
	for period in Balance.PROMOTER_PERIODS:
		promoters.append(Block.new(Block.Kind.PROMOTER, period))

	return [
		{
			"name": "Promoters — slower is cheaper, faster holds more slots",
			"blocks": promoters,
		},
		{
			"name": "Structure — where genes start and stop",
			"blocks": [Block.new(Block.Kind.TERMINATOR), Block.new(Block.Kind.RBS)],
		},
		{
			"name": "Domains — the parts that do work",
			"blocks": [
				Block.new(Block.Kind.MEMBRANE_DOMAIN),
				Block.new(Block.Kind.TRANSPORTER_DOMAIN),
				Block.new(Block.Kind.CATABOLIC_ENZYME),
			],
		},
		{
			"name": "Targets — aim the domains on both sides",
			"blocks": [Block.new(Block.Kind.FOOD)],
		},
	]


## Every block the palette offers, flattened.
static func palette() -> Array[Block]:
	var offered: Array[Block] = []
	for group in palette_groups():
		for block in group["blocks"]:
			offered.append(block)
	return offered
