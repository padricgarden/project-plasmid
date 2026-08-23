# Untitled Syn Bio Autobattler — Design Spec v0.3

**Genre:** Autobattler roguelike / engine builder
**Core fantasy:** Design a cell. Watch it outgrow a rival.
**Loop:** Arrange gene blocks on a circular plasmid → commit → watch the battle resolve on a tick clock → draft new blocks → repeat.

---

## 1. Core Concept

The player edits a **circular plasmid**. Promoters on the plasmid fire on a clock, transcribing the blocks downstream of them into **proteins**. A protein's function is determined entirely by the **order and adjacency** of its constituent blocks — the same blocks in a different arrangement do something different.

Proteins occupy **slots** in one of three compartments (internal, membrane, external). Slots are scarce. Proteins do work: import food, break it down into metabolites, pump toxins, sense conditions, regulate other genes.

**Metabolites are both the currency and the score.** Every action costs the exact resource that wins the game. This is the central tension of the design and every subsystem should reinforce it.

**Win condition:** Reach 100% growth before the opponent and divide.
**Loss conditions:** Opponent divides first, or the cell lyses (toxin above threshold for N consecutive ticks), or time limit expires with lower growth.

---

## 2. The Metabolite Economy

### 2.1 Maturation pipeline

1. Catabolic enzymes emit **immature metabolites** into a pool.
2. Each immature metabolite carries an age counter. At **age 5 ticks**, it converts to **+1 banked growth** and leaves the pool permanently.
3. Spending draws from the pool **youngest-first** (players should never feel robbed of nearly-matured metabolites).
4. **Banked growth is safe.** It cannot be spent, stolen, or lost.

The immature pool, however, is vulnerable — it can be drained by emergency spending, stolen by parasitic opponents, or destroyed by environmental effects. This makes bursty economies structurally different from steady-state ones.

### 2.2 Cost table

| Action | Metabolite cost | Notes |
|---|---|---|
| Catabolic + Food | — | **Yields 3** per food unit. 3-tick cooldown. |
| Transport (import or export), 1 target | 1 per unit | The workhorse tax. |
| Exchange (2 targets, bidirectional) | 0 | Requires both targets present. The efficiency play. |
| Catabolic on toxin | 1 per unit | Defense is cheap. |
| Anabolic (synthesize toxin) | 2 per unit | Offense costs double defense. |
| Anabolic (synthesize food) | 4 per unit | Deliberately bad ROI; niche/combo use only. |
| Sensing | 0 | Never tax the circuit itself. |
| TF | 0 | Never tax the circuit itself. |
| **Protein synthesis** | **1 per 3 blocks, rounded up** | 3-block protein = 1. 7-block = 3. |

### 2.3 Key ratios and their intent

- **3:1 yield-to-transport.** Import-and-catabolize returns 200% on metabolites spent. Building an import engine is always correct *when food is available*. The limiter is food scarcity in the shared medium, not the arithmetic. **Contention does the balancing, not the numbers.**
- **Synthesis is charged** so expression is an economic decision. A promoter firing into a full slot rack is actively wasting money — players notice, then fix it with a TF. That's the intended teaching moment.
- **Slots cap the engine, not diminishing returns.** Eight internal slots = eight catabolic enzymes max ≈ 8 metabolites/tick gross ceiling. Past that, growth must come from efficiency (exchangers, higher-tier food, extracellular pre-digestion, parasitism), not from more of the same.
- **At 24 slots, food supply becomes the true limiter — not slots.** A full engine can consume far more food than a scarce medium provides, so the binding constraint moves off the plasmid and into the environment. This is the intended end state (contention balances, not arithmetic), but it means **medium food delivery rate is now a first-class tuning parameter** and must be specified per environment. See §7.4.

### 2.4 Baseline benchmark

Starting cell: one Catabolic+Food, one importer feeding it.

- Gross: 3 metabolites / 3 ticks = **1.0/tick**
- Import cost: 1 food / 3 ticks = **0.33/tick**
- Synthesis overhead: ~0.07/tick
- **Net ≈ 0.6 metabolites/tick** → ~165 ticks to reach 100 growth.

