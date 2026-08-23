# F08: Game Shell

**Status:** planned
**Spec sections:** —
**Depends on:** F07

> **Sketch, not a specification.**

## Purpose

The frame around the game: main menu, starting and ending a run, settings, and resuming
an in-progress run. No design-spec content — this is the plumbing that makes the other
seven features into something a person can launch and put down.

Kept last and kept small on purpose. Prototype 1 through 3 all run from a single scene
with no shell at all; adding one earlier costs time and buys nothing that a playtest
needs.

## Milestones

### F08-M01 — Scene flow and main menu
New run, quit, and the transitions between menu → build → battle → draft.
**Done when:** the game is launchable from a built executable and reaches a run without
touching the editor.

### F08-M02 — Run persistence
Save and resume an in-progress run.
**Done when:** quitting mid-run and relaunching restores the plasmid, act position, and
banked run state exactly. F01's determinism makes this cheap — the run is its seed plus
its decisions.

### F08-M03 — Settings and export
Speed defaults, audio, and a working Windows export preset.

## Open questions

- Does a run need to survive a crash, or is quit-and-resume enough for the MVG? Enough,
  almost certainly.

## Changelog

- `2026-08-23` — Created as a sketch.
