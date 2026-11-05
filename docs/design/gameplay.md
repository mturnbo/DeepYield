# Gameplay

How a run starts, what the commander does along the way, and what a successful platform looks like. The commander manages processes rather than reacting every second: enough to keep it interesting, with breathing room to plan ahead.

- **Starting crew:** 12 humans, plus 20 multi-purpose robots and 4 mining ships
- **Game time:** 1 hour = 2 s, a 24-hour day passes in 48 seconds
- **Starting fuel:** 2,880 hours, about 96 minutes of real time
- **Startup loan:** 150,000 cr, to repay to The Big Space Corporation

## How the game starts

*Decided · From arrival to the first freighter*

1. **Arrival.** The arrival ship reaches the nebula. The crew lives aboard, and the ship's own bridge, engine and life support keep everyone running. Those systems are the emergency reserve, so the sooner the platform takes over, the better.
2. **Storage.** The ship's storage containers detach and become the first gas storage and metal storage modules, so everything mined early has a place to go.
3. **Ship kits go up.** Multi-purpose robots set up the kits the ship carries: the ship dock, command module, the platform's fusion generator, refinery, factory and assembly, joined by frame and rails. The game suggests an order.
4. **First mining runs.** Once the dock is up, the 4 mining ships take their first assignments. Only materials with somewhere to go can be mined: at first hydrogen, helium, nitrogen and the seven metals. Each new module unlocks more, for example deuterium once the fusion generator runs.
5. **First real builds.** Assembly turns mined metal into the first modules that aren't kits: the electrolysis plant, which unlocks comet ice runs, then habitats.
6. **Moving off the ship.** The crew moves into habitats. More room and relaxation mean higher morale, the ship's reserves stop draining, and there are beds for new crew.
7. **Open for trade.** Assembly builds a trade port, and once there's the minimum to trade, you call the first freighter. Pirate raids begin after that first visit, so defenses should be in place before you call.

**Decided:** The game suggests what to build first so a new commander gets off to a good start. **Proposed:** the suggestions come from the command computer as a short checklist you can follow or ignore. After the opening, the choices are yours: more storage, more ships, a second dock, defenses, helium-3 storage.

## What the commander does

*The jobs that run through the whole game*

### Mining fleet

- Give each mining ship a standing assignment: up to 3 gases from the nebula, up to 2 metals from the asteroids, or comet ice.
- Change an assignment any time in the ship popup. The ship finishes its current trip first.
- Balance wear and energy. Asteroid runs wear ships fastest, nebula runs less, and comet runs barely, but they use the most energy because the comet is farthest away.
- Keep worn ships repaired. A worn ship is slower and carries less.
- Send a ship to tow home any ship stranded in a raid.
- When long-range sensors spot a contact that might be a pirate, decide whether to order mining ships to hold position. The command computer is only guessing whether it's a pirate or a freighter.

### Building

- Choose what to build next and where it goes on the frame. Frame pieces have a fixed reach before they need a module or junction.
- When storage is full, you get an alert and choose: build more storage, or wait. Ships can't leave the dock until their load is offloaded, and each dock holds 4 ships.
- Spread defenses across the platform. Pirates go for storage first.
- Set the factory and assembly queues. Repairs always jump to the front.

### Crew

- Keep enough humans aboard to fill the schedule. Work, sleep and vacations are scheduled automatically.
- Request new crew from The Big Space Corporation. They arrive on the next freighter, at most 4 per freighter.
- Make room first: each habitat sleeps 20 and each electrolysis plant supplies 32 people.
- Approve or refuse vacation requests.
- Watch morale: food quality, entertainment variety and time off. Low morale slows production.

### Trade and money

- Call a freighter once the platform has the minimum to trade. Calling when prices are high pays more, but waiting risks full storage and raids.
- Buy food, entertainment, spare parts, robots and materials you can't mine yet from what the freighter has on board.
- Pay salaries and the crew's profit share.
- Make the loan's minimum payment and choose how much extra to pay. Paying faster leaves less for supplies, which can hurt morale and production.

### After a raid

- During a raid you can't act; the defenses you built have to hold.
- Afterward: repair storage modules that lost containers, and any other damage.
- Replace stolen multi-purpose robots, and recover stranded mining ships.
- Absorb the lost revenue.

## Crew and robots

*Decided · Who does what*

### Humans

- Run every module except storage, habitats and the fusion generator. A module with no operator shuts down.
- One operator runs a module at full speed; more don't make it faster. Any human can run any module.
- The first crew lives on the arrival ship, then moves into habitats. New humans need habitat space.
- New crew cost nothing up front, but each one adds a salary.

### Multi-purpose robots

- Do the dangerous work: building modules, frame and rails, and repairs.
- Built at assembly. Need recharging, and repairs only when damaged.
- Pirates may try to steal them.

### Mining ships