Battle time limit ≈ **120 ticks**, so the naked starting build cannot coast to a win. All improvements are measured against this baseline. NPCs should demand ~2–3× baseline throughput by mid-run.

### 2.5 The death spiral

If the pool hits zero, pumps stall — the cell can't afford to expel the toxin killing it. **This is intended drama.** Banked growth stays safe, so a loss reads as an economic misjudgment rather than a rug pull, and the counterplay (keep a buffer, gate spending with sensors) is legible.

---

## 3. Protein Slots

**Fixed slots per compartment: 8 internal / 8 membrane / 8 external** (24 resident proteins total). Expandable by rare events, one compartment at a time.

New proteins **evict the oldest** protein in their compartment (FIFO).

**One protein per slot.** Copies are not free — a second catabolic enzyme costs a second slot. This forces the central build decision: **breadth or depth.** Eight different internal proteins, or five copies of your best one plus three utilities.

### 3.1 The emergent rule

> **Steady-state slot count = share of expression rate in that compartment × slots available.**

If protein A fires every 4 ticks and B every 12 ticks, both internal with 8 slots, the rack settles at 6 A : 2 B. Players discover this the first time a strong promoter starves a weak one.

**Consequence: promoter strength is how much slot share you buy, and you pay for it every tick.** Because slots are quantized and eviction is FIFO, a stronger promoter doesn't produce "more protein" — it holds *more slots against competing genes*, and pays synthesis cost forever to keep holding them. Maxing every promoter changes the composition not at all and the cost enormously. The skill is finding the **minimum promoter rate that holds the slot count you want.**

This is the design's most unusual and most valuable property — protect it.

### 3.2 Churn is the rent on slot share

In steady state, promoters keep firing into a full rack, and each new protein evicts an old one. **You pay synthesis cost continuously just to maintain your composition.** A 3-block protein on a 4-tick promoter is 0.25 metabolites/tick, forever.

This is intended, not a bug. It is the pressure that makes TF gating pay for itself, and it is the reason a lean specialist beats a bloated generalist even before plasmid burden is counted. Surface it directly in the readout panel as **upkeep/tick**.

### 3.2 What slots do for the design

- **Membrane slots are the contested compartment.** Every transporter and sensor competes for them, making topology decisions genuinely costly.
- **Regulation becomes mandatory.** An ungated gene permanently eats slot share. This is the pressure that makes Sensing+TF circuits pay off.
- **Emergency genes work by construction.** A TF-repressed efflux gene occupies zero slots until toxin appears, then floods in and evicts idle proteins. Correct behavior falls straight out of the rules.

### 3.4 Slot rules

- **One protein per slot, no stacking.** Throughput scales by spending slots, not by expression volume.
- **Eviction is always visible and logged in plain language.**
- **Guarantee stability.** A single eviction is a 12.5% composition swing at 8 slots. Still coarse enough that promoter firing must be **deterministic** (§4.2), so the rack settles into a stable repeating cycle rather than a random walk.
- **8 slots makes ratios expressible.** At 5 slots the only reachable splits were crude (4:1, 3:2). At 8 the player can hit 5:2:1 or 6:2 — promoter tuning now has enough resolution to be a real skill rather than a coin flip between two layouts. This is the main reason to prefer 8 over 5.
- **Anchor block** (+1 length, small metabolite upkeep): exempts a protein from FIFO. Holds its slot until actively degraded. Without stacking, this is a **core block, not a niche one** — it is the only way to guarantee a floor of one critical protein (a sensor, a lone efflux pump) against a high-rate economy gene that would otherwise crowd it out. Real cost: it permanently shrinks the contested pool, and an anchored protein pays no churn but also can't be swapped out when conditions change.
- **Degron block:** vacates the slot after N ticks. Reads as a downside; is actually a burst-economy enabler and essential for fast-clearing sensor responses.

### 3.5 Superseded systems

Protein half-life/decay and ribosome contention are **cut**. Slots handle both jobs more legibly. Protein length still determines **build time in ticks**. Ribosome count survives only as an environment modifier (antibiotics slow all synthesis globally).

