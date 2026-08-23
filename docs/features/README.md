# Feature register

Every `F##` number ever allocated, in allocation order. **Check this table and add your
row before creating a feature doc.** Numbers are never reused or renumbered — a cut
feature keeps its number and gets status `cut`.

Status: `planned` · `in progress` · `done` · `cut`

| ID | Feature | Doc | Status | Notes |
|---|---|---|---|---|
| F01 | Simulation Core | [F01_Simulation-Core.md](F01_Simulation-Core.md) | in progress | Deterministic tick engine. Prototype 1 block set only. |
| F02 | Plasmid Editor | [F02_Plasmid-Editor.md](F02_Plasmid-Editor.md) | planned | The build phase — the game's only decision surface. |
| F03 | Legibility Layer | [F03_Legibility-Layer.md](F03_Legibility-Layer.md) | planned | Spec §9, non-negotiable. Ships with F02, not after. |
| F04 | Battle Presentation | [F04_Battle-Presentation.md](F04_Battle-Presentation.md) | planned | Completes Prototype 1. **Gate: F04-M05.** |
| F05 | Regulation and Toxin | [F05_Regulation-And-Toxin.md](F05_Regulation-And-Toxin.md) | planned | Prototype 2. Sketch only. **Gate: F05-M06.** |
| F06 | Opponent and Shared Medium | [F06_Opponent-And-Shared-Medium.md](F06_Opponent-And-Shared-Medium.md) | planned | Prototype 3. Sketch only. **Gate: F06-M04.** |
| F07 | Run Layer | [F07_Run-Layer.md](F07_Run-Layer.md) | planned | Acts, drafting, environments. Sketch only. |
| F08 | Game Shell | [F08_Game-Shell.md](F08_Game-Shell.md) | planned | Menu, persistence, export. Sketch only. |

## Next free number

`F09`.

## Build order

Allocation order happens to match build order here, but that is a coincidence of planning
everything at once — do not rely on it for future features.

**F01 → F02 + F03 → F04 → *gate* → F05 → *gate* → F06 → *gate* → F07 → F08**

The gates are spec §11's prototype questions and they are real stopping points. Each one
is a milestone that produces an answer rather than code, and a `no` means changing the
design rather than proceeding to the next feature.

F01–F04 are specified in earnest. F05–F08 are **sketches** — milestone titles and rough
scope, recorded so the arc to a minimum viable game is visible, but not to be treated as
settled. Write them properly when the gate before them has an answer.
