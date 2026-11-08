# Deep Yield: first playable prototype

Status: draft for approval, 2026-11-07

## Why

Everything built so far is a look: 3D models of most modules, the frame, junctions,
the defense station, the robot mining ship, the arrival ship and the space setting.
None of it plays. The design on the canvas describes a full game with trade, pirates,
crew, morale and a loan, which is too much to build before knowing whether the core
loop is fun.

The prototype answers one question: **is running the platform fun on its own?**
That means the loop of mining, storing, refining, building and keeping the crew alive,
played at the real game speed with real decisions and a real way to fail.

## Goals

- A run starts with the arrival ship parked in the nebula. It's won by keeping the
  whole crew living on the platform through the second comet pass, and lost if the
  platform collapses first.
- The player places the ship's kits on a frame they lay out, assigns the 4 mining
  ships, keeps the factory and assembly queues going, builds an electrolysis plant
  and a habitat, and fetches comet ice before the arrival ship's reserves run out.
- The opening has real pressure: the first comet arrives 400–600 hours in, so the
  plant has to be ready by then.
- All the rules live in a simulation that runs without graphics and is covered by
  tests.
- It uses the models already built, and runs smoothly at normal and fast speed.

## Non-goals (left for later passes)

- Trade: the trade port, freighters, prices, selling, buying supplies.
- Money: credits, salaries, the startup loan, missed payments, selling the station.
- Pirates, raids, defense stations, turrets firing, stranded ships, towing them home.
- Crew beyond the starting 12: requesting crew, vacations, morale, food,
  entertainment.
- Helium-3 storage and the gases that only matter for trade or upgrades: helium-3,
  deuterium, xenon, neon, methane. Helium can be mined and stored but has no use yet.
- Saving and loading, settings, audio, tutorials beyond the checklist.
- Loops in the frame. The platform is a tree, so power and rail always reach every
  module and there's nothing to cut while pirates are out.
- Rail train cars moving on screen. Deliveries are counted, not shown.

## Anti-goals (what would make this a failure even if it works)

- Rules buried in visual scripts, where they can't be tested or tuned.
- Balance numbers scattered through code. Every number below is a first guess and
  must be changeable in one data file.
- A prototype that only works by watching: the player has to make choices that
  matter (what to mine, what to build next, where to put it, when to fetch ice).
- Rebuilding the models. The `design/` scripts are the visuals; the game uses them.

## Constraints