---

## 4. The Plasmid

Circular, with meaningful position.

*(Origin of replication and positional gene dosage: **cut.** Too much complexity for the return. Gene dosage is uniform; the only expression levers are promoter strength and operator regulation, which keeps §3.1 clean.)*

The ring is still meaningful because **readthrough wraps** — the last gene on the plasmid reads into the first if unterminated. Order and adjacency matter; absolute position does not.

- **Terminators.** A gene without one reads through into the next. Omitting a terminator is a combo (one promoter drives two genes) with a cost (one long transcript, more build ticks, no independent regulation).
- **RBS blocks → operons.** Inside a transcript, an RBS starts a new protein. One promoter can produce three separate proteins. This is the pressure valve for the per-promoter penalty. Tradeoff: operon members share a clock and share regulation.
### 4.1 Plasmid burden

Growth required to divide scales superlinearly with block count *B*:

> **Target = 100 + c × (B^1.1 − B_start^1.1)**

Normalized so the starting genome (~12 blocks) sits at exactly 100. With **c = 1.5**:

| Blocks | Growth target | Effective tax |
|---|---|---|
| 12 (start) | 100 | — |
| 20 | 117 | +17% |
| 30 | 140 | +40% |
| 45 | 176 | +76% |
| 60 | 212 | +112% |

**Note on the exponent:** 1.1 is nearly linear, and that's correct here — the *real* diminishing return comes from slots, not from the curve. Because only 24 proteins can ever be resident, block count and throughput decouple hard past a full rack: early blocks fill empty slots and buy a lot; late blocks buy specialization and conditional circuits, which are situational. **Tune `c`, not the exponent.**

**⚠ c = 1.5 is likely too weak at 8 slots.** A modest full-engine build (5 catabolic + 5 importers, ~38 blocks) nets ~2.3 metabolites/tick against a target of ~159 → **~68 ticks to divide**, versus ~165 for the starting cell. The tax is not restraining engine-building at all. Either raise `c` toward 3–4, or accept that burden is a *pruning nudge* rather than a real cap and let food scarcity do the limiting. **Prefer the latter** — it keeps balance in the environment where it's more interesting — but that makes §7.4 mandatory rather than optional.

### 4.2 Promoters

- Fire on a clock; better promoters have shorter periods.
- **Firing is deterministic** — a fixed period, not a per-tick probability. With 5-slot compartments and no stacking, stochastic firing would let slot composition random-walk, and a player who built for 3 enzymes + 2 pumps could find themselves at 5 + 0 when a toxin pulse lands. That is an unearned loss. **Run variance comes from the environment and the draft, not from expression noise.**
- Each carries an **operator slot** that accepts a colored operator, addressable by TFs (see §6).
- Promoters may default ON (repressible) or OFF (activatable).
- Additional promoters carry a speed/efficiency penalty, offset by TF gating and by operons.

---

## 5. Block Grammar

### 5.1 Effector blocks

| Block | Function |
|---|---|
| **Membrane Domain** | Embeds the protein in the membrane. Blocks to the left are cytoplasmic; blocks to the right are extracellular. |
| **Extracellular Domain** | Secretes the protein outside the cell. |
| **Transporter Domain** | Unified import/export/exchange. Behavior read off topology (see §5.3). |
| **Sensing Domain** | Turns neighboring domains on/off based on presence of a target. |
| **Catabolic Enzyme** | Destroys target. On food, yields metabolites. |
| **Anabolic Enzyme** | Generates target. Costs metabolites. |
| **TF Domain** | Binds a matching operator, repressing or activating that promoter. Conditional if a Sensing domain is attached. |
| **Anchor** | Exempts protein from FIFO eviction. Upkeep cost. |
| **Degron** | Vacates slot after N ticks. |

### 5.2 Target blocks

**Food**, **Toxin**, **Metabolite** — set the target for adjacent effector domains.

### 5.3 Adjacency rules

These are the rules that make arrangement a puzzle. Pin them down early; they cascade into everything.

