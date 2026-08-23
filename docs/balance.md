# Balance parameters

The register of every tunable number in the game: what it is, what it is currently set to,
where it lives in the code, and which spec section it came from.

**This doc is a map, not the source of truth.** The values live in code; this tells you
where to go. If a row and the code disagree, the code wins and the row is stale — fix it.

## Rules that keep this honest

1. **No magic numbers in `src/sim/`.** A bare `5` in the tick loop is a balance parameter
   hiding from this document.
2. **Global tunables live in one place:** `src/data/balance.gd`, a `class_name Balance`
   of typed constants. That is what makes "tune it later" actually cheap — one file, and
   this doc points at names inside it.
3. **Per-entity tunables live in Resources** under `src/data/` — block definitions,
   promoter definitions, environment definitions. Point at the resource, not at a
   constant.
4. **Adding or changing a tunable updates this doc in the same change.** Parameter, value,
   location, spec section.
5. **Feature docs cite this doc; they do not restate values.** Two copies of a number
   drift apart, and the one in the feature doc is always the one that goes stale.

`Defined in` reads `pending F##-M##` for parameters the spec specifies but no code
implements yet. `?` in the Value column means **the spec does not give a number** — see
[Open](#open) at the bottom.

---

## Metabolite economy — spec §2

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Maturation age | 5 ticks | §2.1 | `Balance.MATURATION_AGE` | Primary tension knob, paired with shock frequency (§7.5). |
| Spend order | youngest-first | §2.1 | `MetabolitePool.try_spend()` | Policy, not a number. Do not make it configurable. |
| Catabolic on food — yield | 3 per unit | §2.2 | `EnvironmentDef.food_yield` | Base yield. Tier yields in §7.3 are multiples of it. |
| Effector action cooldown | 3 ticks | §2.2 | `Balance.EFFECTOR_COOLDOWN_TICKS` | **Applied to all effectors, not just catabolism** — see Open. |
| Transport cost | 1 per unit | §2.2 | `Balance.TRANSPORT_COST` | "The workhorse tax." |
| Exchange cost | 0 | §2.2 | pending F05 | Requires both targets present. |
| Catabolic on toxin — cost | 1 per unit | §2.2 | pending F05-M01 | Defense is deliberately cheap. |
| Anabolic toxin — cost | 2 per unit | §2.2 | pending F05-M05 | Offense costs double defense. |
| Anabolic food — cost | 4 per unit | §2.2 | pending F05-M05 | Deliberately bad ROI. |
| Sensing cost | 0 | §2.2 | pending F05-M02 | Never tax the circuit itself. |
| TF cost | 0 | §2.2 | pending F05-M03 | Never tax the circuit itself. |
| Protein synthesis cost | `ceili(blocks / 3)` | §2.2 | `GeneExpression.synthesis_cost()` | Rounds **up**. Charged so expression is an economic decision. |
| Starting endowment buffer | 4 + one round of synthesis | — | `Balance.STARTING_METABOLITE_BUFFER` | **Not in the spec.** Without it the cell deadlocks at tick 0 — see Open. |
| Rate scale | 100 | — | `Balance.RATE_SCALE` | Representation, not balance: keeps fractional rates integer. |

## Slots — spec §3

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Internal slots | 8 | §3 | `Balance.SLOTS_PER_COMPARTMENT` | |
| Membrane slots | 8 | §3 | `Balance.SLOTS_PER_COMPARTMENT` | The contested compartment. |
| External slots | 8 | §3 | `Balance.SLOTS_PER_COMPARTMENT` | |
| Eviction policy | FIFO | §3 | `SlotRack.insert()` | 8 chosen over 5 so ratios like 4:3:1 are expressible (§3.4). |
| Proteins per slot | 1 | §3.4 | `SlotRack` | No stacking. Structural — not a tunable in practice. |
| Build ticks per block | 1 | §3.5 | `Balance.BUILD_TICKS_PER_BLOCK` | **Spec gives no number** — decided at M04. See Open. |
| Anchor upkeep | ? | §3.4 | pending F05-M04 | Spec says "small metabolite upkeep". |
| Degron lifetime | ? ticks | §3.4 | pending F05-M04 | |

## Plasmid burden — spec §4.1

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Base growth target | 100 | §4.1 | `Balance.BASE_GROWTH_TARGET` | Curve implemented in `Burden.growth_target()`; matches §4.1's table exactly. |
| Burden coefficient `c` | 1.5 | §4.1 | `Balance.BURDEN_COEFFICIENT` | Weak, and that is fine — churn and food scarcity do the restraining. See Open. |
| Burden exponent | 1.1 | §4.1 | `Balance.BURDEN_EXPONENT` | "Tune `c`, not the exponent." |
| Starting block count | 12 | §4.1 | `Balance.STARTING_BLOCK_COUNT` | Normalises the start to exactly 100. |

## Promoters — spec §4.2

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Promoter period tiers | 12, 6, 4, 3, 2 | §4.2 | `Balance.PROMOTER_PERIODS` | Divisors of 12. See below. Enforced by `PlasmidNotation.parse()`, not just documented. |
| Starting promoter tier | I (period 12) | §2.4 | pending F01-M05 | ~0.08 synthesis/tick per gene, matching §2.4's overhead. |
| Additional-promoter penalty | ? | §4.2 | pending F01-M04 | Spec says "speed/efficiency penalty", no value. |
| Operator colours | 3–4 | §6 | pending F05-M03 | |

### Why these periods, and why not others

| Tier | Period | Relative rate |
|---|---|---|
| I | 12 | 1 |
| II | 6 | 2 |
| III | 4 | 3 |
| IV | 3 | 4 |
| V | 2 | 6 |

Steady-state slot count is `8 × rate / total_rate` (§3.1), so a rack lands on whole
numbers only when the competing rates are small integers over a common base. **Base 12
gives rates 1, 2, 3, 4, 6 — every period above is `12 / rate`.** The range is also the
usable one: at 120 ticks per battle, period 12 still fires ten times, and anything slower
barely participates.

Reachable racks at 8 slots: **8**, **6:2**, **4:4**, **4:3:1**, **3:3:2**, **4:2:2**,
**6:1:1**, **2:2:2:2**, and 1×8.

The property worth protecting: **6:2 is reachable two ways** — periods (4, 12) or
(2, 6). Identical composition, but (2, 6) fires twice as often and therefore pays double
the synthesis upkeep forever. That is exactly §3.1's "find the minimum promoter rate that
holds the slot count you want", made concrete and discoverable.

⚠ **Adding a period that is not a divisor of 12 breaks this.** Period 8 against period 12
gives 4.8 : 3.2 — a rack that never settles on integers and instead cycles. If a future
draft reward wants a new promoter, it must come from this set or the set must be
redesigned around a new base, not extended ad hoc.

Known cost: **5:2:1** is unreachable — rate 5 needs base 60, whose slowest tier would fire
twice per battle. The nearest reachable split is 4:3:1. Judged an acceptable trade for
keeping every tier fast enough to matter. §3.4 cited 5:2:1 as its example of what 8 slots
buys and was amended to 4:3:1 in spec v0.3.1 for this reason.

## Battle — spec §7.0

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Battle length | 120 ticks | §7.0 | pending F01-M06 | |
| Tick duration | 0.5 s | §7.0 | pending F04-M02 | Presentation only — never affects sim outcome. |
| Speed multipliers | 1× / 2× / 4× / instant | §7.0 | pending F04-M02 | |
| Lysis toxin threshold | ? | §1 | pending F05-M01 | |
| Lysis consecutive ticks | ? | §1 | pending F05-M01 | |

## Environment — spec §7.3, §7.4

Per-environment values; these belong in environment Resources, not in `Balance`.

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Simple sugar yield | 3 | §7.3 | `EnvironmentDef.food_yield` | **Was 2 in the spec table**; raised to 3 to match §2.2/§7.4. |
| Complex polymer yield | 6 | §7.3 | pending F06 | Needs extracellular pre-digestion. Now only 2× simple — see Open. |
| Food delivery — abundant | 1.5 / tick | §7.4 | `EnvironmentDef.abundant()` | Engine-building wins. Early battles. |
| Food delivery — knife-edge | 0.75 / tick | §7.4 | `EnvironmentDef.knife_edge()` | **The default.** Capture rate decides. |
| Food delivery — scarce | 0.4 / tick | §7.4 | `EnvironmentDef.scarce()` | Neither cell can finish honestly. Late battles. |
| Passive diffusion | ~0 | §10 | not planned | Left out until there is a reason. Trap-block risk if too high. |

## Run structure — spec §8

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Battles per run | 10–12 | §8 | pending F07-M01 | |
| Acts | 3 | §8 | pending F07-M01 | |
| Draft options offered | 3 | §8 | pending F07-M02 | |

---

## Open

Decisions the spec leaves unresolved, and the one place it contradicts itself. These are
the rows most likely to move once F01-M05 produces real numbers.

1. ~~**Food yield is specified twice with different values.**~~ **Resolved 2026-08-23:
   simple sugar yields 3**, matching §2.2 and §7.4's budget arithmetic. §7.3's table value
   of 2 is superseded; the spec should be amended so it stops disagreeing with itself.
2. **Polymer's advantage shrank as a side effect of (1).** At simple = 2 the polymer tier
   paid 3× per unit; at simple = 3 it pays 2×. Polymer costs external slots *and* leaks
   digested product to the opponent (§7.3), so 2× may no longer cover it and the tier
   could become a trap. Not blocking — polymer is not implemented until F06 — but if
   nobody builds an extracellular digester there, this is the first number to try (9
   restores the 3× ratio).
3. ~~**Burden coefficient `c = 1.5`.**~~ **Measured at F01-M05: leave it alone.** §4.1
   feared burden was too weak to restrain engine-building. It is — but engine-building
   turns out to be restrained hard by something else, so the weakness does not matter.
   Throughput is **food-limited, not slot-limited**: the starting cell already eats
   everything the medium delivers, so extra genes buy no yield at all. What they buy is
   §3.2's churn — synthesis upkeep every tick, forever. Measured over 400 ticks at
   knife-edge density, a 27-block six-gene engine catabolises the *same* food as the
   9-block starting cell, pays over 5× the synthesis upkeep, and banks less than half the growth
   (0.52/tick against 1.33). At scarce density it never divides at all: upkeep drains the
   pool, transport becomes unaffordable, and it starves beside food it cannot pay to
   import — §2.5's death spiral reached by overbuilding rather than by toxin.
   The spec's stated preference — keep balance in the environment — is validated. Note
   the caveat: upkeep scales with *promoter rate*, not block count, so a long plasmid on
   slow promoters is punished far less than this measurement suggests.
7. **The 3-tick cooldown was made universal.** §2.2 attaches it only to Catabolic+Food
   and gives transport none, but §2.3's ceiling ("eight internal slots ≈ 8
   metabolites/tick") and §2.4's baseline ("import cost 1 food / 3 ticks = 0.33/tick")
   both require it everywhere. Applied universally on that basis; the spec should say so.
8. **A cell needs a starting endowment and the spec never mentions one.** With an empty
   pool at tick 0 no promoter can pay for synthesis, so no protein is built, so nothing
   ever earns — a permanent deadlock, distinct from §2.5's recoverable spiral. Measured:
   an unfunded starting cell stalls 68 times in 400 ticks and racks nothing. The
   endowment is one full round of synthesis plus a buffer of 4, scaled to the genome
   because a flat value large enough for the starting cell still soft-locks a six-gene
   plasmid — and drafting only grows plasmids (§8).
9. **§2.4's baseline benchmark does not reproduce, and cannot.** It predicts ≈0.6
   metabolites/tick and ~165 ticks for "one Catabolic+Food, one importer", but under §3's
   slot rules a lone gene fills all eight slots of its compartment, so the starting cell
   runs eight enzymes and eight importers. §2.4 predates the 5→8 slot change (§3.4) and
   its arithmetic was never revisited. Measured for the starting cell over 400 ticks:
   **2.81/tick abundant, 1.33/tick knife-edge, 0.63/tick scarce.** The 0.6 figure does
   still appear — at scarce density — but as a property of the environment rather than of
   the cell. §2.4 should be rewritten around a named environment.
4. ~~**Promoter period tiers are unspecified.**~~ **Resolved 2026-08-23:** five tiers on
   the divisors of 12 — see [Promoters](#promoters--spec-42) for the reasoning and for
   why the set must not be extended ad hoc.
5. **Anchor upkeep, degron lifetime, lysis threshold and duration** have no numbers at
   all. Not blocking until F05.
6. **Build ticks per block = 1**, decided at F01-M04 because §3.5 says only that length
   determines build time. It has two jobs pulling against each other: long enough that a
   fused readthrough transcript is visibly slower to express than two short genes (§4's
   stated cost for omitting a terminator), short enough that a TF-gated emergency efflux
   gene still arrives in time to matter (§3.2). One tick per block satisfies both at
   current protein lengths; revisit if F05's emergency circuits feel sluggish.

## Changelog

- `2026-08-23` — Created. Seeded from the spec; no parameters implemented yet.
- `2026-08-23` — **Food yield fixed at 3 per unit.** Simple sugar raised from §7.3's 2 to
  3, resolving the contradiction with §2.2 and §7.4 in favour of the value the benchmarks
  already assume. Knock-on: polymer's relative advantage dropped from 3× to 2× (Open 2).
- `2026-08-23` — **Promoter periods set to 12 / 6 / 4 / 3 / 2.** Chosen as the divisors of
  12 so competing rates are small integers and racks settle on whole slot counts; range
  chosen so the slowest tier still fires ten times in a 120-tick battle. Costs the exact
  5:2:1 split named in §3.4. Proposed by Claude, not from the spec — override freely, but
  read the ⚠ note under Promoters first if you want to add a tier.
