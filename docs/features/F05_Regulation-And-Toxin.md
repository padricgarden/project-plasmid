# F05: Regulation and Toxin

**Status:** planned
**Spec sections:** §5.1, §6, §3.4, §2.2
**Depends on:** F01, F04 (gated on the Prototype 1 answer)

> **Sketch, not a specification.** Milestone titles and ordering are provisional and the
> Approach section is deliberately empty. Fill this in properly when F04-M05 has an
> answer — what Prototype 1 teaches will change what this feature needs to be.

## Purpose

Spec §11's Prototype 2. Adds the remaining block grammar and the regulation layer, so
that the cell can respond to conditions it could not respond to before. The question this
prototype exists to answer: **does anyone build a conditional circuit unprompted?**

The intended "aha" moment (§6, ~battle 3) is `Sensing + Toxin + TF` gating a toxin-efflux
gene, and the player noticing slot pressure drop. That moment either happens or the
regulation layer does not pay for itself.

## Design constraints

- Sensing and TF are free (§2.2) — never tax the circuit itself.
- **Regulation must be genuinely necessary, not merely available.** §10 names "sensor
  circuits never pay off" as a live risk: it requires slot pressure to be tight and toxin
  exposure to be actually lethal. If always-on expression stays strictly better, this
  feature has failed regardless of whether the blocks work.
- Players should **discover** that Sensing/TF/activators form a complete logic basis
  rather than be taught it (§6).

## Milestones

### F05-M01 — Toxin, defense, and lysis
Toxin target block, ambient toxin in the medium, `Catabolic + Toxin` defense at 1/unit,
efflux via export, and the lysis loss condition wired live.
**Done when:** an unprotected cell reliably lyses in a toxic environment and a defended
one does not.

### F05-M02 — Sensing domain
Turns neighbouring domains on and off based on presence of a target.
**Done when:** a sensed gene measurably stops paying synthesis cost while its target is
absent.

### F05-M03 — TF domain, operator colours, promoter defaults
3–4 operator colours, repressible and activatable promoters, AND via multiple sensors,
NOR via multiple TFs.
**Done when:** the §6 aha circuit can be built, and the emergency-gene behaviour of §3.2
falls out by construction — zero slots held until toxin appears, then flooding in.

### F05-M04 — Anchor and Degron
FIFO exemption with upkeep, and timed slot vacation (§3.4).
**Done when:** an anchored sensor survives a high-rate economy gene that would otherwise
crowd it out.

### F05-M05 — Anabolic enzyme
Synthesis of toxin (2/unit) and food (4/unit) (§2.2).

### F05-M06 — Prototype 2 gate
**Done when:** §11's second question has an answer. Record it here.

## Open questions

- §10: does depth strictly beat breadth? Needs at least one environment that a mono-build
  cannot survive *at all*, not merely survives worse.

## Changelog

- `2026-08-23` — Created as a sketch.
