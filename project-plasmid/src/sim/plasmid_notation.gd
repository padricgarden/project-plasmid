class_name PlasmidNotation
extends RefCounted
## A compact text form for plasmids: [code]P12-CAT-FOOD-TERM[/code].
##
## Exists so tests, NPC rosters (F06-M02) and saved runs (F08-M02) can state a plasmid
## as one readable line instead of assembling objects by hand. Every milestone after
## F01-M02 leans on it, which is why it lands this early.
##
## The ring is written starting at index 0. Because absolute position carries no meaning
## (§4), any rotation of a string describes the same plasmid — but [method serialise]
## always emits the rotation it was handed, so a round trip is exact.

const SEPARATOR := "-"

## Token spelling for every non-promoter kind. Promoters are written [code]P<period>[/code]
## so the tier is legible in the text rather than hidden behind a name.
const TOKENS := {
	Block.Kind.TERMINATOR: "TERM",
	Block.Kind.RBS: "RBS",
	Block.Kind.MEMBRANE_DOMAIN: "MEM",
	Block.Kind.TRANSPORTER_DOMAIN: "TRA",
	Block.Kind.CATABOLIC_ENZYME: "CAT",
	Block.Kind.FOOD: "FOOD",
}


## Outcome of a parse. Never a half-built plasmid: on failure [member plasmid] is null
## and [member error] says why, in terms a person can act on.
class ParseResult extends RefCounted:
	var plasmid: Plasmid
	var error: String

	func ok() -> bool:
		return error.is_empty()


static func serialise(plasmid: Plasmid) -> String:
	var parts := PackedStringArray()
	for block in plasmid.blocks:
		parts.append(token_for(block))
	return SEPARATOR.join(parts)


static func token_for(block: Block) -> String:
	if block.kind == Block.Kind.PROMOTER:
		return "P%d" % block.period
	return TOKENS[block.kind]


## Parse notation into a plasmid. Tolerates surrounding whitespace and lower case;
## [method serialise] emits the canonical upper-case form with no spaces.
static func parse(text: String) -> ParseResult:
	var result := ParseResult.new()
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		result.plasmid = Plasmid.new()
		return result

	var blocks: Array[Block] = []
	for raw in trimmed.split(SEPARATOR, false):
		var token := (raw as String).strip_edges().to_upper()
		if token.is_empty():
			continue
		var block := _block_for_token(token, result)
		if not result.ok():
			return result
		blocks.append(block)

	result.plasmid = Plasmid.new(blocks)
	return result


static func _block_for_token(token: String, result: ParseResult) -> Block:
	if token.begins_with("P"):
		var digits := token.substr(1)
		if not digits.is_valid_int():
			result.error = "malformed promoter token '%s' — expected P<period>" % token
			return null
		var period := digits.to_int()
		if not Balance.PROMOTER_PERIODS.has(period):
			# Enforced rather than merely documented: a period outside the family stops
			# racks settling on whole slot counts (§3.1). See docs/balance.md.
			result.error = (
				"promoter period %d is outside the closed family %s"
				% [period, str(Balance.PROMOTER_PERIODS)]
			)
			return null
		return Block.new(Block.Kind.PROMOTER, period)

	for kind in TOKENS:
		if TOKENS[kind] == token:
			return Block.new(kind)

	result.error = "unknown block token '%s'" % token
	return null
