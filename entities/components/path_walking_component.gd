class_name PathWalkingComponent
extends EntityComponent

# ID of the waypoint currently being navigated toward.  -1 = not started.
var currentWaypointId: int = -1

# A* path as a sequence of tile positions leading to the current waypoint.
var _pathTiles:       Array[Vector2i] = []

# Index of the next tile in _pathTiles to step toward.
var _pathTargetIndex: int = 0


# Sets the starting waypoint and computes the initial A* path to it.
func startAtWaypoint(waypointId: int) -> void:
	currentWaypointId = waypointId
	_computePath()


# Returns the cardinal direction to step this turn, or Vector2i.ZERO if there
# is nothing to do (not started, no reachable path, or no next waypoint).
# Automatically advances to the next waypoint once the current one is reached.
func getNextStepDirection() -> Vector2i:
	if currentWaypointId == -1:
		return Vector2i.ZERO

	var entityPos := Vector2i(entity.worldPosition.x, entity.worldPosition.y)

	# Consume any tiles we've already reached (handles the initial position
	# being rawPath[0], and any drift where the entity skips a step).
	while _pathTargetIndex < _pathTiles.size() \
			and _pathTiles[_pathTargetIndex] == entityPos:
		_pathTargetIndex += 1

	# End of path — arrived at the current waypoint.  Advance to the next one.
	if _pathTargetIndex >= _pathTiles.size():
		_advanceToNextWaypoint()
		if currentWaypointId == -1:
			return Vector2i.ZERO
		# One tail-call to get the first step of the new path.
		return getNextStepDirection()

	var dir := _pathTiles[_pathTargetIndex] - entityPos
	return Vector2i(sign(dir.x), sign(dir.y))


# Follows nextId to the next waypoint in the chain.
# Refuses to cross into a different zone — zone-locked entities stay put.
func _advanceToNextWaypoint() -> void:
	var wp := MapManager.getWaypoint(currentWaypointId)
	if wp == null or wp.nextId == -1:
		currentWaypointId = -1
		return
	var nextWp := MapManager.getWaypoint(wp.nextId)
	if nextWp == null or nextWp.zoneId != entity.worldPosition.z:
		currentWaypointId = -1
		return
	currentWaypointId = wp.nextId
	_computePath()


# Builds the A* path from the entity's current tile to the current waypoint.
func _computePath() -> void:
	_pathTiles.clear()
	_pathTargetIndex = 0

	if currentWaypointId == -1:
		return
	var wp := MapManager.getWaypoint(currentWaypointId)
	if wp == null or wp.zoneId != entity.worldPosition.z:
		return
	var zone := MapManager.getZone(entity.worldPosition.z)
	if zone == null or zone.astar == null:
		return

	var fromPos := Vector2i(entity.worldPosition.x, entity.worldPosition.y)
	var rawPath := zone.astar.get_point_path(fromPos, wp.position)
	for v: Vector2 in rawPath:
		_pathTiles.append(Vector2i(int(v.x), int(v.y)))
