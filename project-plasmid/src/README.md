# Source layout

| Directory | Contains | May depend on |
|---|---|---|
| `sim/` | The deterministic simulation core: plasmid, transcription, proteins, slots, metabolites, medium, tick loop. **Pure GDScript — no `Node`, no scene tree, no rendering, no input, no randomness that isn't seeded.** | nothing but `data/` |
| `data/` | Block, promoter, food and environment definitions as `Resource` subclasses, plus the catalogs that load them. Data only, no behaviour. | nothing |
| `ui/` | Build-phase plasmid editor, readout panel, event log, topology preview. Scenes live next to their scripts. | `sim/`, `data/` |
| `battle/` | Battle presentation: drives the sim clock, renders cells and the shared medium, speed controls. | `sim/`, `data/`, `ui/` |
| `run/` | Roguelike run layer: acts, drafting, premium rewards, mid-run events, opponent roster. | all of the above |
| `autoload/` | Singletons registered in `project.godot`. Keep this list very short. | `data/` |

The one rule that matters: **`sim/` never imports upward.** It must be constructible and steppable from a plain script with no window, so the build-phase sandbox (`§9.1` of the design spec) can run it forward speculatively and the tests can run it headless.
