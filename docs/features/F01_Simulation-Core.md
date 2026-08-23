# F01: Simulation Core

**Status:** planned
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

### F01-M01 — Metabolite economy and the tick loop

The immature pool with per-unit age counters, maturation to banked growth at age 5,
youngest-first spending, banked growth immutable (§2.1). Defines the `SimEvent` record
type that every later milestone emits into.

**Done when:** headless tests cover maturation timing, youngest-first ordering under a
partial spend, banked growth surviving a pool wipe, and the §2.5 stall (pool at zero →
spending actions fail rather than going negative).

### F01-M02 — Plasmid, transcription, and a text notation

Circular ordered block list; promoters, terminators, readthrough wrapping from last gene
to first, RBS splitting a transcript into multiple proteins (§4, §4.2). Includes a compact
**text notation for plasmids** — this unblocks test-writing for every milestone after it
and later carries NPC rosters, so it is not a side quest.

**Done when:** a plasmid whose last gene lacks a terminator reads into the first; a
one-promoter two-RBS transcript yields two separate protein definitions; a plasmid
round-trips through the text notation unchanged.

### F01-M03 — Adjacency and topology resolution

The §5.3 rules, which are what make arrangement a puzzle: a target domain sets the target
for *both* neighbours; an effector with two different target neighbours acts on both at
doubled cost; transport and sensing only function when membrane-embedded; transporter
direction is read off which side the target sits on.

**Done when:** a table-driven test enumerates the arrangements in §5.3 and §5.4 and
asserts the resolved function of each — including the negative case, a cytoplasmic
Transporter+Food doing nothing at all.

### F01-M04 — Synthesis, slots, and FIFO eviction

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

- **Tick resolution order.** Not yet decided. Whether synthesis resolves before or after
  transport within a tick will shift the baseline benchmark slightly.
- **Passive diffusion** (§10) — near-zero, or inversely scaling with concentration? Left
  out of M05 entirely until there is a reason to add it.

## Changelog

- `2026-08-23` — Created. Scoped to the Prototype 1 block set.
