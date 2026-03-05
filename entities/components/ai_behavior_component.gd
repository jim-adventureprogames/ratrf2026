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
		mover.tryMove(nextStepDirection)
		actionPoints -= 1

	nextStepTile      = Vector3i(-1, -1, -1)
	nextStepDirection = Vector2i.ZERO

	return actionPoints <= 0


# Called by GameManager at the end of every turn.
func onEndOfTurn() -> void:
	actionPoints += 1


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