- Godot 4.7, GDScript, the existing project at the repo root.
- One game hour is 2 seconds of real time (decided). Fast speed is 4 times that.
- Tests for every new rule: happy path, limits, and expected failures (from the
  project owner's standing instructions).
- Distances in meters, as in the models: module base 30 m across, junction 10 m,
  frame piece 15 m.

## Decided by the project owner (from the canvas)

These come from the design canvas and the prototype keeps them as they are.

- Starting crew of 12 humans, 20 multi-purpose robots and 4 mining ships.
- The ship's kits: ship dock, command, fusion generator, refinery, factory and
  assembly. Gas storage and metal storage also come off the ship. Robots set them up.
- Modules sit at least 30 m apart. The electrolysis plant and the ship dock sit at
  least 45 m (3 frame pieces) from every other module. The dock joins only one other
  module. A module or junction is needed at least every 3 frame pieces.
- Each module base has four frame ports. Junctions take up to four frame pieces.
- Mining ships carry up to 3 gases from the nebula or up to 2 metals from the
  asteroids per trip. Changing an assignment takes effect after the current trip.
- Each dock holds 4 ships. A ship can't leave until its whole load is unloaded, so
  full storage ties up the dock, and the player gets an alert.
- One container per material: gas storage has hydrogen, helium and nitrogen tanks;
  metal storage has a bin for each of the 7 metals.
- Refined materials go to the factory and assembly, not back to storage.
  Magnesium and aluminum need argon to refine. Argon goes from the dock straight to
  the refinery.
- The factory makes parts, including frame pieces. Assembly builds modules, ships
  and robots from parts, and repairs jump to the front of its queue.
- The fusion generator burns hydrogen; its power reaches every module through the
  frame. Each module has a battery reserve.
- Humans run every module except storage, habitats and the fusion generator. One
  operator runs a module at full speed. A module with no operator shuts down.
- The electrolysis plant turns comet ice into water and oxygen, mixes the oxygen
  with nitrogen into air, and supplies up to 32 people. A habitat sleeps 20.
- The crew lives on the arrival ship until habitats exist; the ship's reserves are
  the emergency supply. Running out of oxygen, water or energy ends the run.
- Comets: no standing ice assignment. When a comet is in reach, the player sends
  ships to carve a chunk of 1,000, 2,000 or 3,000 u and tow it home to a cradle
  under the plant. A cradle holds up to 3,000 u. 12 crew use about 1 u of ice per
  hour. The first comet arrives 400–600 hours in.
- Mining ships are worn by trips (asteroids most, comets least). A worn ship is
  slower and carries less.

## The prototype's rules

Where a rule below isn't on the canvas, it's marked **(my call)**: a starting point
for the prototype, to be confirmed or changed.

### Time

- The simulation advances in steps of one game hour. Visuals move smoothly between
  steps.
- Speeds: paused, normal (2 s per hour), fast (0.5 s per hour). All orders can be
  given while paused.

### The platform layout

- The platform is a set of **nodes** (modules and junctions) joined by straight runs
  of frame pieces. Each node has four ports, facing the four directions along the
  ground plane.
- To build, the player picks a free port on an existing node, a run length of 1–3
  frame pieces, and what goes at the end: a module or a junction. The new node's
  center sits at: half the first node's size + run length × 15 m + half the new
  node's size.
- The first node can go anywhere within 300 m of the arrival ship **(my call)**.
- A placement is refused, with the reason shown, if:
  - the run is longer than 3 pieces;
  - two modules would be closer than 30 m edge to edge (60 m center to center), or
    closer than 45 m (75 m center to center) when either is the plant or the dock;
    this applies to every module on the platform, not just the neighbor;
  - the dock already has its one connection, or the new node would join the dock to
    a second module;
  - the new frame or node would cross or overlap anything already built;
  - it would leave the build area, a 1,200 m square (16 modules at 75 m) **(my call)**;
  - there aren't enough frame pieces in stock.
- New nodes join only the port they were built from, so the frame stays a tree
  **(my call)**.

### Building

- Placing something creates a **construction site**. Robots do the work, counted in
  robot-hours. A job uses up to 4 robots; free robots take jobs in the order they
  were placed **(my call)**.
- Work needed **(my call)**: setting up a kit 120 robot-hours, installing an
  assembled module 80, a junction 16, each frame piece 8.
- The ship carries 32 frame pieces (its 8 bundles of 4). After that, frame pieces
  come from the factory.
- Under construction, a site shows as a see-through version of the model with its
  progress.
- Until the first fusion generator is running, the arrival ship powers the platform,
  up to 20 MW at no cost **(my call)**.

### Crew

- 12 crew. One operator per crewed module, filled automatically in a fixed priority
  order (electrolysis plant, ship dock, refinery, assembly, factory, command)
  **(my call)**. Extra crew are idle.
- No shifts, sleep or morale in the prototype.

### Power

- Supply: 60 MW per running fusion generator.
- Demand: the draw of every running module (from the canvas table) plus 0.1 MW per
  frame piece.
- If demand is more than supply, modules shut down from the bottom of the priority
  list until it fits, and the player gets an alert **(my call: electrolysis plant
  and habitat last)**.
- Fuel: the generator starts with a sealed core worth 2,880 hours at the starter
  platform's draw of about 30 MW (86,400 MWh). When the core is empty it burns
  hydrogen from gas storage, 1 u per 150 MWh.
- With no fuel and no hydrogen, modules run on their batteries for 12 hours at half
  speed, then the run collapses (energy ran out).

### Air and water

- A crew member is **on the platform** when they have a habitat bed and an
  electrolysis plant is supplying them. Otherwise they depend on the arrival ship.
- A running plant supplies up to 32 people. Each hour it uses ice from its cradle
  (1 u per 12 people supplied) and nitrogen from gas storage (1 u per 100
  person-hours **(my call)**). With no ice, no nitrogen, no power or no operator, it
  supplies no one.
- The arrival ship's reserve starts at 12,000 person-hours: 12 crew for 1,000 hours
  **(my call)**. It drains 1 per hour for each crew member who depends on the ship.
- The run collapses when the reserve reaches zero while anyone still depends on it
  (oxygen and water ran out).
- Rail deliveries are counted as made, since the frame is always connected.

### Mining

- The 4 mining ships wait in the arrival ship's cargo bay until the dock is set up,
  then move into its 4 bays with no assignment.
- Storage containers (canvas proposal): a gas tank holds 60 u; a metal bin holds
  30 u. The run starts with one gas storage and one metal storage, both still to be
  set up.
- A ship's standing assignment is either the nebula (up to 3 of hydrogen, helium,
  nitrogen, argon) or the asteroids (up to 2 of the 7 metals).
