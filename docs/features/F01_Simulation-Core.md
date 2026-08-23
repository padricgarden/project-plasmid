# F01: Simulation Core

**Status:** in progress
**Spec sections:** §2, §3, §4, §5, §7.0, §7.3, §7.4
**Depends on:** nothing

## Purpose

The deterministic tick engine: plasmid → transcription → proteins → slots → metabolites →
growth. Every number in the design spec lives here, and because the core is pure and
headless (see CLAUDE.md > Architecture rules) each of the spec's economic claims becomes
a test that either passes or tells us the spec is wrong.

Scoped to the **Prototype 1 block set only** — Membrane Domain, Transporter, Catabolic
Enzyme, Food target. Toxin, Sensing, TF, Anabolic, Anchor and Degron are F05. Resisting
the urge to build the whole grammar up front is the point: Prototype 1 asks one question
and does not need the rest to ask it.

## Design constraints

- **Purity.** No `Node`, no scene tree, no rendering, no unseeded randomness (§4.2).
- **Deterministic promoter firing** — fixed period, never per-tick probability (§4.2).
  Stochastic firing lets slot composition random-walk and turns a loss into a rug pull.
- **Speculatively runnable.** State must be cheaply copyable and `tick()` must have no
  side effects outside the state object, because F03's sandbox steps a *copy* forward.
- **Integer economy.** Synthesis cost rounds up via `ceili()` (§2.2).
- **Events are data.** The sim emits structured records; the plain-language log is F03's
  view over them.

## Approach

Everything under `src/sim/`, with block and promoter definitions as `Resource` subclasses
in `src/data/`. One `SimState` object holds the whole world (both cells and the medium,
even though Prototype 1 has one cell) so that F06 adds an opponent without a rewrite.
`tick()` takes state and returns state plus an event list.

Resolution order within a tick matters and must be fixed and documented once M04 lands —
pick it deliberately, write it down at the top of the tick function, and do not let it
drift.

## Milestones

### F01-M01 — Metabolite economy and the tick loop ✅

The immature pool with per-unit age counters, maturation to banked growth at age 5,
youngest-first spending, banked growth immutable (§2.1). Defines the `SimEvent` record
type that every later milestone emits into.

**Done when:** headless tests cover maturation timing, youngest-first ordering under a
partial spend, banked growth surviving a pool wipe, and the §2.5 stall (pool at zero →
spending actions fail rather than going negative).

### F01-M02 — Plasmid, transcription, and a text notation ✅

Circular ordered block list; promoters, terminators, readthrough wrapping from last gene
to first, RBS splitting a transcript into multiple proteins (§4, §4.2). Includes a compact
**text notation for plasmids** — this unblocks test-writing for every milestone after it
and later carries NPC rosters, so it is not a side quest.

**Done when:** a plasmid whose last gene lacks a terminator reads into the first; a
one-promoter two-RBS transcript yields two separate protein definitions; a plasmid
round-trips through the text notation unchanged.

### F01-M03 — Adjacency and topology resolution ✅

The §5.3 rules, which are what make arrangement a puzzle: a target domain sets the target
for *both* neighbours; an effector with two different target neighbours acts on both at
doubled cost; transport and sensing only function when membrane-embedded; transporter
direction is read off which side the target sits on.

**Done when:** a table-driven test enumerates the arrangements in §5.3 and §5.4 and
asserts the resolved function of each — including the negative case, a cytoplasmic
Transporter+Food doing nothing at all.

### F01-M04 — Synthesis, slots, and FIFO eviction ✅

Promoters fire on their fixed period, pay `ceili(blocks / 3)`, take build time in ticks
proportional to length, then occupy a slot and evict the oldest in that compartment.
8 / 8 / 8 internal / membrane / external (§3).

**Done when:** the §3.1 equilibrium emerges rather than being hard-coded — a test runs a
4-tick promoter on protein A and a 12-tick promoter on protein B, both internal, for 200
ticks and asserts the rack holds **6 A : 2 B**, stable and non-oscillating, across the
final 50. This is the most important test in the project; §3.1 is the design's most
unusual property and this is the only thing that will notice if a refactor breaks it.

### F01-M05 — Medium, food, and the growth pipeline

Food delivery rate as a first-class per-environment parameter (§7.4), simple vs. polymer
tiers (§7.3), import and catabolism, growth accumulation, and the plasmid burden target
from §4.1.

**Done when:** the §2.4 baseline reproduces — the starting cell plus one importer nets
≈0.6 metabolites/tick and reaches 100 growth in roughly 165 ticks. **If the numbers do
not land, that is a finding about the spec, not a licence to retune quietly:** record it
in the changelog below and raise it.

### F01-M06 — Battle resolution

The 120-tick limit, victory at the burden-adjusted growth target, and the outcome record.
Lysis is wired as a condition but cannot fire until toxin exists in F05.

**Done when:** a headless battle terminates with a defined outcome down each available
path (target reached, time expired), and two runs from identical inputs produce
byte-identical event streams.

## Tunables

This feature introduces most of the game's balance surface — the §2.2 cost table, slot
counts, the burden curve, promoter periods, battle length. All of it is registered in
[docs/balance.md](../balance.md); fill in that doc's `Defined in` column as each milestone
lands, and do not restate values here.

