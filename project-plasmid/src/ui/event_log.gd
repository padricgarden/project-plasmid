class_name EventLog
extends RefCounted
## The plain-language event log. Spec §9.3.
##
## §9.3 asks for lines like "Tick 41: Importer evicted Sensor-A from membrane slot 3" —
## a running account of why the battle went the way it did. This is a [b]view[/b] over
## [SimEvent] and holds no state of its own, which is what keeps the sim pure and the log
## testable: the same event stream always renders the same words.
##
## Every [enum SimEvent.Type] must have a sentence here. A silent event is a thing that
## happened to the player with no explanation, which is the failure mode §9 exists to
## prevent — a loss that reads as noise instead of as a misjudgement.

## Events too frequent to be worth a line each. Maturation fires most ticks once a cell
## is running, and a log that says "3 metabolites matured" forty times buries the
## eviction that actually decided the battle.
const ROUTINE := [
	SimEvent.Type.METABOLITE_PRODUCED,
	SimEvent.Type.METABOLITE_MATURED,
	SimEvent.Type.METABOLITE_SPENT,
	SimEvent.Type.FOOD_DELIVERED,
	SimEvent.Type.FOOD_IMPORTED,
	SimEvent.Type.FOOD_EXPORTED,
	SimEvent.Type.FOOD_CATABOLISED,
]


static func is_routine(event: SimEvent) -> bool:
	return event.type in ROUTINE


## One line, without the tick prefix.
static func sentence(event: SimEvent) -> String:
	var data := event.data
	match event.type:
		SimEvent.Type.METABOLITE_PRODUCED:
			return "Catabolism yielded %d metabolites." % data.get("count", 0)
		SimEvent.Type.METABOLITE_MATURED:
			return "%d metabolites matured into banked growth (%d total)." % [
				data.get("count", 0), data.get("banked_total", 0)
			]
		SimEvent.Type.METABOLITE_SPENT:
			return "Spent %d metabolites on %s." % [
				data.get("amount", 0), _reason_text(data.get("reason", &""))
			]
		SimEvent.Type.SPEND_FAILED:
			# §2.5's stall, and the most important line in the log when it appears.
			return "Could not afford %s — %d metabolites needed, %d in the pool." % [
				_reason_text(data.get("reason", &"")),
				data.get("amount", 0),
				data.get("available", 0),
			]
		SimEvent.Type.PROTEIN_BUILT:
			var where := _compartment_text(data.get("compartment", 0))
			if data.get("into_full_rack", false):
				# §2.3's teaching moment: expressing into a full rack is paid-for waste.
				return "Gene %d expressed into a full %s rack — it had to push something out." % [
					data.get("promoter", 0), where
				]
			return "Gene %d built a protein into %s (%d of %d slots used)." % [
				data.get("promoter", 0), where, data.get("occupied", 0), data.get("capacity", 0)
			]
		SimEvent.Type.PROTEIN_EVICTED:
			# §3.4: eviction is always visible and always logged in plain language.
			return "Gene %d evicted the oldest protein from gene %d out of %s." % [
				data.get("evicted_by_promoter", 0),
				data.get("evicted_promoter", 0),
				_compartment_text(data.get("compartment", 0)),
			]
		SimEvent.Type.FOOD_DELIVERED:
			return "%d food arrived in the medium (%d there now)." % [
				data.get("count", 0), data.get("in_medium", 0)
			]
		SimEvent.Type.FOOD_IMPORTED:
			return "Imported 1 food (%d held, %d left outside)." % [
				data.get("internal", 0), data.get("in_medium", 0)
			]
		SimEvent.Type.FOOD_EXPORTED:
			return "Pumped 1 food back out (%d held, %d outside)." % [
				data.get("internal", 0), data.get("in_medium", 0)
			]
		SimEvent.Type.FOOD_CATABOLISED:
			return "Digested 1 food for %d metabolites." % data.get("yield", 0)
		SimEvent.Type.FOOD_DESTROYED:
			return "An outside enzyme destroyed 1 food in the medium — nobody got it."
		SimEvent.Type.BATTLE_ENDED:
			return _ending_text(data)
		_:
			return "Something happened that the log has no words for."


## A full line, tick prefix included, in §9.3's format.
static func line(event: SimEvent) -> String:
	return "Tick %d: %s" % [event.tick, sentence(event)]


## Render a stream. [param include_routine] false keeps only the turning points —
## evictions, stalls, the ending — which is what makes the log readable during a battle
## rather than a wall of bookkeeping.
static func render(events: Array, include_routine: bool = false) -> PackedStringArray:
	var lines := PackedStringArray()
	for event in events:
		if not include_routine and is_routine(event):
			continue
		lines.append(line(event))
	return lines


static func _reason_text(reason: StringName) -> String:
	match reason:
		&"synthesis":
			return "protein synthesis"
		&"import":
			return "importing food"
		&"export":
			return "exporting food"
		_:
			return str(reason) if not str(reason).is_empty() else "something"


static func _compartment_text(compartment: int) -> String:
	match compartment:
		ResolvedProtein.Compartment.MEMBRANE:
			return "the membrane"
		ResolvedProtein.Compartment.EXTERNAL:
			return "outside the cell"
		_:
			return "the cytoplasm"


static func _ending_text(data: Dictionary) -> String:
	var banked: int = data.get("banked", 0)
	var target: int = data.get("target", 0)
	match data.get("outcome", -1):
		BattleOutcome.Kind.DIVIDED:
			return "Divided — %d growth banked against a target of %d." % [banked, target]
		BattleOutcome.Kind.LYSED:
			return "The cell burst. Toxin held above the threshold for too long."
		_:
			return "Time ran out with %d of %d growth banked." % [banked, target]
