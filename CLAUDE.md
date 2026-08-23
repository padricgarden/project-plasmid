# Project Plasmid

A roguelike autobattler in Godot 4.7. The player arranges gene blocks on a circular
plasmid, commits, and watches a deterministic 120-tick battle resolve against a rival
cell in a shared medium.

**The design spec is [docs/design-spec.md](docs/design-spec.md) and it is the source of
truth.** Read the relevant section before implementing a system — the numbers, ratios,
and adjacency rules there are load-bearing and several of them are deliberately
counter-intuitive. When code and spec disagree, that is a bug in one of them; say which.

---

## Repository layout

```
project-plasmid/          <- repo root
├── CLAUDE.md
├── docs/
│   └── design-spec.md    <- the design spec (v0.3)
├── Godot/                <- vendored Godot 4.7.2 editor (git-ignored, not in the repo)
├── scripts/              <- PowerShell helpers (test.ps1, editor.ps1)
└── project-plasmid/      <- THE GODOT PROJECT (project.godot lives here)
    ├── assets/           <- art / fonts / audio
    ├── src/              <- all game code; see src/README.md for the dependency rules
    │   ├── sim/          <- deterministic simulation core (no Node, no rendering)
    │   ├── data/         <- block/promoter/environment definitions as Resources
    │   ├── ui/           <- build-phase editor, readout panel, event log
    │   ├── battle/       <- battle presentation, clock, speed controls
    │   ├── run/          <- acts, drafting, events, opponent roster
    │   └── autoload/     <- singletons (keep this list short)
    └── tests/            <- headless test suite + runner
```

Note the doubled name: the Godot project is the **inner** `project-plasmid/` directory.
`res://` maps to `project-plasmid/project-plasmid/`.

## Engine

Godot **4.7.2 stable**, GDScript, Mobile renderer, D3D12 on Windows.

The editor executable is vendored at `Godot/Godot_v4.7.2-stable_win64.exe` (alongside a
`_console` variant that prints to stdout — **use the console build for anything
scripted**). It is git-ignored; a fresh checkout needs it downloaded from
godotengine.org and dropped in `Godot/`.

```powershell
.\scripts\editor.ps1     # open the project in the editor
.\scripts\test.ps1       # run the headless test suite
```

Raw equivalents, if you need to vary the flags:

```powershell
.\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path project-plasmid --script res://tests/run_tests.gd
.\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path project-plasmid --check-only --script res://src/sim/some_file.gd
```

Godot should not be open in the editor while a script writes `.tscn` or `.tres` files —
the editor can overwrite them when it regains focus. Ask the user to close it first.

## Testing

`tests/run_tests.gd` is a small `SceneTree` runner: it finds every `test_*.gd` under
`res://tests/`, calls each `test_*` method, and exits non-zero on failure. A test class
gets the runner injected via `set_runner()` and asserts with `check()` / `check_eq()`.
Optional `before_all` / `before_each` / `after_each` / `after_all` hooks are honoured.

`tests/test_smoke.gd` is a placeholder — delete it once `sim/` has real coverage.

**The simulation core must be tested headlessly.** It is deterministic by design, so
every economic claim in the spec (§2.4 baseline ≈ 0.6 metabolites/tick, §3.1 slot-share
equilibrium, §4.1 burden curve) is a test that either passes or tells us the spec is
wrong. Write those tests as the systems land; they are the balance harness.

## Architecture rules

1. **`src/sim/` is pure.** No `Node`, no scene tree, no `_process`, no input, no
   rendering, no unseeded randomness. It is constructed, stepped with `tick()`, and
   inspected. Everything else may depend on it; it depends on nothing but `src/data/`.

2. **Determinism is a design requirement, not a nicety** (spec §4.2, §10). Promoters
   fire on fixed periods. Any randomness — food spawn timing, draft offers, radiation —
   goes through an explicitly seeded `RandomNumberGenerator` owned by the run layer and
   passed in. Never call the global `randi()` / `randf()`. Iterating a `Dictionary` for
   anything order-sensitive is a determinism bug; sort the keys first.

3. **The sim must be speculatively runnable.** The build phase needs to step a copy of
   the cell forward without committing (spec §9.1) and predict steady state (§9.2). That
   means sim state must be cheaply copyable and stepping must have no side effects
   outside the state object.

4. **Integers for the economy.** Metabolites, growth, ticks, slots and ages are `int`.
   Floats invite drift and make equilibria fuzzy. Costs that divide (synthesis at
   1 per 3 blocks) round up explicitly with `ceili()`.

5. **Events are data.** The sim emits a structured event list per tick (evictions, TF
   binds, lysis, maturation) rather than logging strings. The plain-language event log
   (§9.3) is a *view* over that list. This keeps the sim pure and the log testable.

6. **Presentation never mutates sim state.** Speed controls change how fast ticks are
   consumed, never what a tick does.

## Design invariants to protect

These are the parts of the spec most likely to be destroyed by an otherwise reasonable
refactor. Flag it if a change would break one:

- **Slot share is bought with promoter rate and paid for every tick** (§3.1, §3.2).
  One protein per slot, no stacking, FIFO eviction. Throughput scales by spending slots,
  not by expression volume. This is the design's most unusual property.
- **Adjacency determines function** (§5.3). A target block sets the target for *both*
  neighbours; transporter direction is read off which side the target sits on relative
  to the membrane domain. Do not split the unified transporter into separate
  import/export blocks to make it legible — fix legibility with the topology preview.
- **Metabolites are simultaneously the currency and the score** (§2). Every cost must
  draw from the same pool that wins the game. Never add a second currency.
- **Youngest-first spending** from the immature pool (§2.1), and banked growth is
  untouchable.
- **No mid-battle input** (§7.0). Sensors and TFs are the only adaptation mechanism.

## Build order

Follow spec §11. We are at the start of **Prototype 1**: one cell, no opponent, no
roguelike layer — three blocks (Catabolic, Transporter, Food), a membrane, one promoter,
one environment, slots, ticks, a growth bar. The question it answers is whether
arranging blocks to raise metabolites/tick is fun on its own. Do not build the run
layer, drafting, or the second cell until that question has an answer.

Current status: scaffolding only. No simulation code has been written yet.

## Conventions

- GDScript follows the [official style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):
  `snake_case` files and members, `PascalCase` classes, `_leading_underscore` for private
  members, tabs for indentation, two blank lines between top-level definitions.
- **Static typing everywhere** (`var x: int`, `func f(a: String) -> void`). It catches
  the class of error that a deterministic sim hides until tick 90.
- Prefer `class_name` on sim and data types so they are usable without preloads.
- Document non-obvious rules with `##` doc comments that cite the spec section, e.g.
  `## Youngest-first, per spec §2.1.`
- Scenes live beside the script that drives them, named to match (`readout_panel.tscn`
  next to `readout_panel.gd`).

## Git

- Branch: `main`. Remote: `origin` → github.com/padricgarden/project-plasmid.
- Ignored: `.godot/` (import cache), the vendored `Godot/` editor, build output, and
  `export_presets.cfg` (it can embed local paths and signing credentials). Everything
  under `src/`, `tests/`, `assets/` and `docs/` is tracked — including `.import` files,
  which Godot needs.
- The checkout lives inside OneDrive. If a file looks mysteriously locked or reverted,
  suspect sync before suspecting git.
- Commit or push only when asked.