Two decisions taken there change what this feature builds: **food yields 3 per unit**
across the board (M05's benchmark now matches §2.4 arithmetic directly), and **promoter
periods are the divisors of 12 — 12 / 6 / 4 / 3 / 2**. The period set is not a free
choice; M04's equilibrium behaviour depends on the rates being small integers over a
common base, and the register explains why extending the set breaks it.

## Open questions

- **Tick resolution order.** Partly settled — ageing is last, recorded at the top of
  `SimState.step()`. Still open: whether synthesis resolves before or after transport,
  which shifts the §2.4 baseline slightly. Decide at M05, when both exist to order.
- **Passive diffusion** (§10) — near-zero, or inversely scaling with concentration? Left
  out of M05 entirely until there is a reason to add it.

## Changelog

- `2026-08-23` — Created. Scoped to the Prototype 1 block set.
- `2026-08-23` — **M01 done.** `MetabolitePool` stores counts bucketed by age rather than
  one entry per metabolite, so ageing is a shift and a clone is O(MATURATION_AGE) — which
  F03-M01's sandbox needs, since it copies the world on every edit. The pool holds no
  reference to banked growth, making §2.1's "banked growth is safe" structural rather than
  a rule: maturation reports a count and `SimState` banks it. Spending is all-or-nothing,
  which is what makes the §2.5 death spiral a stall rather than a debt; partial fulfilment
  is left to callers as a per-action decision.
- `2026-08-23` — Tick resolution order opened at the top of `SimState.step()` with ageing
  last, so a metabolite produced during a tick banks exactly MATURATION_AGE ticks later.
  Steps 1 and 2 are placeholders for M04 and M05.
- `2026-08-23` — **M02 done.** Transcription reads forward from a promoter until a
  terminator, or until it returns to the promoter it started from — that second guard is
  what stops an unterminated ring looping forever, and it makes "read the whole ring
  once" the natural limit rather than a special case. Promoters met mid-transcript are
  read *through* rather than stopped at, so §4's "one promoter drives two genes" adds a
  transcript without replacing one; the downstream promoter still fires independently.
  Structural blocks are consumed but never translated, so a fused readthrough protein is
  both genes' domains concatenated with the promoter between them dropped.
- `2026-08-23` — Notation is `P12-CAT-FOOD-TERM`, parsed into a `ParseResult` that is
  either a whole plasmid or an error naming the offending token — never half-built.
  `parse()` **rejects promoter periods outside `Balance.PROMOTER_PERIODS`**, which turns
  the closed-family rule from a note in the register into something the code enforces.
- `2026-08-23` — **M03 done.** `Adjacency.resolve()` derives compartment and function
  from block order alone; nothing about what a protein does is stored on a block, so the
  §5.3 rules live in exactly one place. Inert effectors are reported rather than dropped,
  each carrying a plain reason — F02-M03 and F03-M02 both need to show a player that a
  block they paid for is doing nothing.
- `2026-08-23` — **Three rules §5.3 leaves open, decided in `adjacency.gd`.** (1) A
  membrane-embedded transporter reaches *through* the membrane domain it sits against.
  Without it, exchange is unreachable in principle: a transporter's two neighbours can
  only straddle the membrane if the membrane *is* the transporter. Reach-through is
  transporter-only, since rule 3 already makes membrane interaction their special case.
  (2) The same target on both sides resolves inert, not as a free exchange — food for
  food moves nothing, and §2.2 prices exchange at zero, so calling it an exchange would
  be a free no-op. (3) The first membrane domain sets the boundary; one boundary keeps
  the topology preview drawable.
- `2026-08-23` — §5.3 rule 2's cost doubling is structurally present (functions carry a
  distinct-target list) but **cannot be exercised until F05 adds Toxin** — Food is the
  only target in the Prototype 1 grammar, so no arrangement yields two different ones.
  The cost itself is M05's; deliberately not computed here, because §2.2 makes exchange
  free while rule 2 doubles, and those two would fight inside one multiplier.
- `2026-08-23` — **M04 done.** §3.1's equilibrium emerges: a 4-tick and a 12-tick promoter
  settle at 6:2 across 8 internal slots, with nothing in the sim aware that 6 and 2 are
  the answers. Racks compete per compartment, copies of one gene each cost a slot, and
  expressing into a full rack still charges synthesis — §2.3's intended teaching moment
  falls out rather than being special-cased.
- `2026-08-23` — Tick resolution order settled further: **builds finish before promoters
  fire**, so a protein occupies its slot exactly `build_ticks` after the firing that paid
  for it. Builds are also concurrent — every firing starts its own, even while an earlier
  one from the same promoter is in flight. Dropping a firing because a gene was "busy"
  would make its effective rate something other than 1/period, and §3.1 would quietly
  stop holding for the fastest promoters.
- `2026-08-23` — **Build time is 1 tick per block**, decided here because §3.5 says only
  that length determines it. Registered with its reasoning in docs/balance.md.
- `2026-08-23` — `class_name Expression` collides with Godot's built-in `Expression`;
  renamed to `GeneExpression`. Worth remembering when naming sim types.
- `2026-08-23` — **The headline equilibrium test was initially weaker than it looked.**
  Under a mutation that evicted newest-first instead of oldest-first, the 4/12 rack froze
  the instant it filled — and its fill order is *already* 6:2, so the test passed and
  proved nothing. Added a second case whose fill order is 5:3 and which only reaches 6:2
  through continued turnover. That one catches the mutation. A first attempt at it was
  itself neutered by the economy: the subsidy covered only the fast gene's synthesis, so
  the slow gene stalled on tick 0 (§2.5) and the fill order reverted to 6:2. There is now
  a guard asserting no gene ever stalls during that case.
