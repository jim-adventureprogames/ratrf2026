# a Mark is an npc that can be bumped by the player and pickpocketed.

class_name MarkComponent
extends AIBehaviorComponent


# Examines the world and picks the best action for this turn.
# Currently: choose a random passable adjacent tile to wander into.
func decideWhatToDo() -> void:
	nextStepTile      = Vector3i(-1, -1, -1)
	nextStepDirection = Vector2i.ZERO

	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return

	var cardinals := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	cardinals.shuffle()

	for dir: Vector2i in cardinals:
		var target := mover.resolveTargetWorldPosition(dir)
		if target.z < 0:
			continue
		nextStepTile      = target
		nextStepDirection = dir
		return
