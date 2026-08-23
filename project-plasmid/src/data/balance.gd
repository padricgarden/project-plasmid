class_name Balance
extends RefCounted
## Global balance constants. Never instantiated.
##
## Registered in docs/balance.md — any constant added here gets a row there in the
## same change, with its spec section and this file as its location.
##
## Only genuinely global values belong here. Per-block, per-promoter and especially
## per-environment values (food delivery rate, ambient toxin) live in Resources under
## src/data/, because spec §7.4 varies them per battle.


## Ticks an immature metabolite ages before it converts to +1 banked growth and
## leaves the pool permanently. Spec §2.1.
##
## Paired with environmental shock frequency, this is the primary difficulty knob
## (§7.5): at 5 ticks, toxin pulses every ~20 ticks leave buffers intact, while
## pulses every ~6 shred them and force just-in-time play.
const MATURATION_AGE := 5


## Promoter firing periods in ticks, slowest first. Spec §4.2.
##
## The divisors of 12, and the family is [b]closed on purpose[/b]. Steady-state slot
## count is `slots × rate / total_rate` (§3.1), so a rack lands on whole numbers only
## when competing rates are small integers over a common base. A period from outside —
## 8 against 12, say — gives 4.8 : 3.2 and a rack that cycles forever instead of
## settling, undoing the stability §3.4 guarantees.
##
## [method PlasmidNotation.parse] rejects anything outside this list, so the rule is
## enforced rather than merely written down. Read docs/balance.md before adding a tier;
## the answer is usually to redesign around a new base, not to append one.
const PROMOTER_PERIODS: Array[int] = [12, 6, 4, 3, 2]


## Protein slots in each compartment. Spec §3.
##
## Eight rather than five: at five the only reachable splits were crude (4:1, 3:2),
## while eight expresses 4:3:1 and 3:3:2 and gives promoter tuning enough resolution to
## be a real skill (§3.4). Rare events expand one compartment at a time (§8), which is
## why [SlotRack] takes its capacity as an argument instead of reading this directly.
const SLOTS_PER_COMPARTMENT := 8


## Blocks per metabolite of synthesis cost, rounded up. Spec §2.2 — a 3-block protein
## costs 1, a 7-block protein costs 3.
##
## Synthesis is charged at all so that expression is an economic decision: a promoter
## firing into a full rack is actively wasting money, and noticing that is the intended
## teaching moment (§2.3).
const BLOCKS_PER_SYNTHESIS_UNIT := 3


## Ticks to build one block of a protein. Spec §3.5 says length determines build time
## but gives no number; one tick per block is a decision made here.
##
## It keeps a fused readthrough transcript visibly slower to express than two short
## genes — §4's stated cost for omitting a terminator — without making an emergency
## efflux gene so sluggish that TF gating stops paying for itself (§3.2).
const BUILD_TICKS_PER_BLOCK := 1


## Ticks between actions for a resident effector. Spec §2.2, §2.3, §2.4.
##
## §2.2 attaches a 3-tick cooldown only to Catabolic+Food and gives transport none — but
## the cooldown has to be universal for the spec's own arithmetic to work. §2.3's ceiling
## ("eight internal slots ≈ 8 metabolites/tick gross") needs one enzyme to yield exactly
## 1/tick, which is 3 metabolites every 3 ticks. §2.4's baseline needs one importer to
## cost 0.33/tick, which is 1 food every 3 ticks. Both land only at a shared cadence of 3.
const EFFECTOR_COOLDOWN_TICKS := 3


## Metabolites to move one unit of one target across the membrane. Spec §2.2.
const TRANSPORT_COST := 1


## Rates are stored as integers per this many ticks, so the economy never touches a
## float. §7.4's delivery rates become 150 / 75 / 40 rather than 1.5 / 0.75 / 0.4.
const RATE_SCALE := 100


## Buffer on top of one full round of synthesis, endowed to a cell at the start of a
## battle. [b]The spec does not mention any endowment, and without one the game cannot
## start at all.[/b]
##
## At tick 0 the pool is empty, so no promoter can pay for synthesis; with no proteins
## nothing imports or catabolises, so the pool stays empty and the cell deadlocks
## permanently. Measured at F01-M05: a starting cell with no endowment stalls 68 times
## in 400 ticks and never racks a single protein.
##
## Scaled to the genome rather than fixed. A flat endowment large enough for a starting
## cell leaves a six-gene plasmid unable to fund its first import: its transcripts cost
## exactly the endowment, the importers then stall, and the cell deadlocks with a full
## medium in front of it. Measured at F01-M05. Since drafting only grows the plasmid
## (§8), a flat value would make soft-locks more likely as a run goes on.
##
## This is an endowment, not free growth — it enters the pool at age 0 and banks only if
## the cell fails to spend it (§2.1), so a fast starter converts none of it.
const STARTING_METABOLITE_BUFFER := 4


## §4.1's burden curve: `target = BASE + c × (B^exp − B_start^exp)`, normalised so a
## starting genome sits at exactly BASE.
##
## The spec flags its own `c` as probably too weak and states a preference for letting
## food scarcity do the limiting instead (§7.4). Measured at F01-M05 rather than assumed;
## see docs/balance.md.
const BASE_GROWTH_TARGET := 100
const BURDEN_COEFFICIENT := 1.5
const BURDEN_EXPONENT := 1.1
const STARTING_BLOCK_COUNT := 12
