class_name AIBehaviorComponent
extends EntityComponent

enum EBehaviorFlags
{
	wander 					= 0,
	moving_to_goal_position	= 1 << 0,
	observing				= 1 << 1,
	chasing_entity			= 1 << 2,
	fleeing_entity			= 1 << 3,
	guarding_zone			= 1 << 4,
	guarding_location		= 1 << 5,
	following_entity		= 1 << 6,
	returning_to_zone		= 1 << 7,
}

# Action points available this turn.  Each successful action costs 1 AP.
# Restored by 1 in onEndOfTurn so entities with more AP can act multiple
# times per turn and gradually recover if something drains extra AP.
@export var actionPoints: int = 1

# The tile this AI has decided to move to this turn.
var nextStepTile:      Vector3i = Vector3i(-1, -1, -1)

# Direction leading to nextStepTile — passed directly to tryMove.
var nextStepDirection: Vector2i = Vector2i.ZERO

# Active state — holds name, flags, and any per-state payload data.
var currentState: BehaviorState = BehaviorState.new(&"default", 0)

# State history stack.  pushState saves currentState; popState restores it.
var _stateStack: Array[BehaviorState] = []

# Property shim so existing `behaviorFlags` reads/writes keep working unchanged.
var behaviorFlags: int:
	get: return currentState.flags
	set(v): currentState.flags = v


# Saves currentState and switches to newState.
func pushState(newState: BehaviorState) -> void:
	_stateStack.push_back(currentState)
	currentState = newState


# Restores the most recently pushed state.
func popState() -> void:
	if _stateStack.is_empty():
		push_warning("%s: popState called on empty stack" % entity.name)
		return
	currentState = _stateStack.pop_back()


# Called by GameManager each frame while this AI is pending.
# Returns true when done for the turn (no AP left or nothing to do).
func takeAction() -> bool:
	if actionPoints <= 0:
		return true

	decideWhatToDo()

	if nextStepDirection == Vector2i.ZERO:
		actionPoints -= 1  # idle is still a decision — costs 1 AP
		return actionPoints <= 0

	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		# If the intended tile is blocked, reroute via A* — unless the block IS
		# our intended target entity, in which case we walk into it on purpose
		# (e.g. guard stepping onto the player's tile to trigger apprehension).
		# Only reroutes within the same zone; cross-zone steps aim at zone
		# boundaries which are always open.
		if nextStepTile.z == entity.worldPosition.z \
				and nextStepTile != Vector3i(-1, -1, -1):
			var moveResult := MapManager.testDestinationTile(nextStepTile, mover.bCanBumpThings)
			if moveResult == Globals.EMoveTestResult.Wall \
					or moveResult == Globals.EMoveTestResult.Entity \
					or moveResult == Globals.EMoveTestResult.Bumpable :
				var bIsIntendedTarget := false
				var targetEnt         := getTargetEntity()
				if targetEnt != null and targetEnt.worldPosition == nextStepTile:
					bIsIntendedTarget = true
				if not bIsIntendedTarget and targetEnt != null:
					var detourDir := _computeDetourToward(Vector2i(targetEnt.worldPosition.x, targetEnt.worldPosition.y))
					if detourDir != Vector2i.ZERO:
						nextStepDirection = detourDir
						nextStepTile      = mover.resolveTargetWorldPosition(detourDir)
					else:
						# A* found no path around the obstacle — idle this turn
						# rather than repeatedly bumping into the wall.
						nextStepDirection = Vector2i.ZERO
				elif not bIsIntendedTarget:
					#we don't have a goal entity to reach, and our next step is blocked.
					#so we do nothing.
					nextStepDirection = Vector2i.ZERO
					
		mover.tryMove(nextStepDirection)
		actionPoints -= 1

	nextStepTile      = Vector3i(-1, -1, -1)
	nextStepDirection = Vector2i.ZERO

	return actionPoints <= 0


# Uses the zone A* graph to find a one-step detour from this entity's current
# tile toward targetTile.  Temporarily unblocks both endpoints so A* can route
# even when the entity or its destination sits on a solid point.
# Returns Vector2i.ZERO when no path exists.
func _computeDetourToward(targetTile: Vector2i) -> Vector2i:
	var zone := MapManager.getZone(entity.worldPosition.z)
	if zone == null or zone.astar == null:
		return Vector2i.ZERO
	var fromPos := Vector2i(entity.worldPosition.x, entity.worldPosition.y)
	if fromPos == targetTile:
		return Vector2i.ZERO

	var bFromSolid := zone.astar.is_point_solid(fromPos)
	var bToSolid   := zone.astar.is_point_solid(targetTile)
	zone.astar.set_point_solid(fromPos,   false)
	zone.astar.set_point_solid(targetTile, false)
	var rawPath := zone.astar.get_point_path(fromPos, targetTile)
	zone.astar.set_point_solid(fromPos,   bFromSolid)
	zone.astar.set_point_solid(targetTile, bToSolid)

	if rawPath.size() < 2:
		return Vector2i.ZERO
	var nextTile := Vector2i(int(rawPath[1].x), int(rawPath[1].y))
	return nextTile - fromPos


# Called by GameManager at the end of every turn.
func onEndOfTurn() -> void:
	actionPoints += 1


# Returns the entity this AI is actively trying to reach or interact with,
# or null if there is no such target.  Override in subclasses so takeAction()
# can skip rerouting when the blocked tile is the intended destination.
func getTargetEntity() -> Entity:
	return null


# Examines the world and picks the best action for this turn.
# Currently: choose a random passable adjacent tile to wander into.
func decideWhatToDo() -> void:
	return


func onDebugPrint() -> void:
	print("  [%s] actionPoints: %d" % [get_script().get_global_name(), actionPoints])
	print("    state: %s  flags: %s  data: %s" % [
		currentState.stateName,
		_flagsToString(currentState.flags),
		str(currentState.data)
	])
	for i in _stateStack.size():
		var s: BehaviorState = _stateStack[_stateStack.size() - 1 - i]
		print("    stack[%d]: %s  flags: %s  data: %s" % [
			i, s.stateName, _flagsToString(s.flags), str(s.data)
		])


func _flagsToString(flags: int) -> String:
	if flags == EBehaviorFlags.wander:
		return "wander"
	var parts: Array[String] = []
	if flags & EBehaviorFlags.moving_to_goal_position: parts.append("moving_to_goal")
	if flags & EBehaviorFlags.observing:               parts.append("observing")
	if flags & EBehaviorFlags.chasing_entity:          parts.append("chasing")
	if flags & EBehaviorFlags.fleeing_entity:          parts.append("fleeing")
	if flags & EBehaviorFlags.guarding_zone:           parts.append("guarding_zone")
	if flags & EBehaviorFlags.guarding_location:       parts.append("guarding_location")
	if flags & EBehaviorFlags.following_entity:        parts.append("following")
	if flags & EBehaviorFlags.returning_to_zone:       parts.append("returning")
	return "|".join(parts) if not parts.is_empty() else "0x%x" % flags