- A full load is 20 u, split evenly across the assignment. Argon is capped at 1 u
  and platinum at 2 u per trip (canvas); palladium at 3 u. The rest of the hold
  fills with the other materials.
- Trip **(my call)**, chosen so one hydrogen ship brings about 40 u per 100 hours as
  the canvas proposes:
  - nebula: 18 h out, 10 h mining, 18 h back;
  - asteroids: 22 h out, 12 h mining, 22 h back;
  - then about 4 h in the dock to unload and recharge.
- Wear **(my call)**: condition starts at 100%; each trip takes 2% (nebula), 4%
  (asteroids) or 1% (comet). Load is 20 u × condition (rounded down), and travel
  takes up to 50% longer as condition falls to zero.
- The player orders a repair from the ship popup. The ship comes home after its
  current trip and waits in a dock bay, and assembly puts a repair job at the front
  of its queue: 1 module part, 10 hours. The ship then resumes its assignment.
- Docking: a returning ship takes a free bay, or waits in a holding pattern. It
  unloads into storage; argon goes straight to the refinery's supply. If a container
  is full, the ship waits in its bay until there's room, and the player gets an
  alert.

### Comets and ice

- The first comet is forecast from the start and arrives 400–600 hours in. The next
  ones come every 1,500–2,500 hours. Each stays in reach about 200 hours. Each pass
  has a distance from 1.0 (close) to 2.0 (far) **(my call)**.
- While a comet is in reach, the player can send any docked or returning ship to
  fetch a chunk of 1,000, 2,000 or 3,000 u. A docked ship leaves as soon as it's
  unloaded; a ship that's away goes after it gets home. The ice trip replaces its next
  trip, and its standing assignment resumes after.
- Ice trip **(my call)**: 30 h × distance out, 10 h carving, then 30 h × distance ×
  (1 + chunk ÷ 6,000) back. A ship that's away when the comet leaves reach still
  brings its chunk home.
- The chunk goes straight to the plant's cradle, skipping the dock. If the cradle
  can't take the whole chunk (3,000 u at most), the ship waits beside the plant
  until it can **(my call)**.
- The ice chunk model under the plant shrinks as the ice is used.

### Production

- **Refinery** (my call for the rates): turns raw metal from metal storage into
  refined metal at 2 u per hour, taking whichever metal it has the most of first.
  Magnesium and aluminum use 1 u of argon per 10 u refined, and wait if there's none.
  Refined metal goes into one shared stock used by the factory and assembly, with no
  limit.
- **Factory** and **assembly** each work through a queue the player sets, one item
  at a time. An item starts when its inputs are in stock and takes them then.
- Recipes and times, all **(my call)**:

  | Made at | Item | Takes | Hours |
  |---|---|---|---|
  | Factory | Frame piece | 4 iron, 1 nickel | 4 |
  | Factory | Module part | 3 iron, 1 aluminum, 1 silicon | 4 |
  | Assembly | Habitat | 10 parts, 4 silicon | 40 |
  | Assembly | Electrolysis plant | 12 parts, 2 platinum | 50 |
  | Assembly | Gas storage | 6 parts | 24 |
  | Assembly | Metal storage | 8 parts | 30 |
  | Assembly | Fusion generator | 14 parts, 3 palladium | 60 |
  | Assembly | Reinforcing junction | 2 parts | 10 |
  | Assembly | Mining ship | 6 parts, 4 magnesium, 2 silicon | 40 |
  | Assembly | Multi-purpose robot | 2 parts, 2 silicon | 16 |
  | Assembly | Ship repair | 1 part | 10 |

- A finished module waits in stock until the player places it. A finished ship or
  robot joins the fleet.
- Modules shut down without an operator or power, as above.

### The command module

- It does nothing extra in the prototype. Until it's set up, the arrival ship's
  bridge shows the same information **(my call)**.