1. **A target domain sets the target for *both* neighbors.** So `Transporter–Food–Catabolic` is a two-for-one efficiency play. Dense sandwiches are the primary skill expression.
2. **An effector with two different target neighbors acts on both**, at doubled metabolite cost.
3. **Transport and sensing only function when membrane-embedded.** A cytoplasmic Transporter+Food does nothing. This is the constraint that makes topology matter at all.
4. **Unified transporter directionality:**
   - Target domain on the **extracellular** side → **import**
   - Target domain on the **cytoplasmic** side → **export**
   - Target domains on **both** sides → **exchange** (both targets required, no metabolite cost)

The unified transporter cuts block count and makes the same block do different things depending on placement. Cost: reduced first-ten-minutes legibility. **Mitigate with a topology preview that draws the membrane and directional arrows — do not mitigate by splitting the block back apart.**

### 5.4 Starting protein

`Catabolic Enzyme + Food Domain` — converts food to metabolites. Internal. Three blocks including promoter overhead.

---

## 6. Regulation and Logic

**Addressing: operator colors.** TF blocks carry a color; promoters have an operator slot accepting a matching color. **3–4 colors total.** UI: colored keyhole on the promoter, colored key on the block.

**Logic basis:**
- Multiple Sensing domains on one TF → **AND**
- Multiple TFs on one promoter → **NOR**
- Activator TFs + default-OFF promoters → cascades and inverters

Together these form a complete logic basis. Players should **discover** this rather than be taught it.

**The intended "aha" moment (~battle 3):** `Sensing + Toxin + TF` gating a toxin-efflux gene. The player builds their first conditional circuit and sees slot pressure drop.

---

## 7. Battles

### 7.0 Timing and input

- **120 ticks at 0.5 s/tick** ≈ 60 seconds per battle, with speed controls (1× / 2× / 4× / instant). Tunable.
- **No mid-battle player input.** The build phase is the whole decision. This is what forces sensors and TFs to carry the entire burden of adaptation — they are not a convenience, they are the *only* way the cell responds to changing conditions. Revisit only if playtesting shows the watch phase feels inert.

### 7.1 Shared medium

**Both cells inhabit the same environment pool.** This single decision generates most of the interaction for free:

- Food is contested and depletes
- Exported toxins actually reach the opponent
- `Catabolic + Toxin` becomes a real defense
- Importing the opponent's secreted metabolites is a viable parasitic build

### 7.2 Environment axes

Mix two per battle, escalating across the run:

- **Food type:** simple (directly importable) vs. complex polymer (requires extracellular breakdown first)
- **Food abundance and pattern:** steady drip vs. pulses (pulses reward buffering capacity)
- **Ambient toxin level**
- **Radiation:** forced random block mutations mid-battle
- **Antibiotic:** global synthesis slowdown
- **Osmotic / pH stress:** raises all transport costs

### 7.3 Food tiers

| Tier | Yield | Requirement |
|---|---|---|
| Simple sugar | 2 | Directly importable |
| Complex polymer | 6 | Needs an **extracellular** catabolic protein to pre-digest — costs external slots, and the digested product is available to the opponent too |

That asymmetry alone generates a large space of interesting environments.

### 7.4 Food budget (now load-bearing)

With 24 slots, engine capacity outruns any realistic medium. **Total food delivered per battle is therefore the primary balance lever.**

Working numbers: one food unit yields 3 metabolites, so reaching 100 growth requires ~34 food units net of spending — call it **~45 units** with transport and churn overhead. In a shared medium with two cells, delivering **~90 units over 120 ticks (0.75/tick)** means both cells can theoretically finish, and whoever captures more than half wins. That's the knife-edge to design around.

- **Abundant** (~1.5/tick): engine-building wins, denial is pointless. Early battles.
- **Knife-edge** (~0.75/tick): capture rate decides. The default.
- **Scarce** (~0.4/tick): neither cell can finish honestly. Forces parasitism, toxin offense, or polymer access. Late battles.

**Capture rate, not consumption rate, becomes the real stat** at knife-edge and below — number of importers, their tick rate, and proximity advantages. Worth surfacing in the readout panel alongside metabolites/tick.

