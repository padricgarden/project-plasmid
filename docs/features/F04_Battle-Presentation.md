# F04: Battle Presentation

**Status:** planned
**Spec sections:** §7.0, §3.4, §9.3
**Depends on:** F01, F03

## Purpose

The watch phase — 120 ticks at 0.5 s/tick, roughly a minute, with speed controls. The
player has already made every decision; this is where they find out whether they were
right, and where they learn enough to build differently next time.

Completing this feature completes **Prototype 1** and reaches the spec's first gate.

## Design constraints

- **Presentation never mutates sim state** (CLAUDE.md > Architecture rules). Speed
  controls change how fast ticks are consumed, never what a tick does. Instant-resolve
  must produce exactly the same outcome as watching at 1×.
- **Evictions are always visible and logged in plain language** (§3.4). A protein
  vanishing silently is the single most confusing thing this game can do.
- **No mid-battle input** (§7.0). Resist every temptation to add a button here — sensors
  and TFs carrying the whole burden of adaptation is the design, not an omission.

## Approach

`src/battle/`. A thin driver that pulls ticks from F01 on a timer and hands events to
F03's log. Everything visible is derived from sim state; the battle view owns no
authoritative data whatsoever.

## Milestones

### F04-M01 — Cell view and slot racks

The three compartments with their 8 slots each, proteins appearing as they finish
building, evictions shown as evictions.

**Done when:** a full rack turning over under promoter pressure is readable at 1× — you
can see which protein left and why.

### F04-M02 — Clock and speed controls

1× / 2× / 4× / instant (§7.0).

**Done when:** instant-resolve and 1× produce identical outcomes and identical event logs
from the same starting state.

### F04-M03 — Growth bar and outcome

Banked growth against the burden-adjusted target (§4.1), the immature pool shown as
distinct from banked growth (§2.1 — one is safe, one is not, and that difference is the
whole economy), and an end-of-battle result.

**Done when:** all of F01-M06's termination paths present a clear outcome, and the pool
draining without banked growth moving is visibly legible as two different things.

### F04-M04 — Medium view

Food available in the shared environment, delivery arriving over time. Single-cell for
now; F06 makes it contested.

**Done when:** food scarcity is visible as scarcity before the growth rate drops.

### F04-M05 — Prototype 1 gate

Not code. Play it, and get other people to play it.

**Done when:** spec §11's first question has an answer: *is arranging blocks to raise
metabolites/tick fun on its own?* Record the answer in this changelog. If it is no, the
correct next step is to change the design, not to start F05 — the spec is explicit that
no amount of roguelike scaffolding saves it.

## Open questions

- Default speed for a first-time player. 0.5 s/tick over 120 ticks is a minute of
  watching, which is a long time if nothing legible is happening.
- Whether a battle can be paused and inspected mid-run without violating the spirit of
  §7.0. Pausing adds no input to the cell, so probably fine, but it is a judgement call.

## Changelog

- `2026-08-23` — Created.
