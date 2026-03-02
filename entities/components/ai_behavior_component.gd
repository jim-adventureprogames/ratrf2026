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
}

# Action points available this turn.  Each successful action costs 1 AP.
# Restored by 1 in onEndOfTurn so entities with more AP can act multiple
# times per turn and gradually recover if something drains extra AP.
@export var actionPoints: int = 1

# The tile this AI has decided to move to this turn.
var nextStepTile:      Vector3i = Vector3i(-1, -1, -1)

# Direction leading to nextStepTile — passed directly to tryMove.
var nextStepDirection: Vector2i = Vector2i.ZERO

var behaviorFlags: EBehaviorFlags


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