### Checklist and alerts

- The command computer shows a short suggested order the player can follow or
  ignore: set up the dock, storage and generator; send ships to metals; set up the
  refinery, factory and assembly; build the electrolysis plant; fetch ice; build a
  habitat. Each item ticks off when done.
- Alerts: storage full, ships waiting, power short, comet forecast and in reach,
  ship's reserve low (under 200 hours), fuel low (under 200 hours), no operator for a
  module.

### End of a run

Decided by the project owner: the prototype has a survival goal.

- **Won** when the second comet leaves reach with every crew member on the platform
  (a habitat bed and air and water from a plant). That's about 2,000–3,000 hours in.
- **Lost** on collapse at any time, with the reason shown.
- If the crew isn't all on the platform when the second comet leaves reach, the run
  carries on, and is won if they're all on the platform when a later comet leaves
  reach **(my call)**.
- The player can also end the run from the menu.
- The summary shows the result, hours operated, the arrival ship's reserve left, and
  the hour every crew member was first on the platform.

## Screens and controls

The canvas mockups (Game screen, Module kit, Ship management popup) set the look.

- **Top bar:** game day and hour, speed buttons, power (supply and demand), fuel
  hours left, air and water (who's on the platform, the ship's reserve in hours),
  ice in the cradle, crew, free robots, frame pieces in stock.
- **Build menu:** kits and finished modules ready to place, plus junctions.
- **Placing:** pick an item, point at a free port, change the run length with the
  mouse wheel or 1–3 keys, see the preview green or red with the reason, click to
  place. Escape cancels.
- **Module panel** (click a module): status (running, no operator, no power, on
  battery, under construction), what it takes in and puts out, contents for storage,
  the queue for the factory and assembly, the cradle for the plant.
- **Ship popup** (click a ship or pick from a fleet list): assignment, condition,
  cargo, where it is in its trip, fetch ice (when a comet is in reach), repair.
- **Alerts list** and **checklist**, on the side.
- **Camera:** the existing isometric rig (pan and zoom).

## Visuals

- Modules, junctions, frame pieces, ships, the arrival ship, ice chunks and the space
  setting all use the existing `design/` scripts.
- The factory and assembly have no models yet. They use a plain module base with
  their band color and a simple block on top **(my call)**.
- Ships fly out of the dock bays (the doors already animate) toward the nebula, the
  asteroid field or the comet, and fade out of view while away. They reappear and fly
  back in. Paths don't need to avoid each other.
- When a midsection base becomes a module (command, fusion generator, gas storage,
  metal storage), that base disappears from the arrival ship model. The same goes
  for frame bundles as the ship's frame pieces are used **(my call; nice to have)**.

## How it's put together (for the builder)

- **Simulation** in `game/sim/`: plain GDScript classes (not nodes) holding the whole
  game state and advancing it one hour at a time. Player actions are methods that
  check the rules and return either success or a reason for refusal. A seeded random
  number generator makes runs repeatable.
- **Balance data** in one file under `game/data/`, holding every number marked as a
  guess above.
- **View** in `game/view/` and **UI** in `game/ui/`: scenes that read the state each
  frame and send player actions to the simulation. They never change the state
  directly.
- **Main scene** `game/main.tscn` becomes the project's main scene. The existing
  `design/` scenes stay as they are for viewing models.
- **Tests** with GUT in `test/`, run headless from the command line, covering every
  rule above: placement and spacing, construction, power and fuel, air and water and
  the reserve, mining loads and caps, docking and full storage, wear and repair, the
  refinery and argon, queues, comets and the cradle, and both kinds of collapse.

## What's left to the builder

- Mining destinations' positions in the scene, and how ships fly to them.
- The exact look of construction sites, previews, panels and alerts, following the
  canvas mockups.
- How the state is split into classes, as long as the rules stay out of the visuals.
- How the sim and the frame rate stay in step at fast speed.

## Done looks like

- From a fresh start, a player can set up the kits, mine, build an electrolysis plant
  and a habitat, fetch a chunk of comet ice and get the whole crew onto the platform.
- A player who keeps the crew on the platform through the second comet pass wins.
- A player who ignores the comet, or lets hydrogen run out after the fuel core,
  collapses, with the reason shown.
- All simulation tests pass headless.
- It runs smoothly at both speeds on this Mac.
