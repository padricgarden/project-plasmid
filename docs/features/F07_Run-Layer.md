# F07: Run Layer

**Status:** planned
**Spec sections:** §8, §7.2, §7.5, §10
**Depends on:** F06

> **Sketch, not a specification.** Provisional until F06's gate has an answer.

## Purpose

The roguelike wrapper: 10–12 battles across three acts, drafting between them, escalating
environments. This is what turns a battle into a run and completes the minimum viable
game.

Deliberately last. Spec §11 is explicit that this scaffolding cannot rescue a core loop
that isn't fun, so building it early would only hide the answer.

## Design constraints

- **Draft one of three: a block, a promoter, or a plasmid-length extension** (§8).
- **Premium rewards are valuable specifically because of plasmid burden** — excise a
  block, rearrange freely, +1 slot in a chosen compartment. They only read as premium if
  §4.1's burden is actually biting, which F01-M05 will have measured by now.
- **Difficulty is tuned on §7.5's two dials**: maturation window vs. shock frequency
  (the primary tension knob), and food density.
- §10: the pure economy rush should **win battles 1–3 and lose hard at battle 4.** That is
  a designed teaching moment with a known location, not an accident to balance away.

## Milestones

### F07-M01 — Run state and act structure
Sequence of battles, persistent plasmid between them, run win/loss.
**Done when:** a full 10-battle run can be played start to finish.

### F07-M02 — Drafting
One of three between battles (§8).
**Done when:** a run's plasmid visibly diverges across two playthroughs.

### F07-M03 — Premium rewards
Excise, free rearrange, +1 compartment slot.
**Done when:** players take excise over a new block at least sometimes — if never, burden
is too weak and §4.1 needs revisiting.

### F07-M04 — Environment variety
§7.2's axes, mixed two per battle and escalating: food type and abundance, ambient toxin,
radiation, antibiotic, osmotic stress.
**Done when:** each act has a distinct environmental character and at least one battle per
act is unwinnable without a specific utility protein (§10's breadth-vs-depth mitigation).

### F07-M05 — Mid-run events
Mutagen, salvaged plasmid from a defeated NPC, horizontal gene transfer (§8).

## Open questions

- Run length: 10 or 12 battles. Depends on how long a battle actually takes to build for,
  which won't be known until after F04-M05.
- Is the pure-economy-rush death at battle 4 tuned, or does it need a specific scripted
  opponent to guarantee it?

## Changelog

- `2026-08-23` — Created as a sketch.