### 7.5 Difficulty dials

1. **Maturation window vs. shock frequency.** 5-tick maturation with toxin pulses every ~20 ticks means buffers usually survive. Pulses every ~6 ticks shred them and force lean, just-in-time play. **Primary tension knob.**
2. **Food density.** Scarcity converts the game from engine-building into denial. Late-run environments should be scarce enough that pure economy builds lose to parasitic and offensive ones.

---

## 8. Run Structure

**10–12 battles across three acts.**

**Between battles, draft one of three:** a block, a promoter, or a plasmid-length extension.

**Premium rewards** (valuable specifically *because* of plasmid burden): excise a block, rearrange the plasmid freely, +1 slot in a chosen compartment.

**Mid-run events:** mutagen (randomize three blocks for a reward), salvaged plasmid from a defeated NPC to splice in wholesale, horizontal gene transfer.

**Elites and bosses are counterbuilds, not stat blocks:**
- A cell secreting a catabolic enzyme that destroys extracellular food — starves anyone without direct import
- A cell dumping toxin from tick 0
- A cell with no defenses that simply outruns you on raw expression

Pressure teaches mechanics better than tutorials do.

---

## 9. Legibility Requirements

This is an autobattler: the player commits and watches. If they can't predict what their cell will do, losses feel like noise. **Non-negotiable:**

1. **Sandbox tick-through in the build phase.** Step forward one tick at a time. Watch proteins get built, slots fill, the membrane populate.
2. **Steady-state readout panel:** predicted metabolites/tick gross, **upkeep/tick** (churn — see §3.2), net/tick, **predicted equilibrium slot allocation per compartment rendered as the actual rack** (this is the single most important readout, since slot count *is* throughput), and — most importantly — **which step is rate-limiting**. Render the pipeline (food in → catabolism → metabolites → growth) as a flow with the bottleneck highlighted. *This one widget will teach the game better than any tutorial.*
3. **Plain-language event log:** "Tick 34: ToxinR repressor bound P2. Efflux pump expression stopped." / "Tick 41: Importer evicted Sensor-A from membrane slot 3."

---

## 10. Known Risks

| Risk | Mitigation |
|---|---|
| **Pure economy rush** (one promoter, one Catabolic+Food, ignore everything) | Should win battles 1–3 and lose hard at battle 4. Design the difficulty curve to kill it at a known point. |
| **Sensor circuits never pay off** — always-on expression strictly better | Requires slot pressure to be genuinely tight and toxin exposure genuinely lethal. |
| **Full determinism** → solved metagame | Expression is now deterministic by design (§4.2), so variance must come from elsewhere: randomized food spawn timing and position, environment pairings, draft offers, radiation events. |
| **Depth strictly beats breadth** — 5 copies of the best enzyme always wins | Environments must include hazards that a mono-build cannot survive at all, not merely survives worse. At least one battle per act should be unwinnable without a specific utility protein. |
| **Transport dominated by passive diffusion** — importer becomes a trap block | Passive influx near-zero, or scaling inversely with concentration so it only matters in the opening. |
| **Exchangers too strong at 0 cost** | Make exchange stoichiometric and rate-limited by the scarcer target — excellent under specific conditions, dead otherwise. |
| **Unified transporter illegible to new players** | Topology preview with membrane and directional arrows. Do not split the block. |

---

## 11. Build Order

**Prototype 1 — the only question that matters.**
One cell. No opponent. No roguelike layer. Three blocks (Catabolic, Transporter, Food), a membrane, one promoter, one environment, slots, ticks, a growth bar.
*Ask: is arranging blocks to raise metabolites/tick fun on its own?* If not, no amount of roguelike scaffolding saves it.

**Prototype 2.**
Add topology (membrane directionality), toxin, and the Sensing+TF loop.
*Ask: does anyone build a conditional circuit unprompted?*

**Prototype 3.**
Add the second cell and the shared medium.
*Ask: do players read the opponent and adapt, or just optimize their own engine?*

**Then:** run layer, drafting, environment variety, events.
