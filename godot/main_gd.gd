extends Node

# --- Configuration ---
@export var agent_scene: PackedScene # Assign Agent.tscn in the Inspector
@export var agent_count: int = 500  # Number of agents to spawn
@export var interaction_radius: float = 50.0 # Distance within which agents interact
@export var separation_strength: float = 5000.0 # How strongly agents repel each other

# --- Nodes ---
@onready var agent_container: Node2D = $AgentContainer
@onready var info_label: Label = $CanvasLayer/InfoLabel

# --- State ---
var agents: Array[Node2D] = [] # Holds references to all agent nodes
var screen_size: Vector2
# We need a way to store the calculated forces for each agent before applying them
var forces_to_apply = {} # Dictionary: Agent Node -> Accumulated Force Vector

# --- Performance Measurement ---
var calculation_times: Array[float] = [] # Store recent frame calculation times (microseconds)
const TIME_SAMPLES: int = 60 # Number of frames to average calculation time over
var lowest_fps:float = 0.0
var highest_fps:float = 0.0

func _ready() -> void:
	if not agent_scene:
		printerr("Agent scene not assigned in Main.gd!")
		return
	
	screen_size = get_viewport().size
	print("Screen Size: ", screen_size)
	print("Spawning ", agent_count, " agents...")

	# Pre-allocate array size for minor optimization
	agents.resize(agent_count)

	for i in range(agent_count):
		var agent_instance = agent_scene.instantiate() as Node2D
		if agent_instance:
			# Set random initial position
			agent_instance.global_position = Vector2(
				randf_range(0, screen_size.x),
				randf_range(0, screen_size.y)
			)
			# Set random initial velocity (optional)
			if agent_instance.has_method("apply_separation_force"): # Check if Agent.gd is correctly set up
				var initial_velocity = Vector2(randf_range(-50, 50), randf_range(-50, 50))
				agent_instance.set("velocity", initial_velocity) # Directly set initial velocity
				agent_instance.set("screen_size", screen_size) # Pass screen size to agent

			agent_container.add_child(agent_instance)
			agents[i] = agent_instance # Store reference
		else:
			printerr("Failed to instantiate agent scene.")
			return

	print("Spawning complete.")


func _physics_process(delta: float) -> void:
	if agents.is_empty():
		return

	# --- Performance Measurement Start ---
	var start_time_usec = Time.get_ticks_usec()

	# --- Core Calculation Loop (O(N^2)) ---
	for i in range(agents.size()):
		var agent_i = agents[i]
		if not is_instance_valid(agent_i): continue # Safety check

		var total_separation_force = Vector2.ZERO

		for j in range(agents.size()):
			# Don't compare an agent with itself
			if i == j:
				continue

			var agent_j = agents[j]
			if not is_instance_valid(agent_j): continue # Safety check

			# Calculate distance (use distance_squared for efficiency)
			var vec_diff = agent_j.global_position - agent_i.global_position
			var dist_sq = vec_diff.length_squared()

			# Check if within interaction radius
			if dist_sq < interaction_radius * interaction_radius and dist_sq > 0.001 : # Avoid division by zero if agents overlap perfectly
				# Calculate normalized direction vector pointing away from agent_j
				# Using vec_diff avoids recalculating the difference vector
				# Dividing by sqrt(dist_sq) normalizes it
				var separation_direction = -vec_diff / sqrt(dist_sq) # Points away from j

				# Force strength increases sharply as agents get closer (inverse relationship)
				# Add 1.0 to avoid extreme forces when distance is very small but non-zero
				var force_magnitude = separation_strength / (sqrt(dist_sq) + 1.0)

				total_separation_force += separation_direction * force_magnitude

		# Store the calculated force for agent_i
		forces_to_apply[agent_i] = total_separation_force

	# --- Performance Measurement End ---
	var end_time_usec = Time.get_ticks_usec()
	var duration_usec = end_time_usec - start_time_usec

	# Store and average the calculation time
	calculation_times.push_back(duration_usec)
	if calculation_times.size() > TIME_SAMPLES:
		calculation_times.pop_front()

	var avg_calc_time_usec = 0.0
	if not calculation_times.is_empty():
		avg_calc_time_usec = calculation_times.reduce(func(accum, val): return accum + val, 0.0) / calculation_times.size()

	# --- Apply Forces (O(N)) ---
	# This part is outside the timed section, as we primarily want to measure the calculation cost.
	for agent in forces_to_apply:
		var force = forces_to_apply[agent]
		# Check if the agent instance is still valid before calling method
		if is_instance_valid(agent) and agent.has_method("apply_separation_force"):
			agent.apply_separation_force(force, delta)

	# --- Update UI ---
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	if (lowest_fps == 0.0 or fps < lowest_fps):
		lowest_fps = fps
	elif (highest_fps == 0.0 or fps > highest_fps):
		highest_fps = fps
	var avg_calc_time_msec = avg_calc_time_usec / 1000.0
	info_label.text = "Agents: %d\nFPS: %d (low: %d, high: %d)\nCalc Time: %.3f ms" % [agent_count, fps, lowest_fps, highest_fps, avg_calc_time_msec]
