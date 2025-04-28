import gdext
import gdext/classes/gdNode
import gdext/classes/gdNode2D
import gdext/classes/gdLabel
import gdext/classes/gdSceneTree
import gdext/classes/gdPackedScene
import gdext/classes/gdTime
import gdext/classes/gdPerformance
import classes/gdAgentNim

type MainNim* {.gdsync.} = ptr object of Node2D
  agent_scene* {.gdexport.}: gdref PackedScene
  agent_count* {.gdexport.}: int32 = 500
  interaction_radius* {.gdexport.}: float32 = 50.0
  separation_strength* {.gdexport.}: float32 = 5000.0
  time_samples*: int32 = 60
  AgentContainer: Node2D
  InfoLabel: Label
  agents: seq[AgentNim]
  forces_to_apply: seq[Vector2]
  screen_size: Vector2
  calculation_times: TypedArray[uint64]
  lowest_fps: float32 = 0.0
  highest_fps: float32 = 0.0

method ready(self: MainNim) {.gdsync.} =
  self.AgentContainer = self/"AgentContainer" as Node2D
  self.InfoLabel = self/"CanvasLayer"/"InfoLabel" as Label

  # if self.agent_scene == nil:
  #   echo "Agent scene not assigned!"
  #   discard

  self.screen_size = self.getViewportRect().size
  print "Screen size: ", self.screen_size
  print "Spawning: ", self.agent_count, " agents"

  # We need a way to store the calculated forces for each agent before applying them
  # self.forces_to_apply = newDictionary() # Dictionary: Agent Node -> Accumulated Force Vector
  self.forces_to_apply.setLen(self.agent_count)
  self.calculation_times = newTypedArray[uint64]()

  for i in 0 ..< self.agent_count:
    let agent_instance:AgentNim = self.agent_scene[].instantiate as AgentNim
    if agent_instance != nil:
      # Set random initial position
      agent_instance.global_position = vector(randfRange(0, self.screen_size.x), randfRange(0, self.screen_size.y))

      # Set random initial velocity (optional)
      if agent_instance.hasMethod("apply_separation_force"):
        let initial_velocity = vector(randfRange(-50, 50), randfRange(-50, 50))
        agent_instance.velocity = initial_velocity
        agent_instance.screen_size = self.screen_size

      self.AgentContainer.add_child(agent_instance)
      self.agents.add(agent_instance)
    else:
      echo "Failed to create agent instance"
      return

proc array_sum(self:MainNim, accum:float32, val:float32): float32 {.gdsync.} = 
  return accum + val

method physics_process(self: MainNim; delta: float64) {.gdsync.} = 
  if self.agents.len == 0:
    echo "Empty agents!"

  # --- Performance Measurement Start ---
  let start_time_usec:uint64 = Time.get_ticks_usec()

  # --- Core Calculation Loop (O(N^2)) ---
  for i in 0 ..< self.agents.len:
    let agent_i = self.agents[i]

    # Update physics process
    agent_i.physics_process(delta)

    # Safety check
    if agent_i == nil:
      continue
    
    var total_separation_force:Vector2 = Vector2.Zero

    for j in 0 ..< self.agents.len:
      # Don't compare an agent with itself
      if i == j:
        continue

      let agent_j = self.agents[j]

      # Safety check
      if agent_j == nil:
        continue

      # Calculate distance (use distance_squared for efficiency)
      let vec_diff:Vector2 = agentj.global_position - agenti.global_position
      let dist_sq:float32 = vec_diff.lengthSquared()

      # Check if within interaction radius
      if dist_sq < self.interaction_radius * self.interaction_radius and dist_sq > 0.001 : # Avoid division by zero if agents overlap perfectly
        # Calculate normalized direction vector pointing away from agent_j
        # Using vec_diff avoids recalculating the difference vector
        # Dividing by sqrt(dist_sq) normalizes it
        let separation_direction:Vector2 = -vec_diff / sqrt(dist_sq) # Points away from j

        # Force strength increases sharply as agents get closer (inverse relationship)
        # Add 1.0 to avoid extreme forces when distance is very small but non-zero
        let force_magnitude:float32 = self.separation_strength / (sqrt(dist_sq) + 1.0)

        total_separation_force = total_separation_force + (separation_direction * force_magnitude)
    
    # Store the calculated force for agent_i
    # discard self.forces_to_apply.set(variant agent_i, variant total_separation_force)
    self.forces_to_apply[i] = total_separation_force

  # --- Performance Measurement End ---
  let end_time_usec:uint64 = Time.get_ticks_usec()
  let duration_usec:uint64 = end_time_usec - start_time_usec

  # Store and average the calculation time
  self.calculation_times.pushBack(duration_usec)
  if self.calculation_times.size() > self.time_samples:
    discard self.calculation_times.popFront()

  var avg_calc_time_usec = 0.0
  if not self.calculation_times.is_empty():
    let reduced_calc_times: float32 = self.calculation_times.reduce(self.callable("array_sum"), variant 0.0).get(float32)
    avg_calc_time_usec = reduced_calc_times  / float32 self.calculation_times.size()
  
  # --- Apply Forces (O(N)) ---
  # This part is outside the timed section, as we primarily want to measure the calculation cost.
  for i, agent in self.agents:
    # Check if the agent instance is still valid before calling method
    if is_instance_valid(variant agent):
    # if is_instance_valid(agent) and agent.has_method("apply_separation_force"):
      # var force:Vector2 = self.forces_to_apply[agent].get(Vector2)
      let force:Vector2 = self.forces_to_apply[i]
      # var agent_nim:AgentNim = agent.get(AgentNim)
      # agent_nim.apply_separation_force(force, delta)
      agent.apply_separation_force(force, delta)

  # --- Update UI ---
  let fps = Performance.get_monitor(Performance_Monitor.timeFps)
  if self.lowest_fps == 0.0 or fps < self.lowest_fps:
    self.lowest_fps = fps
  if self.highest_fps == 0.0 or fps > self.highest_fps:
    self.highest_fps = fps
  let avg_calc_time_msec = avg_calc_time_usec / 1000.0
  # self.InfoLabel.text = "Agents: %d\nFPS: %d\nCalc Time: %.3f ms" % [int32 self.agent_count, int32 fps, int32 avg_calc_time_msec]
  self.InfoLabel.text = "Agents: " & $(self.agent_count) & "\nFPS: " & $(int32 fps) & " (low: " & $(int32 self.lowest_fps) & ", high: " & $(int32 self.highest_fps) & ")\nCalc time: " & $(avg_calc_time_msec) & " ms"
