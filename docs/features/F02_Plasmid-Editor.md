# F02: Plasmid Editor

**Status:** in progress
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

### F02-M01 — Ring rendering and block placement ✅

The circular plasmid drawn with its blocks in order; insert, remove, and drag-to-reorder.

**Done when:** the §5.4 starting protein can be built by hand and the resulting plasmid is
accepted and run by F01 with no hand-editing.

### F02-M02 — Topology preview ✅

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

- ~~Does the ring rotate, or stay fixed?~~ Fixed, with index 0 pinned to the top and the
  wrap point marked, so the place where the last gene reads into the first never moves.
- How much of the §5.3 resolution is shown inline versus in F03's readout panel — still
  a real risk of building the same explanation twice. M02 draws topology; M03 should
  describe function in words and not re-draw it.

## Changelog

- `2026-08-23` — Created.
- `2026-08-23` — **M01 done.** The ring draws the plasmid as a ring, with index 0 pinned
  to the top and the wrap point marked, so §4's "the last gene reads into the first" is
  visible rather than a rule to be surprised by. Blocks are placed from a palette,
  reordered by dragging one chip onto another, and removed from the side panel.
- `2026-08-23` — **All editing behaviour lives in `PlasmidDraft`, a `RefCounted` with no
  scene dependency**, so insert/remove/move/validate are tested headlessly and the scene
  layer only draws and forwards input. This is the split worth protecting: a rule that
  exists only inside a `_gui_input` handler cannot be tested and will drift from the sim.
  The scene tests drive the editor through its own handlers and assert that what comes
  out the far end runs a battle.
- `2026-08-23` — The `.tscn` holds only the root node and its script; the tree is built
  in `_ready()`. Nearly all of it is dynamic — the ring rebuilds on every edit, the
  palette is generated from the block grammar — so a hand-authored scene would be one
  more thing to keep in sync. Worth revisiting once the layout stops moving.
- `2026-08-23` — **Test runner bug found and fixed, affecting everything downstream.**
  It ran the suite from `_init()`, where the scene tree root is not yet inside the tree,
  so any `Control` added to it never received `_ready()` — scene tests saw half-built
  nodes with null members. Neither `_init` nor `_initialize` works; the suite now runs on
  the first `_process` frame. F03 and F04 would have hit this immediately.
- `2026-08-23` — Placing a block inserts *after* the current selection rather than
  appending, so a plasmid is built left to right instead of every block needing a drag.
  Selection travels with a dragged block for the same reason.
- `2026-08-23` — **M02 done.** The selected protein is drawn flat with the membrane
  across it, the two sides shaded as places rather than described as a rule, and an arrow
  through the membrane pointing the way things actually move. §10 names this widget as
  the one mitigation for the unified transporter, right before "do not split the block" —
  so it is the thing standing between that design decision and an illegible game.
- `2026-08-23` — **The preview cannot disagree with the sim, structurally.** It resolves
  through `Adjacency`, the same call `GeneExpression.compile()` makes, so the arrow shown
  is the behaviour that will happen. A test asserts the two agree across every membrane
  arrangement the Prototype 1 grammar can reach.
- `2026-08-23` — Removed a duplicated rule while wiring this up: "is this block outside
  the membrane" existed inline in `SimState._catabolise` and was about to be written a
  second time in the preview. It now lives once, on `ResolvedProtein.is_outside()`.
  Verified by mutation — inverting it fails both the sim's extracellular-enzyme test and
  the preview's side-placement test, which is the proof that they share it.
- `2026-08-23` — `ProteinDef` gained `ring_indices`, so a protein can be traced back to
  the blocks it came from. The alternative was re-walking §4's transcription rules inside
  the editor, which would have put those rules in two places.
- `2026-08-23` — Readthrough means a block can belong to *two* proteins at once (§4). The
  preview shows the first and says so, rather than silently picking a favourite.
- `2026-08-23` — **A layout bug no test could have caught.** The screen overflowed
  Godot's default 1152×648 viewport and the palette was simply not on screen. Found by
  rendering a frame and looking at it. Added `scripts/screenshot.ps1` and
  `tools/screenshot.gd` so that check is repeatable; F03 is entirely visual and will need
  it. Viewport default is now 1280×832.
