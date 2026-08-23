# F03: Legibility Layer

**Status:** planned
**Spec sections:** §9 (all of it), §3.2, §7.4
**Depends on:** F01, F02

## Purpose

Spec §9 is titled "Legibility Requirements" and marked **non-negotiable**, for a reason
specific to this genre: the player commits and then watches. If they cannot predict what
their cell will do, every loss reads as noise rather than as a misjudgement they can
learn from.

This is not polish and it is not a later pass. It is the feature that decides whether the
Prototype 1 playtest measures the design or measures confusion, and it should ship
alongside F02 rather than after it.

## Design constraints

- **The sandbox runs a copy.** Stepping forward in the build phase must not commit
  anything, which is exactly why F01 is required to be speculatively runnable.
- **Prediction must be derived, never duplicated.** The steady-state readout has to come
  from running or analysing the real sim. A second hand-written model of the economy that
  drifts from the first is the obvious failure mode here.
- **The event log is a view.** It renders F01's structured events into plain language and
  holds no state of its own.

## Approach

`src/ui/`. The readout panel is the highest-value widget in the project — §9.2 says the
rate-limiting-step display "will teach the game better than any tutorial" — so it gets
milestones of its own rather than being a corner of the editor.

## Milestones

### F03-M01 — Sandbox tick-through

Step the build-phase cell forward one tick at a time (§9.1). Watch proteins get built,
slots fill, the membrane populate.

**Done when:** stepping N ticks in the sandbox and running N ticks in a committed battle
produce identical state. This doubles as the determinism regression test for F01.

### F03-M02 — Steady-state readout panel

Predicted gross metabolites/tick, **upkeep/tick** (the churn rent from §3.2), net/tick,
and the predicted equilibrium slot allocation **rendered as the actual rack** — §9.2 calls
that the single most important readout, because slot count *is* throughput.

**Done when:** the predicted rack matches the rack the sim actually settles into, asserted
by test across several plasmids including one where a strong promoter starves a weak one.

### F03-M03 — Pipeline flow and the rate-limiting step

Food in → catabolism → metabolites → growth, rendered as a flow with the bottleneck
highlighted (§9.2). Per §7.4, capture rate belongs here beside metabolites/tick, since at
knife-edge food density capture rate is the stat that actually decides battles.

**Done when:** starving a working build of food moves the highlighted bottleneck to the
import step without any change to the widget's configuration.

### F03-M04 — Plain-language event log

§9.3: "Tick 41: Importer evicted Sensor-A from membrane slot 3." A view over F01's event
stream, with no sim state of its own.

**Done when:** every event type F01 emits has a sentence, and a battle replayed from the
same seed produces the same log.

## Open questions

- Is the steady-state prediction computed analytically from §3.1's share rule, or by
  running the sandbox forward until it settles? Running it forward cannot drift from the
  sim and is the safer default; analytic is faster and may be needed if the panel updates
  live on every edit.
- How much of this survives into the battle view versus staying in the build phase.

## Changelog

- `2026-08-23` — Created.
