extends Node2D

var velocity: Vector2 = Vector2.ZERO
var max_speed: float = 150.0
var damping: float = 0.1 # Slows down agents over time if no force applied

var screen_size: Vector2 # Will be set by Main.gd

func _physics_process(delta: float) -> void:
	# Apply damping
	velocity *= (1.0 - damping * delta)
	
	# Update position based on velocity
	global_position += velocity * delta
	
	# Screen wrapping (optional, but keeps agents in view)
	if screen_size != Vector2.ZERO:
		global_position.x = wrapf(global_position.x, 0, screen_size.x)
		global_position.y = wrapf(global_position.y, 0, screen_size.y)

# Function called by Main.gd to apply the calculated force/velocity change
func apply_separation_force(force: Vector2, delta: float) -> void:
	# Simple acceleration model: velocity change is proportional to force
	velocity += force * delta
	# Clamp velocity to max speed
	velocity = velocity.limit_length(max_speed)
	# Rotate towards the velocity direction
	# Only rotate if the agent is actually moving to avoid NaN or division by zero issues
	if velocity.length_squared() > 0.001: # Use length_squared for efficiency and to avoid sqrt
		# Set the node's rotation to the angle of the velocity vector
		# Assumes the node's forward direction is along the positive X-axis (0 rotation)
		rotation = velocity.angle()
