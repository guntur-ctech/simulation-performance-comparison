import gdext
import gdext/classes/gdNode2D

type AgentNim* {.gdsync.} = ptr object of Node2D
  velocity*: Vector[2,float32]
  max_speed: float32 = 150.0
  damping: float32 = 0.1 # Slows down agents over time if no force applied
  screen_size*: Vector2

# method physics_process(self: AgentNim; delta: float64) {.gdsync.} = 
# Calling physics_process manually
proc physics_process*(self: AgentNim; delta: float64) = 
  # Apply damping
  self.velocity = self.velocity * (1.0 - self.damping * float32 delta)
  
  # Update global position based on velocity
  self.position = self.position + (self.velocity * float32 delta)

  # Screen wrapping (optional, but keeps agents in view)
  if self.screen_size != Vector2.Zero: # Check against zero vector
    self.position = vector(wrapf(self.position.x, 0.0, self.screen_size.x), wrapf(self.position.y, 0.0, self.screen_size.y))
  
  # Rotate towards the velocity direction
  if self.velocity.lengthSquared() > 0.001: # Use lengthSquared for efficiency
    self.rotation = self.velocity.angle() # Set rotation based on velocity angle

proc applySeparationForce*(self: AgentNim; force: Vector2; delta: float64) {.gdsync, name:"apply_separation_force".} =
  # Simple acceleration model: velocity change is proportional to force
  self.velocity = self.velocity + (force * float32 delta)
  # Clamp velocity to max speed
  self.velocity = self.velocity.limitLength(self.max_speed)
  # print "Applying force: ", $(force)