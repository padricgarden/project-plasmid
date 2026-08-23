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
| Catabolic on food — yield | 3 per unit | §2.2 | pending F01-M05 | Base yield. Tier yields in §7.3 are multiples of it. |
| Catabolic on food — cooldown | 3 ticks | §2.2 | pending F01-M05 | |
| Transport cost | 1 per unit | §2.2 | pending F01-M05 | "The workhorse tax." |
| Exchange cost | 0 | §2.2 | pending F05 | Requires both targets present. |
| Catabolic on toxin — cost | 1 per unit | §2.2 | pending F05-M01 | Defense is deliberately cheap. |
| Anabolic toxin — cost | 2 per unit | §2.2 | pending F05-M05 | Offense costs double defense. |
| Anabolic food — cost | 4 per unit | §2.2 | pending F05-M05 | Deliberately bad ROI. |
| Sensing cost | 0 | §2.2 | pending F05-M02 | Never tax the circuit itself. |
| TF cost | 0 | §2.2 | pending F05-M03 | Never tax the circuit itself. |
| Protein synthesis cost | `ceili(blocks / 3)` | §2.2 | pending F01-M04 | Rounds **up**. Charged so expression is an economic decision. |

## Slots — spec §3

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Internal slots | 8 | §3 | pending F01-M04 | |
| Membrane slots | 8 | §3 | pending F01-M04 | The contested compartment. |
| External slots | 8 | §3 | pending F01-M04 | |
| Eviction policy | FIFO | §3 | pending F01-M04 | 8 chosen over 5 so ratios like 4:3:1 are expressible (§3.4). |
| Proteins per slot | 1 | §3.4 | pending F01-M04 | No stacking. Structural — not a tunable in practice. |
| Anchor upkeep | ? | §3.4 | pending F05-M04 | Spec says "small metabolite upkeep". |
| Degron lifetime | ? ticks | §3.4 | pending F05-M04 | |

## Plasmid burden — spec §4.1

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Base growth target | 100 | §4.1 | pending F01-M05 | |
| Burden coefficient `c` | 1.5 | §4.1 | pending F01-M05 | **Suspect** — spec flags it as likely too weak. See Open. |
| Burden exponent | 1.1 | §4.1 | pending F01-M05 | "Tune `c`, not the exponent." |
| Starting block count | 12 | §4.1 | pending F01-M05 | Normalises the start to exactly 100. |

## Promoters — spec §4.2

| Parameter | Value | Spec | Defined in | Notes |
|---|---|---|---|---|
| Promoter period tiers | 12, 6, 4, 3, 2 | §4.2 | pending F01-M04 | Divisors of 12. See below — the set is load-bearing. |
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
| Simple sugar yield | 3 | §7.3 | pending F01-M05 | **Was 2 in the spec table**; raised to 3 to match §2.2/§7.4. |
| Complex polymer yield | 6 | §7.3 | pending F06 | Needs extracellular pre-digestion. Now only 2× simple — see Open. |
| Food delivery — abundant | 1.5 / tick | §7.4 | pending F01-M05 | Engine-building wins. Early battles. |
| Food delivery — knife-edge | 0.75 / tick | §7.4 | pending F01-M05 | **The default.** Capture rate decides. |
| Food delivery — scarce | 0.4 / tick | §7.4 | pending F07-M04 | Neither cell can finish honestly. Late battles. |
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
3. **Burden coefficient `c = 1.5`.** §4.1 flags its own value: a ~38-block engine build
   may divide in ~68 ticks against a 120-tick limit, meaning burden restrains nothing.
   The spec's stated preference is to leave `c` weak and let food scarcity do the
   limiting — which makes the §7.4 delivery rates load-bearing rather than flavour.
   Measure in F01-M05 before changing either.
4. ~~**Promoter period tiers are unspecified.**~~ **Resolved 2026-08-23:** five tiers on
   the divisors of 12 — see [Promoters](#promoters--spec-42) for the reasoning and for
   why the set must not be extended ad hoc.
5. **Anchor upkeep, degron lifetime, lysis threshold and duration** have no numbers at
   all. Not blocking until F05.

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
