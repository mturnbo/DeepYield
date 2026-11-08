# Deep Yield Playable Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable survival prototype: lay out the platform from the arrival ship's kits, mine with 4 ships, refine and build, fetch comet ice, and keep the whole crew on the platform through the second comet pass.

**Architecture:** All rules live in plain GDScript classes under `game/sim/` (no nodes), advanced one game hour per `GameState.step()` and covered by GUT tests run headless. Every tunable number lives in `game/data/balance.json`. Scenes under `game/view/` and `game/ui/` read the state every frame and send player actions to `GameState` methods; they reuse the existing `design/` model scripts and never change state directly.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.x (Godot 4 line) for tests.

**Spec:** `docs/superpowers/specs/2026-11-07-playable-prototype-design.md`

## Global Constraints

- Godot 4.7, GDScript, the existing project at the repo root. `godot` is at `/opt/homebrew/bin/godot`.
- One game hour is 2 seconds of real time at normal speed; fast speed is 0.5 s per hour. All orders can be given while paused.
- Distances in meters: module base 30 m across, junction 10 m, frame piece 15 m.
- Every number marked "(my call)" in the spec goes in `game/data/balance.json`, nowhere else.
- The sim never touches nodes; views never change sim state except through `GameState` action methods.
- Tests for every rule: happy path, limits and expected failures. No mocking of the sim.
- Code style (owner's standing rules): explicit over clever, small focused functions, no comments or annotations added to code you didn't change.
- Commits: one-line messages ending with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Work on branch `prototype`. Never push without asking.
- Downloading GUT needs the owner's OK at execution time (say the file, source and size).

## Review Focus

1. Anything built off the ship dock's free ports, a module or a junction: refused with "The dock can only join one module", so the dock always stays on the edge. (Task 2)
2. A ship comes home with a material whose storage module isn't built yet: it waits in its bay with the "storage full" alert instead of losing cargo or crashing. (Task 7)
3. The player changes a ship's assignment mid-trip: the current trip finishes with the old materials; the next trip uses the new ones. (Task 7)
4. A queued item whose inputs never arrive: nothing is taken from stock until all inputs are there, and the other building's queue keeps running. (Task 9)
5. The player orders ice, but the comet leaves reach before the ship departs: the order is cancelled with no ice trip; a ship already on its way still brings the chunk home. (Task 8)

---

## File Structure

```
addons/gut/                     GUT, vendored (Task 1)
.gutconfig.json                 GUT settings: test dir, exit on finish (Task 1)
game/data/balance.json          every tunable number (Task 1, grown by later tasks)
game/sim/balance.gd             Balance: loads balance.json (Task 1)
game/sim/sim_clock.gd           SimClock: real seconds -> game hours (Task 1)
game/sim/platform_layout.gd     PlatformLayout + PlatformNode: nodes, ports, placement rules (Task 2)
game/sim/storage.gd             Storage: raw-material containers on built storage modules (Task 3)
game/sim/stock.gd               Stock: refined metals, parts, argon, frame pieces (Task 3)
game/sim/construction.gd        Construction: sites and robot work (Task 4)
game/sim/game_state.gd          GameState: owns everything, step(), player actions (Task 4, grown)
game/sim/power.gd               Power: operators, supply, demand, fuel, batteries (Task 5)
game/sim/comets.gd              Comets: seeded schedule of passes (Task 6)
game/sim/mining_ship.gd         MiningShip: one ship's state and trip timing (Task 7)
game/sim/fleet.gd               Fleet: ships, bays, loads, docking, unloading, ice trips (Tasks 7-8)
game/sim/production.gd          Production: refinery, factory and assembly queues (Task 9)
game/sim/life_support.gd        LifeSupport: beds, plants, ice, nitrogen, ship reserve (Task 10)
game/sim/advisor.gd             Advisor: alerts and checklist (Task 11)
test/sim/helpers.gd             builds states and the starter platform for tests (Task 4)
test/sim/test_*.gd              one test file per sim file
game/main.tscn, game/game.gd    world, sim driver, speed (Task 12)
game/view/platform_view.gd      modules, frames, construction ghosts, ice chunk (Task 13)
game/view/placeholder_module.gd factory and assembly stand-ins (Task 13)
game/view/placement_tool.gd     port picking and preview (Task 14)
game/view/fleet_view.gd         ships flying, dock doors (Task 15)
game/ui/hud.tscn + hud.gd       top bar, speed buttons, alerts, checklist (Task 16)
game/ui/build_menu.gd           build menu (Task 14)
game/ui/module_panel.gd         module panel and queues (Task 17)
game/ui/ship_popup.gd           ship popup (Task 18)
game/ui/end_screen.gd           result and summary (Task 19)
```

## Shared names (used across tasks)

- Module kinds (`String`): `"command"`, `"ship_dock"`, `"fusion_generator"`, `"refinery"`, `"factory"`, `"assembly"`, `"gas_storage"`, `"metal_storage"`, `"electrolysis_plant"`, `"habitat"`, plus `"junction"`.
- Ports (`int`): `0` = +X, `1` = +Z, `2` = -X, `3` = -Z. Positions on the ground plane are `Vector2(x, z)`.
- Materials: gases `"hydrogen"`, `"helium"`, `"nitrogen"`, `"argon"`; metals `"iron"`, `"nickel"`, `"magnesium"`, `"silicon"`, `"aluminum"`, `"platinum"`, `"palladium"`.
- Actions return `String`: `""` means done, anything else is the reason shown to the player.

---

### Task 1: Test harness, balance data, sim clock

**Files:**
- Create: `addons/gut/` (vendored), `.gutconfig.json`, `game/data/balance.json`, `game/sim/balance.gd`, `game/sim/sim_clock.gd`
- Test: `test/sim/test_balance.gd`, `test/sim/test_sim_clock.gd`

**Interfaces:**
- Produces: `class_name Balance`, `static func load_default() -> Dictionary` (reads `res://game/data/balance.json`). `class_name SimClock extends RefCounted`: `var speed: String` (`"paused"`, `"normal"`, `"fast"`), `func _init(seconds_per_hour: Dictionary)`, `func advance(delta: float) -> int` (whole hours to step, at most `MAX_STEPS_PER_FRAME = 8`, remainder kept).

- [ ] **Step 1: Create branch and install GUT**

Run: `git checkout -b prototype`. With the owner's OK, download the latest GUT 9.x release for Godot 4 from https://github.com/bitwes/Gut/releases into a new empty folder in the scratchpad, copy only its `addons/gut` into the repo, and write `.gutconfig.json` with `{"dirs": ["res://test/"], "include_subdirs": true, "should_exit": true, "log_level": 1}`.
Run: `godot --headless --path . --import` then `godot --headless --path . -s addons/gut/gut_cmdln.gd`
Expected: GUT runs and reports 0 tests.

- [ ] **Step 2: Write `game/data/balance.json`** with exactly these keys (later tasks read them):

```json
{
  "seconds_per_hour": {"normal": 2.0, "fast": 0.5},
  "seed": 1,
  "layout": {"piece_length": 15, "module_size": 30, "junction_size": 10, "max_run": 3,
             "module_spacing": 60, "wide_spacing": 75, "wide_kinds": ["electrolysis_plant", "ship_dock"],
             "build_area": 1200, "first_node_max_distance": 300, "frame_width": 4},
  "arrival_ship": {"position": [-260, 0], "power_mw": 20, "reserve_person_hours": 12000},
  "start": {"crew": 12, "robots": 20, "mining_ships": 4, "frame_pieces": 32,
            "kits": ["ship_dock", "command", "fusion_generator", "refinery", "factory", "assembly", "gas_storage", "metal_storage"]},
  "work": {"kit": 120, "assembled_module": 80, "junction": 16, "frame_piece": 8, "robots_per_job": 4},
  "modules": {
    "command": {"power_mw": 3, "crewed": true}, "ship_dock": {"power_mw": 6, "crewed": true},
    "fusion_generator": {"power_mw": 0, "crewed": false}, "refinery": {"power_mw": 7, "crewed": true},
    "factory": {"power_mw": 5, "crewed": true}, "assembly": {"power_mw": 5, "crewed": true},
    "gas_storage": {"power_mw": 1, "crewed": false}, "metal_storage": {"power_mw": 1, "crewed": false},
    "electrolysis_plant": {"power_mw": 7, "crewed": true}, "habitat": {"power_mw": 4, "crewed": false},
    "junction": {"power_mw": 0, "crewed": false}
  },
  "power": {"generator_mw": 60, "frame_piece_mw": 0.1, "fuel_core_mwh": 86400, "mwh_per_hydrogen": 150,
            "battery_hours": 12, "battery_speed": 0.5,
            "operator_priority": ["electrolysis_plant", "ship_dock", "refinery", "assembly", "factory", "command"],
            "shutdown_order": ["command", "factory", "assembly", "refinery", "ship_dock", "metal_storage", "gas_storage", "habitat", "electrolysis_plant"]},
  "storage": {"gas_storage": {"hydrogen": 60, "helium": 60, "nitrogen": 60},
              "metal_storage": {"iron": 30, "nickel": 30, "magnesium": 30, "silicon": 30, "aluminum": 30, "platinum": 30, "palladium": 30}},
  "mining": {"load": 20, "caps": {"argon": 1, "platinum": 2, "palladium": 3},
             "nebula": {"materials": ["hydrogen", "helium", "nitrogen", "argon"], "max": 3, "out": 18, "work": 10, "back": 18, "wear": 0.02},
             "asteroids": {"materials": ["iron", "nickel", "magnesium", "silicon", "aluminum", "platinum", "palladium"], "max": 2, "out": 22, "work": 12, "back": 22, "wear": 0.04},
             "dock_hours": 4, "bays": 4, "max_slowdown": 0.5},
  "comets": {"first_arrival": [400, 600], "gap": [1500, 2500], "in_reach": 200, "forecast": 400, "distance": [1.0, 2.0],
             "out": 30, "carve": 10, "tow_divisor": 6000, "chunks": [1000, 2000, 3000], "cradle": 3000, "wear": 0.01, "passes": 12},
  "life": {"plant_capacity": 32, "habitat_beds": 20, "people_per_ice": 12, "person_hours_per_nitrogen": 100},
  "refinery": {"rate": 2, "argon_every": 10, "argon_metals": ["magnesium", "aluminum"]},
  "recipes": {
    "factory": {"frame_piece": {"takes": {"iron": 4, "nickel": 1}, "hours": 4},
                "module_part": {"takes": {"iron": 3, "aluminum": 1, "silicon": 1}, "hours": 4}},
    "assembly": {"habitat": {"takes": {"module_part": 10, "silicon": 4}, "hours": 40},
                 "electrolysis_plant": {"takes": {"module_part": 12, "platinum": 2}, "hours": 50},
                 "gas_storage": {"takes": {"module_part": 6}, "hours": 24},
                 "metal_storage": {"takes": {"module_part": 8}, "hours": 30},
                 "fusion_generator": {"takes": {"module_part": 14, "palladium": 3}, "hours": 60},
                 "junction": {"takes": {"module_part": 2}, "hours": 10},
                 "mining_ship": {"takes": {"module_part": 6, "magnesium": 4, "silicon": 2}, "hours": 40},
                 "robot": {"takes": {"module_part": 2, "silicon": 2}, "hours": 16},
                 "ship_repair": {"takes": {"module_part": 1}, "hours": 10}}
  },
  "alerts": {"reserve_low_hours": 200, "fuel_low_hours": 200},
  "goal_comet": 2
}
```

- [ ] **Step 3: Write failing tests**

`test_balance.gd`: `test_loads_default` asserts `Balance.load_default()["seconds_per_hour"]["normal"] == 2.0` and `["start"]["crew"] == 12`.
`test_sim_clock.gd`:
- `test_normal_speed_steps_every_two_seconds`: `advance(1.9)` → 0, then `advance(0.2)` → 1.
- `test_fast_speed`: speed `"fast"`, `advance(1.0)` → 2.
- `test_paused_never_steps`: speed `"paused"`, `advance(100.0)` → 0.
- `test_long_frame_is_capped_and_remainder_kept`: speed `"fast"`, `advance(10.0)` → 8, then `advance(0.0)` → 8, then `advance(0.0)` → 4.

- [ ] **Step 4: Run** `godot --headless --path . -s addons/gut/gut_cmdln.gd` — Expected: FAIL (classes missing).
- [ ] **Step 5: Implement `Balance` and `SimClock`** as in Interfaces.
- [ ] **Step 6: Run tests** — Expected: all pass.
- [ ] **Step 7: Commit** — `git add addons .gutconfig.json game test && git commit -m "Add GUT, balance data and sim clock"`

---

### Task 2: Platform layout and placement rules

**Files:**
- Create: `game/sim/platform_layout.gd`
- Test: `test/sim/test_platform_layout.gd`

**Interfaces:**
- Consumes: `balance["layout"]`.
- Produces: `class_name PlatformNode extends RefCounted` with `var id: int`, `var kind: String`, `var center: Vector2`, `var size: float`, `var links: Array[int]` (4 entries, node id or -1), `var built := false`, `var parent_port := -1`, `var run := 0` (pieces from parent). `class_name PlatformLayout extends RefCounted`: `func _init(layout_balance: Dictionary)`, `var nodes: Array[PlatformNode]`, `func check_first(kind: String, center: Vector2, arrival_ship: Vector2) -> String`, `func add_first(kind, center) -> PlatformNode`, `func new_center(from_id: int, port: int, run: int, kind: String) -> Vector2`, `func check_placement(from_id: int, port: int, run: int, kind: String) -> String`, `func add(from_id, port, run, kind) -> PlatformNode`, `func node(id: int) -> PlatformNode`, `func built_nodes(kind := "") -> Array[PlatformNode]`, `func frame_piece_count(only_built: bool) -> int`.

Rules (spec "The platform layout"): new center = from center + direction × (from.size/2 + run × 15 + new size/2). Refusal reasons, checked in this order:
1. `"The frame can only run 1 to 3 pieces"` (run < 1 or > 3)
2. `"That port is already used"`
3. `"The dock can only join one module"` (the from node is a dock; it got its one link when it was placed)
4. `"Too close to the <kind>"` with the kind name spaced (`"Too close to the ship dock"`): any module-module center distance < 60, or < 75 when either is a wide kind (plant or dock)
5. `"Overlaps the frame or a module"`: the new node's square plus the new run's rectangle (frame_width 4 m wide) overlaps any existing node square or run rectangle, other than the from node's own square
6. `"Outside the build area"`: any edge of the new node more than 600 m from the first node's center along x or z
`check_first`: `"Too far from the arrival ship"` past 300 m.

- [ ] **Step 1: Write failing tests**
- `test_new_center_module_to_module`: first command at (0,0); `new_center(0, 0, 2, "fusion_generator") == Vector2(60, 0)`; `new_center(0, 1, 3, "ship_dock") == Vector2(0, 75)`; `new_center(0, 2, 1, "junction") == Vector2(-35, 0)`.
- `test_run_limits`: run 0 and 4 → `"The frame can only run 1 to 3 pieces"`.
- `test_modules_need_two_pieces`: command→generator run 1 → `"Too close to the command"`; run 2 → `""`.
- `test_dock_needs_three_pieces`: command→ship_dock run 2 → `"Too close to the command"`; run 3 → `""`.
- `test_spacing_checks_every_module_not_just_neighbor`: command at (0,0); gas_storage from command port 1 run 2 → (0,60); junction from command port 0 run 1 → (35,0); metal_storage from that junction port 1 run 2 would sit at (35,50), 61 m from the command but 36 m from the gas storage → `"Too close to the gas storage"`.
- `test_dock_joins_only_one_module` (Review Focus 1): command→dock run 3 ok and added; then from dock port 0 run 3 `"refinery"` → `"The dock can only join one module"`; junction off the dock → same reason.
- `test_used_port_refused`, `test_overlap_refused` (a run that crosses an existing run), `test_outside_build_area` (chain of junctions east until past 600 m), `test_first_node_too_far` (center (100,0) with ship at (-260,0) → `"Too far from the arrival ship"`; (0,0) → `""`).
- `test_frame_piece_count`: after two added nodes with runs 2 and 3, `frame_piece_count(false) == 5`, `frame_piece_count(true) == 0`.

- [ ] **Step 2: Run** `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://test/sim/test_platform_layout.gd` — Expected: FAIL.
- [ ] **Step 3: Implement `PlatformNode` and `PlatformLayout`** (both in `platform_layout.gd`; `PlatformNode` may be an inner class exposed as `PlatformLayout.PlatformNode` if Godot refuses two `class_name`s in one file — then use that name everywhere).
- [ ] **Step 4: Run tests** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add platform layout and placement rules"`

---

### Task 3: Storage and stock

**Files:**
- Create: `game/sim/storage.gd`, `game/sim/stock.gd`
- Test: `test/sim/test_storage.gd`, `test/sim/test_stock.gd`

**Interfaces:**
- Produces: `class_name Storage extends RefCounted`: `func _init(storage_balance: Dictionary)`, `func set_modules(gas_count: int, metal_count: int)` (capacity = per-module size × count), `func amount(material: String) -> float`, `func capacity(material) -> float`, `func room(material) -> float`, `func add(material, units: float) -> float` (returns units actually stored), `func take(material, units: float) -> float`, `func is_full(material) -> bool`, `func most_stored(materials: Array) -> String` (largest amount > 0, ties by list order, `""` if none).
- `class_name Stock extends RefCounted`: `var items: Dictionary`, `func amount(key) -> float`, `func add(key, units: float)`, `func has_all(needs: Dictionary) -> bool`, `func take_all(needs: Dictionary) -> bool` (takes nothing unless all are there).

- [ ] **Step 1: Write failing tests**
- `test_no_storage_means_no_room`: `Storage` with no modules: `room("hydrogen") == 0`, `add("hydrogen", 5) == 0`.
- `test_capacity_per_module`: `set_modules(1, 1)`: `capacity("hydrogen") == 60`, `capacity("iron") == 30`; `set_modules(2, 0)`: `capacity("hydrogen") == 120`, `capacity("iron") == 0`.
- `test_add_stops_at_capacity`: one gas module, `add("helium", 70) == 60`, `is_full("helium")`.
- `test_take_only_what_is_there`: `add("iron", 5)`, `take("iron", 8) == 5`, `amount("iron") == 0`.
- `test_most_stored`: iron 4, nickel 9 → `"nickel"`; empty → `""`.
- `test_stock_take_all_is_all_or_nothing`: stock iron 3, nickel 1; `take_all({"iron": 4, "nickel": 1}) == false` and iron still 3; `take_all({"iron": 3, "nickel": 1}) == true` and both 0.

- [ ] **Step 2: Run** the two test files — Expected: FAIL.
- [ ] **Step 3: Implement `Storage` and `Stock`.**
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add storage containers and stock"`

---

### Task 4: Game state, kits and construction

**Files:**
- Create: `game/sim/construction.gd`, `game/sim/game_state.gd`, `test/sim/helpers.gd`
- Test: `test/sim/test_construction.gd`, `test/sim/test_game_state_build.gd`

**Interfaces:**
- Consumes: `Balance`, `PlatformLayout`, `Storage`, `Stock`.
- Produces:
  - `class_name Construction extends RefCounted`: `func _init(work_balance: Dictionary)`, `func add_site(node_id: int, robot_hours: float)`, `func step(robots: int) -> Array[int]` (returns node ids finished this hour; robots go to sites in the order added, up to `robots_per_job` each), `func progress(node_id) -> float` (0–1), `func robots_busy() -> int`, `var sites: Array`.
  - `class_name GameState extends RefCounted`: `func _init(balance: Dictionary, seed: int)`, `var hour := 0`, `var balance`, `var layout: PlatformLayout`, `var storage: Storage`, `var stock: Stock` (starts with `frame_piece: 32`), `var kits: Dictionary` (kind → count, from `start.kits`), `var assembled: Dictionary` (kind → count, empty), `var crew := 12`, `var robots := 20`, `var construction: Construction`, `var outcome := ""` (`""`, `"won"`, `"collapsed"`, `"ended"`), `var collapse_reason := ""`, `func step() -> void`, `func can_place(kind) -> bool` (a kit or assembled one, or junction in `assembled`), `func place_first(kind: String, center: Vector2) -> String`, `func place(from_id: int, port: int, run: int, kind: String) -> String`, `func is_running(node_id) -> bool` (Task 5 fills this in; until then: built), `func end_run()`.
  - Placing: checks the layout, then that the kind is available (`"No <kind> to place"`), then frame pieces (`"Not enough frame pieces"`); takes the kit first, else an assembled module; takes `run` frame pieces; adds a site with work = (kit 120 or assembled 80 or junction 16) + run × 8. When a site finishes, the node becomes `built` and `storage.set_modules()` is refreshed.
  - `step()` does nothing once `outcome != ""`; otherwise runs construction, then (later tasks) power, production, fleet, life support, comets/goal, then `hour += 1`.
  - `helpers.gd`: `static func new_state() -> GameState` (default balance, seed 1), `static func place_starter(state) -> Dictionary` (kind → node id; the layout below), `static func finish_construction(state)` (steps until no sites remain, at most 500 steps). Starter layout: command first at (0,0); fusion_generator from command port 0 run 2; gas_storage from command port 1 run 2; metal_storage from command port 3 run 2; refinery from metal_storage port 0 run 2; factory from gas_storage port 0 run 2; assembly from fusion_generator port 0 run 2; ship_dock from command port 2 run 3. (15 frame pieces.)

- [ ] **Step 1: Write failing tests**
- `test_construction.gd`: `test_one_site_gets_four_robots` (site 120 → after 1 step `progress == 4.0/120`); `test_robots_split_in_order` (6 sites of 8, 20 robots → first five progress, sixth 0, `robots_busy() == 20`); `test_site_finishes` (site 8, 4 robots → after 2 steps returns `[id]`).
- `test_game_state_build.gd`: `test_starts_with_kits_and_frame` (8 kits, 32 frame pieces, 12 crew, 20 robots); `test_place_takes_kit_and_frame_pieces` (after command first and generator run 2: generator kit 0, frame pieces 30, one more site); `test_place_refused_without_kit` (placing a habitat → `"No habitat to place"`); `test_place_refused_without_frame_pieces` (set frame pieces 1, run 2 → `"Not enough frame pieces"`, nothing taken); `test_starter_platform_builds` (`place_starter` then `finish_construction`: all 8 nodes built, `storage.capacity("hydrogen") == 60`, frame pieces 17); `test_kit_work_includes_frame` (generator site needs 120 + 16 = 136 robot-hours); `test_no_steps_after_outcome` (`end_run()`, `step()` leaves `hour` unchanged, `outcome == "ended"`).

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement `Construction`, `GameState` and `helpers.gd`.**
- [ ] **Step 4: Run** all sim tests — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add game state, kits and construction"`

---

### Task 5: Operators, power, fuel and batteries

**Files:**
- Create: `game/sim/power.gd`
- Modify: `game/sim/game_state.gd` (call power each step; `is_running`, `speed_of`)
- Test: `test/sim/test_power.gd`

**Interfaces:**
- Consumes: `balance["modules"]`, `balance["power"]`, `balance["arrival_ship"]["power_mw"]`, `GameState.layout`, `GameState.storage`, `GameState.crew`.
- Produces: `class_name Power extends RefCounted`: `func _init(balance: Dictionary)`, `var fuel_core_mwh: float`, `var battery_hours_left: float`, `var supply_mw: float`, `var demand_mw: float`, `var short := false`, `var on_battery := false`, `var operated: Dictionary` (node id → bool), `var powered: Dictionary` (node id → bool), `func step(layout: PlatformLayout, storage: Storage, crew: int) -> String` (returns `"energy"` when batteries run out, else `""`), `func fuel_hours_left(storage) -> float`.
- `GameState.is_running(id) -> bool` = built and (not crewed or operated) and (powered or on battery). `GameState.speed_of(id) -> float` = 0 if not running, `battery_speed` on battery, else 1.

Rules (spec "Crew" and "Power"):
- Operators: crewed built modules sorted by `operator_priority`, then id; the first `crew` get one.
- Candidates: built modules that are operated or not crewed. Demand = their `power_mw` + 0.1 × built frame pieces.
- Supply: 60 × built generators if fuel core > 0 or hydrogen > 0; if no generator is built, the arrival ship's 20 MW.
- If supply ≥ demand: all candidates powered. Generator energy used (demand, only when generators supply) burns the core first, then hydrogen at 1 u per 150 MWh.
- If 0 < supply < demand: switch off candidates in `shutdown_order` until demand fits; `short = true`.
- If generators are built but supply is 0: `on_battery = true`, every candidate runs at half speed, `battery_hours_left -= 1`; at 0 the step returns `"energy"` and `GameState` sets `outcome = "collapsed"`, `collapse_reason = "energy"`. Battery refills to 12 whenever supply returns.

- [ ] **Step 1: Write failing tests**
- `test_operators_follow_priority`: crew 2 with refinery, factory, command built → refinery operated, factory and command not.
- `test_arrival_ship_powers_before_generator`: only command, dock and gas storage built (10 MW) → all powered, `supply_mw == 20`.
- `test_short_power_shuts_down_in_order`: no generator; build command at (0,0), ship_dock (port 2 run 3), refinery (port 0 run 2), factory (port 1 run 2): demand 3+6+7+5 + 0.7 frame = 21.7 MW against the ship's 20 → command off; dock, refinery and factory on; `short`.
- `test_generator_burns_core_then_hydrogen`: starter platform built; set `fuel_core_mwh = 10`, hydrogen 10; after one step core 0 and hydrogen reduced by `(demand − 10) / 150`.
- `test_battery_then_collapse` (spec "With no fuel and no hydrogen…"): core 0, hydrogen 0 → `on_battery`, `speed_of(refinery) == 0.5`; after 12 steps `outcome == "collapsed"`, `collapse_reason == "energy"`.
- `test_battery_refills_when_fuel_returns`: 5 hours on battery, add hydrogen 10 → next step `battery_hours_left == 12`.
- `test_fuel_hours_left`: core 86400, demand 30 → about 2880.

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement `Power`** and wire it into `GameState.step()` after construction.
- [ ] **Step 4: Run** all sim tests — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add operators, power, fuel and batteries"`

---

### Task 6: Comet schedule

**Files:**
- Create: `game/sim/comets.gd`
- Modify: `game/sim/game_state.gd` (owns `comets`, built with the state's seeded RNG)
- Test: `test/sim/test_comets.gd`

**Interfaces:**
- Produces: `class_name Comets extends RefCounted`: `func _init(comet_balance: Dictionary, rng: RandomNumberGenerator)`, `var passes: Array[Dictionary]` (each `{"arrives": int, "leaves": int, "distance": float}`, `passes` count from balance), `func current(hour: int) -> int` (index in reach or -1), `func next_forecast(hour: int) -> int` (index of the next pass that is visible: the first is always visible, others from `arrives − 400`; -1 if none), `func ended_at(hour: int) -> int` (index of a pass whose `leaves == hour`, else -1).
- Arrivals: first in [400, 600]; each next = previous arrival + gap in [1500, 2500]; leaves = arrives + 200; distance in [1.0, 2.0]; all from the rng.

- [ ] **Step 1: Write failing tests**
- `test_first_pass_in_window` (seeds 1–20: 400 ≤ arrives ≤ 600, leaves == arrives + 200).
- `test_gaps_in_window`, `test_distance_in_range`.
- `test_in_reach_and_end` (`current(arrives) == 0`, `current(leaves) == -1`, `ended_at(leaves) == 0`).
- `test_forecast_visibility` (at hour 0 `next_forecast == 0`; second pass not visible until `passes[1].arrives − 400`).
- `test_same_seed_same_schedule`.

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement `Comets`.**
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add comet schedule"`

---

### Task 7: Mining ships, trips, docking and unloading

**Files:**
- Create: `game/sim/mining_ship.gd`, `game/sim/fleet.gd`
- Modify: `game/sim/game_state.gd` (owns `fleet`; actions `assign_ship`, `request_repair`; steps fleet after power)
- Test: `test/sim/test_mining_ship.gd`, `test/sim/test_fleet.gd`

**Interfaces:**
- Produces: `class_name MiningShip extends RefCounted`: `var id: int`, `var state: String` (`"in_cargo"`, `"docked"`, `"outbound"`, `"working"`, `"inbound"`, `"holding"`; Task 8 adds ice states), `var hours_left: int`, `var hours_total: int`, `var destination: String` (`"nebula"`, `"asteroids"`, `"comet"`, `"plant"`), `var bay := -1`, `var condition := 1.0`, `var assignment: Dictionary` (`{"site": String, "materials": Array}` or empty), `var next_assignment: Dictionary`, `var trip_materials: Array`, `var cargo: Dictionary`, `var repair_requested := false`, `var waiting_for_room := false`, `func load_for(materials: Array, mining_balance: Dictionary) -> Dictionary`, `func travel_hours(base: int, mining_balance: Dictionary) -> int` (= ceil(base × (1 + (1 − condition) × 0.5))).
- `class_name Fleet extends RefCounted`: `func _init(balance: Dictionary, count: int)`, `var ships: Array[MiningShip]`, `func add_ship() -> MiningShip`, `func ship(id) -> MiningShip`, `func step(dock_running: bool, storage: Storage, stock: Stock) -> void`, `func waiting_count() -> int`.
- `GameState.assign_ship(ship_id: int, site: String, materials: Array) -> String` refusals: `"Pick up to 3 gases"` / `"Pick up to 2 metals"`, `"<material> isn't found there"`, `"Pick at least one material"`. Assigning while away sets `next_assignment`; it becomes `assignment` when the ship next leaves the dock.
- `GameState.request_repair(ship_id) -> String` sets `repair_requested` (Task 9 runs the repair job).

Rules (spec "Mining"):
- Ships start `"in_cargo"`. When a dock is first running they become `"docked"` in bays 0–3 with no assignment.
- Load: L = floor(20 × condition). Share evenly across the trip's materials; capped materials (argon 1, platinum 2, palladium 3) take min(cap, share); what they leave over is shared among uncapped ones; integer units, remainder to the earliest uncapped materials in the list.
- Trip: outbound `travel_hours(out)`, working `work` hours, inbound `travel_hours(back)`; wear applied when the trip ends.
- Inbound arrival: a free bay if `dock_running`, else `"holding"` (retries each hour).
- Docked: each hour unload what fits (`argon` to `stock`, others to `storage`); `waiting_for_room` while anything is left. After the cargo is empty and `dock_hours` (4) have passed, leave on `next_assignment`/`assignment` (or stay docked if none or `repair_requested`).

- [ ] **Step 1: Write failing tests**
- `test_mining_ship.gd`: `test_even_split_three_gases` (`["hydrogen","helium","nitrogen"]` → 7, 7, 6); `test_cap_fills_with_rest` (`["iron","platinum"]` → iron 18, platinum 2); `test_argon_alone` (→ argon 1); `test_worn_ship_carries_less` (condition 0.5 → total 10); `test_worn_ship_is_slower` (condition 0 → `travel_hours(18) == 27`).
- `test_fleet.gd` (use `helpers.place_starter` + `finish_construction`):
  - `test_ships_wait_in_cargo_until_dock_runs` then move to bays 0–3.
  - `test_assign_refusals` (4 gases, 3 metals, iron at nebula, empty list).
  - `test_nebula_round_trip_timing` (assign hydrogen; ship returns to a bay after 18 + 10 + 18 hours and storage hydrogen == 20 after unloading).
  - `test_wear_after_trip` (asteroids → condition 0.96).
  - `test_holding_when_bays_full` (5 ships, 4 bays: fifth `"holding"`).
  - `test_full_storage_keeps_ship_docked` (hydrogen at 55 of 60: ship unloads 5, `waiting_for_room`, stays docked past 4 hours; `waiting_count() == 1`).
  - `test_missing_storage_keeps_cargo` (Review Focus 2): a state whose gas storage is not built; a ship back with hydrogen keeps it, stays docked, `waiting_for_room`; after gas storage is built it unloads.
  - `test_assignment_change_mid_trip` (Review Focus 3): assign iron+nickel, step 5 hours, assign silicon; cargo on return is iron+nickel; the next trip's `trip_materials == ["silicon"]`.
  - `test_argon_goes_to_stock` (argon unloads to `stock.amount("argon")`).
  - `test_no_dock_running_means_holding` (dock unpowered → returning ship holds).

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement `MiningShip`, `Fleet` and the two `GameState` actions.**
- [ ] **Step 4: Run** all sim tests — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add mining ships, trips, docking and unloading"`

---

### Task 8: Ice trips and the cradle

**Files:**
- Modify: `game/sim/fleet.gd`, `game/sim/mining_ship.gd`, `game/sim/game_state.gd`
- Test: `test/sim/test_ice.gd`

**Interfaces:**
- Consumes: `Comets.current()`, `balance["comets"]`.
- Produces: `MiningShip.ice_order := 0` (chunk size waiting to leave), `MiningShip.chunk := 0` (chunk being towed); ship states `"ice_outbound"`, `"carving"`, `"towing"`, `"at_plant"`. `GameState.cradle_ice: float`, `GameState.cradle_capacity() -> float` (3000 × built electrolysis plants), `GameState.ice_delivered := false`, `GameState.fetch_ice(ship_id: int, chunk: int) -> String` refusals: `"No comet in reach"`, `"Chunks are 1,000, 2,000 or 3,000 u"`, `"Build an electrolysis plant first"`, `"That ship is already fetching ice"`, `"That ship is still in the cargo bay"`.
- `Fleet.step()` gains a `GameState`-supplied context for the comet: change its signature to `func step(dock_running: bool, storage: Storage, stock: Stock, comet: Dictionary, delivery: Callable) -> void`, where `comet` is the current pass or `{}` and `delivery.call(units) -> bool` adds the chunk to the cradle if it fits.

Rules (spec "Comets and ice"):
- A docked ship with an `ice_order` leaves when unloaded (no 4-hour wait); a ship that's away leaves after its next unload.
- If the comet is out of reach when the ship would leave, the order is cancelled (Review Focus 5).
- Out: `travel_hours(ceil(30 × distance))`; carving 10; back `travel_hours(ceil(30 × distance × (1 + chunk / 6000)))`. Wear 0.01.
- At the plant: delivered if `cradle_ice + chunk ≤ cradle_capacity()`, else `"at_plant"` and retry each hour. After delivery the ship heads back to a bay as an inbound ship with no cargo.

- [ ] **Step 1: Write failing tests**
- `test_refusals` (each reason above).
- `test_ice_trip_timing` (distance 1.0, chunk 3000, new ship: 30 + 10 + 45 hours to delivery).
- `test_far_comet_is_slower` (distance 2.0, chunk 1000: 60 + 10 + 70).
- `test_chunk_waits_for_cradle_room` (cradle 2500 of 3000, chunk 1000: `"at_plant"` until ice drops to 2000).
- `test_away_ship_goes_after_unloading`.
- `test_order_cancelled_if_comet_leaves_first` (Review Focus 5): order on a ship with 30 hours of trip left when the comet has 10 hours of reach; when it docks, `ice_order == 0` and it resumes its assignment.
- `test_chunk_still_comes_home_after_comet_leaves` (ship carving when `leaves` passes still delivers).
- `test_assignment_resumes_after_ice`.

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** ice states, `fetch_ice`, cradle.
- [ ] **Step 4: Run** all sim tests — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add comet ice trips and the cradle"`

---

### Task 9: Refinery, factory and assembly

**Files:**
- Create: `game/sim/production.gd`
- Modify: `game/sim/game_state.gd` (owns `production`; actions `queue_item`, `remove_queued`; steps production after power, before fleet)
- Test: `test/sim/test_production.gd`

**Interfaces:**
- Produces: `class_name Production extends RefCounted`: `func _init(balance: Dictionary)`, `var queues: Dictionary` (`"factory"`/`"assembly"` → `Array[String]`), `var current: Dictionary` (building → `{"item": String, "hours_left": float, "ship_id": int}` or `{}`), `func refine(speed: float, storage: Storage, stock: Stock) -> void`, `func work(building: String, speed: float, stock: Stock) -> String` (returns the item finished this hour or `""`), `func add_repair(ship_id: int)` (inserts `ship_repair` at the front of the assembly queue).
- `GameState.queue_item(building: String, item: String) -> String` refusals: `"<building> can't make that"` (unknown item, or `ship_repair`, which only comes from `request_repair`); `GameState.remove_queued(building: String, index: int)`.
- Finished assembly items: modules (and `junction`) → `assembled[kind] += 1`; `mining_ship` → `fleet.add_ship()` (docked if a bay is free, else holding); `robot` → `robots += 1`; `ship_repair` → that ship's `condition = 1.0`, `repair_requested = false`. Factory items → `stock`.
- A repair job is added when a docked ship has `repair_requested` and none is queued for it.

Rules (spec "Production"):
- Refinery: `rate × speed` u per hour from the metal with the most raw units (`Storage.most_stored`). Magnesium/aluminum need 1 argon per 10 u (fractional argon allowed); if the top metal needs argon and there's none, use the next metal instead.
- Factory and assembly: one job at a time; a job starts only when `Stock.take_all(takes)` succeeds; hours advance by `speed`.

- [ ] **Step 1: Write failing tests**
- `test_refines_most_stored_metal` (iron 10, nickel 4 → after 1 hour stock iron 2, storage iron 8).
- `test_argon_needed_for_aluminum` (aluminum 10, iron 2, no argon → iron refined; with argon 1 → aluminum 2 refined, argon 0.8).
- `test_refinery_off_without_operator` (speed 0 → nothing).
- `test_factory_makes_module_part` (stock iron 3, aluminum 1, silicon 1; queue module_part; after 4 hours `stock.amount("module_part") == 1`).
- `test_job_waits_for_all_inputs` (Review Focus 4): queue module_part with iron 3, silicon 1, no aluminum: nothing taken after 10 hours; assembly queue with its inputs present still finishes a junction meanwhile.
- `test_assembly_builds_module_for_placing` (electrolysis_plant → `assembled["electrolysis_plant"] == 1`, `can_place("electrolysis_plant")`).
- `test_battery_halves_speed` (speed 0.5 → module_part takes 8 hours).
- `test_new_ship_and_robot_join` (mining_ship → 5 ships; robot → 21 robots).
- `test_repair_jumps_queue` (queue habitat, gas_storage; request repair on a docked ship → assembly queue starts `ship_repair`; afterwards condition 1.0).
- `test_queue_refusals`.

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement `Production`** and the `GameState` actions.
- [ ] **Step 4: Run** all sim tests — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add refinery, factory and assembly"`

---

### Task 10: Air, water, the ship's reserve, collapse and the goal

**Files:**
- Create: `game/sim/life_support.gd`
- Modify: `game/sim/game_state.gd` (owns `life`; steps it last; goal check; `summary()`)
- Test: `test/sim/test_life_support.gd`, `test/sim/test_goal.gd`

**Interfaces:**
- Produces: `class_name LifeSupport extends RefCounted`: `func _init(balance: Dictionary)`, `var reserve: float` (person-hours, starts 12000), `var on_platform := 0`, `var dependent := 0`, `func step(state: GameState) -> String` (`"air_water"` on collapse, else `""`), `func reserve_hours(crew: int) -> float`.
- `GameState.first_all_on_platform_hour := -1`, `GameState.summary() -> Dictionary` with keys `outcome`, `reason`, `hours`, `reserve_hours_left`, `first_all_on_platform_hour`.

Rules (spec "Air and water", "End of a run"):
- Beds = 20 × running habitats. Plant places = 32 × running electrolysis plants. Supplied = min(crew, beds, plant places, floor(cradle_ice × 12), floor(nitrogen × 100)).
- Each hour: `cradle_ice -= on_platform / 12`, nitrogen `-= on_platform / 100`, `reserve -= dependent`.
- Collapse `"air_water"` when reserve ≤ 0 and dependent > 0.
- Goal: when `comets.ended_at(hour)` is pass index ≥ 1 (the second pass or later) and `dependent == 0`, `outcome = "won"`.
- `end_run()` sets `outcome = "ended"`.

- [ ] **Step 1: Write failing tests**
- `test_everyone_depends_on_ship_at_start` (reserve drops by 12 per hour).
- `test_plant_and_habitat_take_everyone` (built plant + habitat, cradle 3000, nitrogen 60 → `on_platform == 12`, reserve unchanged, ice −1 per hour, nitrogen −0.12 per hour).
- `test_beds_limit` (no habitat → on_platform 0).
- `test_no_ice_no_supply` (cradle 0 → dependent 12).
- `test_nitrogen_limits_supply` (plant and habitat built, cradle 3000, nitrogen 0.05 → on_platform 5, dependent 7).
- `test_reserve_runs_out` (reserve 24, everyone dependent → collapsed after 2 steps, reason `"air_water"`).
- `test_goal.gd`: `test_win_at_second_comet` (set passes so `passes[1].leaves == hour + 1`, everyone on platform → `outcome == "won"`); `test_no_win_at_first_comet`; `test_later_comet_can_still_win` (dependent at pass 1's end, on platform at pass 2's end → won); `test_summary_fields` (after `end_run`: outcome `"ended"`, `hours`, `reserve_hours_left == reserve / 12`, `first_all_on_platform_hour` recorded the first hour dependent hit 0).

- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement `LifeSupport`**, goal and `summary()`.
- [ ] **Step 4: Run** all sim tests — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add life support, collapse and survival goal"`

---

### Task 11: Alerts and checklist

**Files:**
- Create: `game/sim/advisor.gd`
- Test: `test/sim/test_advisor.gd`

**Interfaces:**
- Produces: `class_name Advisor`: `static func alerts(state: GameState) -> Array[Dictionary]` (each `{"id": String, "text": String}`), `static func checklist(state: GameState) -> Array[Dictionary]` (each `{"id", "text", "done": bool}`).
- Alert ids and texts: `storage_full` "Storage is full", `ships_waiting` "<n> ships waiting to unload", `power_short` "Not enough power", `comet_forecast` "Comet arrives in <h> hours", `comet_in_reach` "Comet in reach for <h> hours", `reserve_low` "Ship's reserve: <h> hours left" (under 200), `fuel_low` "Fuel: <h> hours left" (under 200, only once a generator is built), `no_operator` "<n> modules have no operator".
- Checklist, in order: `core` "Set up the dock, storage and generator"; `metals` "Send ships to mine metals"; `industry` "Set up the refinery, factory and assembly"; `plant` "Build an electrolysis plant"; `ice` "Fetch comet ice"; `habitat` "Build a habitat". Done when built / any ship assigned to asteroids / `ice_delivered`.

- [ ] **Step 1: Write failing tests** — one test per alert raising and clearing, and `test_checklist_order_and_done` on the starter platform (first item done after `finish_construction`, `metals` done after an asteroid assignment).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement `Advisor`.**
- [ ] **Step 4: Run** all sim tests — Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "Add alerts and checklist"`

---

### Task 12: Main scene and sim driver

**Files:**
- Create: `game/main.tscn`, `game/game.gd`
- Modify: `project.godot` (`run/main_scene="res://game/main.tscn"`)
- Test: `test/sim/test_full_run.gd` (sim-only smoke test)

**Interfaces:**
- Consumes: `GameState`, `SimClock`, `Balance`.
- Produces: `game.gd` on the root `Game` node: `var state: GameState`, `var clock: SimClock`, `signal stepped`, `func set_speed(speed: String)`; `_process` calls `state.step()` `clock.advance(delta)` times and emits `stepped`. Space/`P` toggles pause, `1` normal, `2` fast (ignored while a text field has focus).
- `main.tscn`: copies the environment, sun, camera rig, camera and nebula backdrop from `design/space/space_setting.tscn`; `AsteroidField` at (-636, 0, -636); `Comet` (hidden; shown by Task 15); `ArrivalShip` (`design/ships/arrival_ship.gd`) at the balance's arrival position (x, 0, z), turned so the bow points away from the build area; empty `PlatformView`, `FleetView` and a `UI` CanvasLayer for later tasks.

- [ ] **Step 1: Write failing test** `test_full_run.gd::test_scripted_run_reaches_goal`: with seed 1, place the starter layout, assign ships (2 to iron+aluminum, 1 to silicon+platinum, 1 to nitrogen+argon+hydrogen), queue module parts and the plant and habitat, place them when assembled (plant from metal_storage port 3 run 3; habitat from gas_storage port 1 run 2), fetch a 3000 u chunk with one ship when the first comet is in reach, and step until `outcome != ""` or 4000 hours. Assert `outcome == "won"`. (If it can't win with the starting numbers, fix the balance numbers rather than the test, and note the change in the commit.)
- [ ] **Step 2: Run** — Expected: FAIL until all sim pieces agree; fix wiring bugs found here in the owning files.
- [ ] **Step 3: Build `main.tscn` and `game.gd`.**
- [ ] **Step 4: Run** `godot --headless --path . --quit-after 300 res://game/main.tscn 2>&1 | grep -iE "error|warning"` — Expected: no output. And all GUT tests pass.
- [ ] **Step 5: Commit** — `git commit -m "Add main scene and sim driver"`

---

### Task 13: Platform view

**Files:**
- Create: `game/view/platform_view.gd`, `game/view/placeholder_module.gd`
- Modify: `game/main.tscn`

**Interfaces:**
- Consumes: `GameState.layout`, `GameState.construction.progress()`, `GameState.cradle_ice`, `GameState.cradle_capacity()`.
- Produces: `PlatformView.node_visual(id: int) -> Node3D` (for picking and panels), `func world_position(center: Vector2) -> Vector3` (= `Vector3(center.x, 0, center.y)`).
- Kind → script: `command_module.gd`, `ship_dock.gd` (`demo_cycle = false`), `fusion_generator.gd`, `refinery.gd`, `gas_storage.gd`, `metal_storage.gd`, `electrolysis_plant.gd`, `habitat_module.gd`, `reinforcing_junction.gd`; factory and assembly use `placeholder_module.gd` (extends `module_base.gd`; factory band `#5b8def` with a sawtooth-ish box, assembly band `#9b6bd6` with an open gantry box).
- Frame pieces: piece i of a run from node A along direction d starts at `A.center + d × (A.size / 2 + 15 × i)`; rotation about Y: port 0 → 0, port 1 → -PI/2, port 2 → PI, port 3 → PI/2 (matches `space_setting.tscn`).
- Under construction: set `transparency = 0.6` on every `GeometryInstance3D` under the node's visual, plus a `Label3D` showing progress percent; restore when built.
- Each electrolysis plant gets an `ice_chunk.gd` child at y = -6, hidden at 0 ice, scaled by `pow(share_of_cradle_ice, 1.0 / 3.0)`.

- [ ] **Step 1: Implement** the view (adds and updates visuals as nodes appear; never rebuilds existing ones every frame).
- [ ] **Step 2: Verify** with a temporary debug key (removed before commit) or the full-run script: load `main.tscn`, place the starter layout from code, screenshot with the render tool or `--write-movie` to a scratch folder, and check modules, frames, ghosts and an ice chunk appear in the right places.
- [ ] **Step 3: Run** the headless load check from Task 12 — Expected: no errors.
- [ ] **Step 4: Commit** — `git commit -m "Add platform view"`

---

### Task 14: Build menu and placement

**Files:**
- Create: `game/ui/build_menu.gd` (+ `.tscn`), `game/view/placement_tool.gd`
- Modify: `game/main.tscn`

**Interfaces:**
- Consumes: `GameState.kits`, `assembled`, `can_place`, `layout.check_placement`, `layout.new_center`, `layout.check_first`, `place`, `place_first`.
- Produces: `BuildMenu` signal `item_chosen(kind: String)`; `PlacementTool.start(kind)`, `cancel()`, signal `placed`.
- Behavior (spec "Placing"): ray from the camera to the y = 0 plane; nearest built or planned node within its size + 40 m picks the port whose direction is closest to the cursor; mouse wheel or keys 1–3 change the run (number keys go to the tool while placing, not to game speed); preview = translucent model + frame pieces, green when `check_placement` is `""`, red otherwise with the reason in a label; click places; Escape or right click cancels. With no nodes yet, the preview follows the cursor and uses `check_first`.
- Build menu lists kits and assembled modules with counts, plus junctions when available; greyed when count is 0.

- [ ] **Step 1: Implement** menu and tool.
- [ ] **Step 2: Verify** in the running game (`godot --path .`) that a dock placed 2 pieces out shows red with "Too close to the command" and 3 pieces shows green and places.
- [ ] **Step 3: Run** headless load check and GUT — Expected: clean.
- [ ] **Step 4: Commit** — `git commit -m "Add build menu and placement preview"`

---

### Task 15: Fleet view

**Files:**
- Create: `game/view/fleet_view.gd`
- Modify: `game/main.tscn`

**Interfaces:**
- Consumes: `Fleet.ships` (`state`, `hours_left`, `hours_total`, `destination`, `bay`), `PlatformView.node_visual()`, `Comets.current()`.
- Behavior (spec "Visuals"): one `robot_ship.gd` per ship. Docked: on its bay pad inside the dock. Outbound/inbound: flies along a line between the dock door and the destination (nebula point (900, 40, 500), the asteroid field, the comet node), position from `1 − hours_left / hours_total` plus the sub-hour fraction from the clock; fades out over the middle 60% of the leg. Working/carving: hidden. Holding: circles 80 m outside the dock. Towing: an `ice_chunk.gd` scaled to the chunk follows behind. Doors: `open_door(bay)` from one hour before arriving until one hour after leaving, else `close_door(bay)`. The comet node is visible only while a pass is in reach.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify** with the scripted run at fast speed: ships leave the bays, doors open and close, ships return. Capture frames to a scratch folder.
- [ ] **Step 3: Run** headless load check and GUT — Expected: clean.
- [ ] **Step 4: Commit** — `git commit -m "Add fleet view"`

---

### Task 16: Top bar, alerts and checklist

**Files:**
- Create: `game/ui/hud.tscn`, `game/ui/hud.gd`
- Modify: `game/main.tscn`

**Interfaces:**
- Consumes: `Game.stepped`, `Game.set_speed`, `GameState` fields, `Power.supply_mw/demand_mw/fuel_hours_left()`, `LifeSupport.on_platform/reserve_hours()`, `Advisor.alerts/checklist`.
- Behavior (spec "Top bar"): day and hour (`Day 3, 14:00` from `hour`), pause/normal/fast buttons, power "supply / demand MW", fuel hours, "On platform n / 12" and ship reserve hours, cradle ice u, crew, free robots (`robots − construction.robots_busy()`), frame pieces. Side panel: alerts and checklist with done items ticked. Style follows the canvas Game screen mockup (dark panels, Space Grotesk-like font if bundled, else the default).

- [ ] **Step 1: Implement**, updating on `stepped` (not every frame).
- [ ] **Step 2: Verify** values change as the scripted run advances.
- [ ] **Step 3: Run** headless load check and GUT — Expected: clean.
- [ ] **Step 4: Commit** — `git commit -m "Add top bar, alerts and checklist"`

---

### Task 17: Module panel and queues

**Files:**
- Create: `game/ui/module_panel.gd` (+ `.tscn`)
- Modify: `game/main.tscn`, `game/view/platform_view.gd` (click picking)

**Interfaces:**
- Consumes: `GameState.is_running`, `Power.operated/powered/on_battery`, `Storage`, `Production.queues/current`, `queue_item`, `remove_queued`, `cradle_ice`.
- Behavior (spec "Module panel"): status text, one of "Under construction n%", "No operator", "No power", "On battery", "Running"; takes in / puts out lines from a small per-kind table in the script; storage contents with bars; factory/assembly: current job with progress, queue list with remove buttons, add buttons for each recipe (refusal reason shown inline); plant: cradle ice and supply count.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify** queueing a module part from the panel and watching it finish.
- [ ] **Step 3: Run** headless load check and GUT — Expected: clean.
- [ ] **Step 4: Commit** — `git commit -m "Add module panel and production queues"`

---

### Task 18: Ship popup

**Files:**
- Create: `game/ui/ship_popup.gd` (+ `.tscn`), a fleet list in the HUD side panel
- Modify: `game/main.tscn`, `game/view/fleet_view.gd` (click picking)

**Interfaces:**
- Consumes: `MiningShip` fields, `assign_ship`, `fetch_ice`, `request_repair`, `Comets.current()`.
- Behavior (spec "Ship popup"): site toggle (nebula/asteroids), material checkboxes limited to 3 gases or 2 metals, Apply (shows refusal reason), condition percent, cargo, trip state and hours left, "Fetch ice" with 1,000/2,000/3,000 choices enabled only while a comet is in reach, "Repair" button. Follows the canvas Ship management popup mockup.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify** assigning, ice fetching during a pass and a repair.
- [ ] **Step 3: Run** headless load check and GUT — Expected: clean.
- [ ] **Step 4: Commit** — `git commit -m "Add ship popup"`

---

### Task 19: End screen and menu

**Files:**
- Create: `game/ui/end_screen.gd` (+ `.tscn`)
- Modify: `game/ui/hud.gd` (menu button with "End run"), `game/game.gd` (restart)

**Interfaces:**
- Consumes: `GameState.outcome`, `summary()`, `end_run()`.
- Behavior (spec "End of a run"): when `outcome` is set, pause and show: "Platform held" (won), "Collapse: energy ran out" / "Collapse: oxygen and water ran out", or "Run ended"; hours operated; ship reserve left in hours; hour the whole crew was first on the platform (or "never"); a "New run" button that builds a fresh `GameState` with a new seed and reloads the views.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Verify** each outcome (set state directly in a debug build or via the scripted run).
- [ ] **Step 3: Run** headless load check and GUT — Expected: clean.
- [ ] **Step 4: Commit** — `git commit -m "Add end screen and new run"`

---

### Task 20: Arrival ship parts and a full play check

**Files:**
- Modify: `design/ships/arrival_ship.gd` (export `var bases_present := [true, true, true, true]` and `var frame_bundles_present := 8`, rebuild on change), `game/game.gd` or `platform_view.gd` (set them from state)

**Interfaces:**
- Consumes: `GameState.kits` (a midsection base is gone once its kit is placed: command → top, gas storage → right, fusion generator → bottom, metal storage → left, matching `BASES` order), frame pieces used from the starting 32 (one bundle per 4).

- [ ] **Step 1: Implement** the two exports in `arrival_ship.gd` without changing its look when all are present; render with the existing `renders_logo/jobs.json`-style job to confirm unchanged.
- [ ] **Step 2: Play** a full run at fast speed by hand: set up the kits, mine, build the plant and habitat, fetch ice, reach the second comet. Note anything confusing or broken, and the frame rate at both speeds.
- [ ] **Step 3: Run** all GUT tests and the headless load check — Expected: clean.
- [ ] **Step 4: Commit** — `git commit -m "Remove arrival ship parts as they're used"`
- [ ] **Step 5: Report** the play notes to the owner and ask before pushing the `prototype` branch.
