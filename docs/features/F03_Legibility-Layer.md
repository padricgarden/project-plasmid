# F03: Legibility Layer

**Status:** done
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

### F03-M01 — Sandbox tick-through ✅

Step the build-phase cell forward one tick at a time (§9.1). Watch proteins get built,
slots fill, the membrane populate.

**Done when:** stepping N ticks in the sandbox and running N ticks in a committed battle
produce identical state. This doubles as the determinism regression test for F01.

### F03-M02 — Steady-state readout panel ✅

Predicted gross metabolites/tick, **upkeep/tick** (the churn rent from §3.2), net/tick,
and the predicted equilibrium slot allocation **rendered as the actual rack** — §9.2 calls
that the single most important readout, because slot count *is* throughput.

**Done when:** the predicted rack matches the rack the sim actually settles into, asserted
by test across several plasmids including one where a strong promoter starves a weak one.

### F03-M03 — Pipeline flow and the rate-limiting step ✅

Food in → catabolism → metabolites → growth, rendered as a flow with the bottleneck
highlighted (§9.2). Per §7.4, capture rate belongs here beside metabolites/tick, since at
knife-edge food density capture rate is the stat that actually decides battles.

**Done when:** starving a working build of food moves the highlighted bottleneck to the
import step without any change to the widget's configuration.

### F03-M04 — Plain-language event log ✅

§9.3: "Tick 41: Importer evicted Sensor-A from membrane slot 3." A view over F01's event
stream, with no sim state of its own.

**Done when:** every event type F01 emits has a sentence, and a battle replayed from the
same seed produces the same log.

## Open questions

- ~~Analytic prediction, or run the sandbox forward?~~ Run it forward. It cannot drift
  from the sim, and a full 240-tick run per edit turns out to be cheap enough not to
  notice. Revisit only if the panel ever needs to update on every keystroke.
- How much of this survives into the battle view versus staying in the build phase.

## Changelog

- `2026-08-23` — Created.
- `2026-08-23` — **The open question is settled: prediction is done by running the sim, not
  by analysing it.** Every number in the readout comes from a real run of a copy of the
  cell. A hand-written predictor would be a second implementation of the tick loop and
  would drift from the first the moment either changed; the sim is deterministic (§4.2),
  so running it *is* the prediction. `Prediction` is the shared core all three readouts
  are views over — one model, not three half-models.
- `2026-08-23` — **M01 done.** `Sandbox` steps a copy tick by tick. Its event stream is
  asserted byte-identical to a committed battle's, which is what makes §9.1 worth having:
  a sandbox that drifts would teach players a game they are not playing.
- `2026-08-23` — **M02 done.** Gross, upkeep, net and capture rate, plus the equilibrium
  rack drawn as a rack. Measured upkeep is asserted against what `ExpressionUnit` works
  out analytically, so §3.2's churn rent is checked from both ends.
- `2026-08-23` — Prediction deliberately runs *past* the win, twice a battle's length. A
  healthy cell divides around tick 73, long before its racks settle — stopping there would
  report the opening ramp as if it were steady state. Rates are averaged over the back
  half for the same reason.
- `2026-08-23` — **M03 done.** The pipeline draws as four stages with the narrow one
  highlighted and one sentence of advice. The classifier's ordering is the subtle part:
  running out of metabolites is usually a *symptom*, so physical backlogs are read first
  and the economy is blamed only when food is moving freely. Stalls are split by cause —
  a cell with importers it cannot afford has an economy problem, while a cell with no
  importers also stalls but needs the opposite advice.
- `2026-08-23` — **DIGESTION is not reachable with the Prototype 1 block set.** Enzymes
  and importers share one cadence and a single gene fills its whole compartment, so an
  eight-importer cell always has eight enzymes to match. The stage is implemented and
  unit-tested; F05 makes it reachable by putting regulation proteins into the internal
  rack. Recorded rather than quietly dropped.
- `2026-08-23` — **M04 done.** Every `SimEvent.Type` has a sentence, asserted by iterating
  the enum, so a new event type cannot be added silently. Routine bookkeeping is filtered
  out by default — a line for every maturation would bury the eviction that decided the
  battle — with a toggle to see everything.
- `2026-08-23` — **Found a legibility gap while testing: blocks past the last terminator
  are never transcribed**, but §4.1 still charges growth for them. Pure cost, previously
  invisible. `PlasmidDraft.dead_weight_blocks()` now flags them.
- `2026-08-23` — **Harness bug: a GDScript runtime error inside a test aborted that test
  without failing it**, so the suite could report "0 failures" while a test silently did
  almost nothing. Caught when a renamed field left a stale reference. `test.ps1` now fails
  the run if any `SCRIPT ERROR` appears.
