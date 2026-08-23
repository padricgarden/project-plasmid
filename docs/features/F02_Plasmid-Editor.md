# F02: Plasmid Editor

**Status:** planned
**Spec sections:** §4, §5, §5.3, §10
**Depends on:** F01

## Purpose

The build phase — the interface where the player arranges gene blocks on the circular
plasmid. Per spec §7.0 there is no mid-battle input, so **this screen is the entire
decision surface of the game.** Prototype 1's question ("is arranging blocks to raise
metabolites/tick fun on its own?") cannot be asked without it.

## Design constraints

- **Arrangement must feel like arrangement.** Order and adjacency carry all the meaning
  (§5.3); the interface has to make reordering cheap and the consequence immediate.
- **The unified transporter must not be split.** §10 names its illegibility as a known
  risk and names the mitigation: a topology preview with membrane and directional arrows.
  Splitting the block back into separate import/export blocks is explicitly forbidden.
- **The ring wraps.** The last gene reading into the first (§4) must be visible, not a
  rule the player learns by losing.

## Approach

`src/ui/`, scenes beside their scripts. The editor operates on F01's plasmid data model
directly and serialises through F01-M02's text notation, so an editor bug and a sim bug
are always distinguishable.

Only M01 and M02 are required to run the Prototype 1 playtest. M03 and M04 are the
difference between a testable toy and something a stranger can sit down with — worth
doing, but not before the gate.

## Milestones

### F02-M01 — Ring rendering and block placement

The circular plasmid drawn with its blocks in order; insert, remove, and drag-to-reorder.

**Done when:** the §5.4 starting protein can be built by hand and the resulting plasmid is
accepted and run by F01 with no hand-editing.

### F02-M02 — Topology preview

The membrane drawn across the protein under construction, cytoplasmic and extracellular
sides distinguished, directional arrows on transporters. The §10 mitigation.

**Done when:** moving a Food block from one side of a Membrane Domain to the other visibly
flips the transporter from import to export, and a cytoplasmic Transporter+Food is
visibly marked as doing nothing.

### F02-M03 — Block palette and plain-language function readout

The available blocks, and a sentence describing what the currently selected protein will
actually do once resolved through §5.3.

**Done when:** a player can tell whether their transporter imports or exports without
running the sim.

### F02-M04 — Commit flow

Lock the plasmid, count blocks, show the burden-adjusted growth target (§4.1), hand off
to the battle.

**Done when:** committing moves cleanly into F04's watch phase and the plasmid cannot be
edited afterwards.

## Open questions

- Does the ring stay fixed with blocks placed onto it, or does the player rotate the ring?
  Affects how obvious wrapping is.
- How much of the §5.3 resolution is shown inline versus in F03's readout panel — there is
  a real risk of building the same explanation twice in two places.

## Changelog

- `2026-08-23` — Created.
