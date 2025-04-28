# Simulation Performance Comparison

Comparing between GDScript vs Nim

## Use Case: N-Body Proximity Simulation

### Concept
Simulate a large number of simple "agents" (particles, boids, units, etc.) moving in a 2D space. The core computational task will be for each agent to check its distance to every other agent. If two agents are within a certain "interaction radius", we'll perform a simple calculation (e.g., apply a repulsive force to simulate basic collision avoidance or separation).

### Why this use case?
- **CPU-Bound:** The primary workload is calculation (distance checks, vector math), not rendering or I/O. This is where compiled languages like Nim often excel over interpreted ones like GDScript.
- **Scalability Test:** The computational complexity is O(N^2) where N is the number of agents (each of N agents checks against N-1 other agents). This makes performance differences very apparent as N increases.
- **Relevant:** Many simulation/sandbox elements involve proximity checks: collision detection (basic), flocking behaviour (separation, alignment, cohesion), area-of-effect triggers, sensor ranges, social interactions, etc.
- **Measurable:** We can easily measure the time taken to complete one full update cycle for all agents.

### Goal
Measure the time (in milliseconds or microseconds) required to perform the proximity checks and associated calculations for all agents within a single frame (_physics_process) and also monitor the overall FPS.

### Components:
Each version have 2 scenes:
1. **Agent**: Represents a single agent. It will handle its own movement based on velocity.
   1. GDScript: `agent_gd.tscn` and `agent_gd.gd`
   2. Nim: `agent_nim.tscn` and `gdagentnim.nim`
2. **Main**: Spawns and manages all agents. It will contain the core N^2 calculation loop and measure its performance.
   1. GScript: `main_gd.tscn` and `main_gd.gd`
   2. Nim: `main_nim.tscn` and `gdmainnim.nim`

### Setup:
The Nim implementation uses [gdext-nim](https://github.com/godot-nim/gdext-nim), the GDExtension for Nim. 

To build the Nim version, just run:
```
gdextwiz build
```

Then open Godot 4.4 and play the `main_gd.tscn` or `main_nim.tscn` scene.


### Results:
In my Linux machine (*I'm using AMD Ryzen 7 2700X Eight-Core Processor*):

- Running 180 agents:
  - GDScript: highest FPS is 30, but average is 7
  - Nim: highest FPS is 60, but average is 55
- Running 190 agents:
  - GDScript: highest FPS is 11, but average is 6
  - Nim: highest FPS is 15, but average is 7

So there is a slight advantage to Nim over GDScript on 180 agents, but adding 10 more agents the performance are similar.

There might be some optimizations that can be done on both ends and the results may vary.

#### Update 2025/04/28:
Thanks to [panno8M](https://github.com/panno8M), there are massive updates on optimization, with these 3 changes:
1. Update compile options for speed
2. Replaced Dictionary with Sequence
3. Calling physics_process of AgentNim from MainNim

The Nim version are able to run even to 600 agents with no significant FPS drop (average 50 FPS). While running 650 agents caused the FPS to drop to 11 (although still running well in my opinion)