- A separate class of robot: autonomous, with no humans or other robots aboard.
- Built at assembly. Need recharging, and wear down from use.
- Always find their way home unless damaged in a raid. A damaged ship is stranded where it was hit until another mining ship tows it home.

## Power, air and water

*Decided · How the platform keeps people alive*

### Life support in every crewed module

- Every module with human operators has its own life support: air, water, heat and artificial gravity.
- The electrolysis plant turns comet ice into water and oxygen, and mixes the oxygen with nitrogen to make air.
- Water and air are delivered in tanks by the rail train cars, not through the frame, which would be too dangerous with pirate attacks.
- A crewed module needs one delivery of water and air per day. That stays manageable as the platform grows, so rail travel time isn't something to manage.
- If pirates damage a stretch of rail, deliveries beyond it stop until robots repair it.

### Power through the frame

- The fusion generators' power reaches every module through the frame.
- Each module has a battery reserve. If frame damage cuts it off from main power, it keeps working in a limited way until power is restored.

**Proposed:** this makes the frame's shape matter. A module at the end of a single frame arm loses power if that one piece is hit, while a loop gives power a second way around.

| What one generator covers | Draw each | Count | Total |
|---|---|---|---|
| Electrolysis plant | 7 MW | 1 | 7 MW |
| Refinery | 7 MW | 1 | 7 MW |
| Ship dock | 6 MW | 1 | 6 MW |
| Factory | 5 MW | 1 | 5 MW |
| Assembly | 5 MW | 1 | 5 MW |
| Habitat | 4 MW | 1 | 4 MW |
| Command | 3 MW | 1 | 3 MW |
| Trade port | 3 MW | 1 | 3 MW |
| Helium-3 storage | 2 MW | 1 | 2 MW |
| Gas storage | 1 MW | 1 | 1 MW |
| Metal storage | 1 MW | 1 | 1 MW |
| Defense junction | 3 MW | 4 | 12 MW |
| Frame piece with rail | 0.1 MW | 40 | 4 MW |
| Reinforcing junction | 0 MW | 20 | 0 MW |
| One generator |   |   | 60 MW |

### Generators and fuel

**Decided:** One fusion generator powers a complete set of modules, one of each kind, plus 4 defense junctions, 40 frame pieces with rail and 20 reinforcing junctions. Storage modules need a little power for their mechanical systems, and the frame needs a little to move the rail cars. Only the reinforcing junction needs none.

**Proposed:** A generator makes 60 MW. It burns 1 u of hydrogen for every 150 MWh it supplies, so a fully loaded generator burns about 40 u every 100 hours. That's roughly what one ship mining only hydrogen brings in, which gives an easy rule of thumb: one hydrogen ship per generator.

**Proposed:** The starter platform draws about 30 MW, half a generator. The kit arrives with a sealed fuel core that runs it for about 2,880 hours. Deuterium makes hydrogen go 25% further.

**Proposed:** On battery, a module keeps its own life support running and works at half speed for about 12 hours.

## Pirates

*Decided*

### Raids

- Raids start only after at least one freighter has come to trade.
- Each raid is 1 to 3 pirate ships, so raids don't escalate until the platform is overwhelmed.
- Main target: the containers on storage modules, stolen with the raw materials inside, sometimes only some of them.
- They may also attack the trade port or try to steal multi-purpose robots.
- Defense junctions carry phased plasma guns that automatically track and fire at anything attacking the platform.
- Well-equipped defenses generally hold them off, but some damage can still happen.

## Being successful

### How a run ends

**Decided:**

- Collapse: the materials for oxygen, water or energy run out. The crew evacuates on the arrival ship, sends an emergency beacon and hopes to be rescued, and the game is over. The score is hours operated.
- Sale: you can sell the station at any time. The score is hours operated and the sale price.
- A good run lasts long enough to pay off the startup loan. The proposed numbers put that at about 4 hours of real time.

### What a strong commander does

**Proposed:**

- Gets ice and hydrogen flowing early, since those keep the crew breathing and the lights on.
- Builds habitats and electrolysis plants before requesting crew, and requests crew before falling short.
- Puts defenses up before calling the first freighter, and keeps storage away from the edges.
- Sells on good prices without letting storage fill up.
- Pays above the minimum when morale and supplies allow.
- Leaves the arrival ship's reserves alone. If the platform fails, the ship is how the crew gets out.

## Time and saving

### Pacing

**Decided:**

- One game hour is 2 seconds of real time. A run can end in one sitting.
- A run that's going well can be saved and continued.

### Controls

**Proposed:**

- Pause, normal speed and a faster speed.
- Pausing doesn't block decisions: you can assign ships, queue builds and approve vacations while paused.

## Still open

*Proposed*

### Questions for later

- How morale is measured, and how long vacations last.
- Turret types, and how far a frame piece reaches.
- Whether the refinery pauses when nothing has room for its output.
- The first playable version to build.
