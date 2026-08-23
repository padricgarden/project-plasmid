# F06: Opponent and Shared Medium

**Status:** planned
**Spec sections:** §7.1, §7.3, §7.4, §8
**Depends on:** F05

> **Sketch, not a specification.** Provisional until F05's gate has an answer.

## Purpose

Spec §11's Prototype 3, and the point at which this becomes an autobattler rather than a
solitaire optimiser. §7.1 is the highest-leverage decision in the whole design: putting
both cells in **one shared environment pool** generates food contention, real toxin
delivery, and parasitic builds for free, without a single bespoke interaction rule.

The question: **do players read the opponent and adapt, or just optimise their own
engine?**

## Design constraints

- One medium, not two. Everything interesting here is a consequence of that.
- §7.4's food budget is load-bearing at this point, not a tuning detail — with 24 slots
  the binding constraint is meant to live in the environment. Knife-edge (~0.75/tick) is
  the default to design around.
- **Capture rate, not consumption rate**, becomes the stat that decides battles, and
  F03-M03 needs to surface it.

## Milestones

### F06-M01 — Two cells, one pool
Both cells stepping in the same `SimState` against a contested food supply. F01 was built
for this, so it should be an extension rather than a rewrite — if it isn't, that's a
finding about F01.
**Done when:** two identical builds in a knife-edge medium finish within a few ticks of
each other, and a build with more importers reliably beats one with more enzymes.

### F06-M02 — Opponent roster
Fixed NPC plasmids authored in F01-M02's text notation. Per §8, elites and bosses are
**counterbuilds, not stat blocks** — the extracellular-catabolase starver, the tick-zero
toxin dumper, the pure-expression racer.
**Done when:** three counterbuild opponents exist and each beats a build that ignores its
specific threat.

### F06-M03 — Opponent legibility
What the player can see of the rival cell during the build phase and during the battle.
**Done when:** adapting to a known opponent is possible from the build screen alone.

### F06-M04 — Prototype 3 gate
**Done when:** §11's third question has an answer. Record it here.

## Open questions

- How much of the opponent's plasmid is visible before committing? Too little and §11's
  question answers itself as "no"; too much and the build phase becomes a lookup.
- Does the NPC need any adaptive behaviour at all, or are fixed plasmids sufficient
  through the whole run? Fixed is the cheaper hypothesis and worth testing first.

## Changelog

- `2026-08-23` — Created as a sketch.
