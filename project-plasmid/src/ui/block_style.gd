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


## Every block the palette offers, in the order it should be shown: structure first,
## then the domains that do work, then the targets that aim them.
static func palette() -> Array[Block]:
	var offered: Array[Block] = []
	for period in Balance.PROMOTER_PERIODS:
		offered.append(Block.new(Block.Kind.PROMOTER, period))
	offered.append(Block.new(Block.Kind.TERMINATOR))
	offered.append(Block.new(Block.Kind.RBS))
	offered.append(Block.new(Block.Kind.MEMBRANE_DOMAIN))
	offered.append(Block.new(Block.Kind.TRANSPORTER_DOMAIN))
	offered.append(Block.new(Block.Kind.CATABOLIC_ENZYME))
	offered.append(Block.new(Block.Kind.FOOD))
	return offered
