class_name GuardComponent
extends AIBehaviorComponent

# Anchor tile for guarding_location mode (x/y within the zone).
@export var guardLocation: Vector2i = Vector2i.ZERO

# How many turns to spend at a crime scene before resuming normal patrol.
@export var investigateDuration: int = 20

# How many turns to shadow a suspect before breaking off the follow.
@export var followDuration: int = 30

var targetEntity: Entity

var bDetectedCrimeThisTurn: bool

# How concerned is this guard right now? < 1.0 means no clear suspect or crime,
# as it approaches 1 the guard is more suspicious.
var alertLevel: float

# Zone this guard was assigned to at spawn — they return here after a chase.
var homeZoneId: int = -1


func _enter_tree() -> void:
	updateSpriteBorderByBehavior()


func onDebugPrint() -> void:
	super()
	print("    alertLevel: %.2f" % alertLevel)


func onEndOfTurn() -> void:
	super()

	if not bDetectedCrimeThisTurn && (currentState.flags & EBehaviorFlags.chasing_entity) == 0:
		alertLevel -= 0.01
	alertLevel = max(alertLevel, 0.0)

	if currentState.stateName == &"investigating":
		if bDetectedCrimeThisTurn:
			# Fresh detection while already investigating — reset the countdown.
			currentState.data["turnsRemaining"] = investigateDuration
		else:
			currentState.data["turnsRemaining"] -= 1
			if currentState.data["turnsRemaining"] <= 0:
				_stopInvestigating()

	if currentState.stateName == &"following":
		currentState.data["turnsRemaining"] -= 1
		if currentState.data["turnsRemaining"] <= 0:
			_stopFollowingEntity()

	bDetectedCrimeThisTurn = false
	updateSpriteBorderByBehavior()


func onAttached() -> void:
	homeZoneId   = entity.worldPosition.z
	currentState = BehaviorState.new(&"observing", EBehaviorFlags.observing)
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.movementBlocked.connect(_onMovementBlocked)


func _onMovementBlocked(direction: Vector2i) -> void:
	if not (behaviorFlags & EBehaviorFlags.chasing_entity):
		return
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return
	var targetPos := mover.resolveTargetWorldPosition(direction)
	if targetPos.z < 0:
		return
	for target: Entity in MapManager.getEntitiesAt(targetPos):
		if target.getComponent(&"PlayerInputComponent") != null:
			GameManager.HandleGuardApprehendPlayer(entity, target)
			return


func onDecideChaseCriminal(criminal: Entity) -> void:
	targetEntity = criminal
	if targetEntity:
		behaviorFlags &= ~EBehaviorFlags.observing
		behaviorFlags |= EBehaviorFlags.chasing_entity
	else:
		behaviorFlags &= ~EBehaviorFlags.chasing_entity
		behaviorFlags |= EBehaviorFlags.observing


# Examines the world and picks the best action for this turn.
# guarding_zone:     follows the zone's patrol waypoint route via PathWalkingComponent.
# guarding_location: anchor = guardLocation; zone-crossing moves are blocked.
# Both flags prevent zone crossings.
func decideWhatToDo() -> void:
	nextStepTile      = Vector3i(-1, -1, -1)
	nextStepDirection = Vector2i.ZERO

	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover == null:
		return

	# guarding_zone: delegate movement to the patrol waypoint path walker.
	if behaviorFlags & EBehaviorFlags.guarding_zone:
		var pathWalker := entity.getComponent(&"PathWalkingComponent") as PathWalkingComponent
		if pathWalker != null:
			if pathWalker.currentWaypointId == -1:
				var nearestId := _findNearestPatrolWaypoint()
				if nearestId != -1:
					pathWalker.startAtWaypoint(nearestId)
			var step := pathWalker.getNextStepDirection()
			if step != Vector2i.ZERO:
				nextStepDirection = step
				return

	# guarding_location: step toward the anchor unless already within 1 tile.
	# Anchor comes from state data if present, otherwise falls back to the export.
	if behaviorFlags & EBehaviorFlags.guarding_location:
		var anchor   : Vector2i = currentState.data.get("location", guardLocation)
		var guardPos := Vector2i(entity.worldPosition.x, entity.worldPosition.y)
		var dx := anchor.x - guardPos.x
		var dy := anchor.y - guardPos.y
		if abs(dx) > 1 or abs(dy) > 1:
			var dir := _cardinalToward(guardPos, anchor)
			var target := mover.resolveTargetWorldPosition(dir)
			if target.z >= 0 and target.z == entity.worldPosition.z:
				nextStepTile      = target
				nextStepDirection = dir
				return
		# Within 1 tile — small wander, stay in zone.
		var cardinals := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
		cardinals.shuffle()
		for dir: Vector2i in cardinals:
			var target := mover.resolveTargetWorldPosition(dir)
			if target.z < 0 or target.z != entity.worldPosition.z:
				continue
			nextStepTile      = target
			nextStepDirection = dir
			return
		return

	# returning_to_zone: navigate back to homeZoneId after a chase ends.
	if behaviorFlags & EBehaviorFlags.returning_to_zone:
		if entity.worldPosition.z == homeZoneId:
			_stopReturning()
			# Fall through so patrol resumes on this same turn.
		else:
			var dir    := _zoneGridDirectionTowardHome()
			var target := mover.resolveTargetWorldPosition(dir)
			if target.z >= 0:
				nextStepTile      = target
				nextStepDirection = dir
			return

	# chasing_entity: close the gap completely and bump the target every turn.
	if behaviorFlags & EBehaviorFlags.chasing_entity:
		var chaseTarget := currentState.data.get("target", null) as Entity
		if chaseTarget == null:
			_stopChasing()
		else:
			var dir    := _cardinalTowardEntity(chaseTarget)
			var target := mover.resolveTargetWorldPosition(dir)
			_faceTowardTile(Vector2i(entity.worldPosition.x, entity.worldPosition.y),
					Vector2i(entity.worldPosition.x + dir.x, entity.worldPosition.y + dir.y))
			if target.z >= 0:
				nextStepTile      = target
				nextStepDirection = dir
		return

	# following_entity: shadow the target, staying within 2 tiles without bumping.
	if behaviorFlags & EBehaviorFlags.following_entity:
		var followTarget := currentState.data.get("target", null) as Entity
		if followTarget == null:
			_stopFollowingEntity()
		else:
			var guardPos  := Vector2i(entity.worldPosition.x, entity.worldPosition.y)
			var targetPos := Vector2i(followTarget.worldPosition.x, followTarget.worldPosition.y)
			var dist      := (float)(max(abs(targetPos.x - guardPos.x), abs(targetPos.y - guardPos.y)))
			_faceTowardTile(guardPos, targetPos)
			if dist > 2:
				var dir    := _cardinalToward(guardPos, targetPos)
				var target := mover.resolveTargetWorldPosition(dir)
				if target.z >= 0:
					nextStepTile      = target
					nextStepDirection = dir
			# Within 2 tiles — stand still, already facing them.
		return

	# Fallback wander for un-locked guards.
	var cardinals := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	cardinals.shuffle()
	for dir: Vector2i in cardinals:
		var target := mover.resolveTargetWorldPosition(dir)
		if target.z < 0:
			continue
		nextStepTile      = target
		nextStepDirection = dir
		return


# Returns the ID of the nearest patrol-loop waypoint in the guard's current zone,
# or -1 if the zone has no patrol waypoints.
func _findNearestPatrolWaypoint() -> int:
	var zone := MapManager.getZone(entity.worldPosition.z)
	if zone == null:
		return -1
	var guardPos   := Vector2(entity.worldPosition.x, entity.worldPosition.y)
	var bestId     := -1
	var bestDistSq := INF
	for wp: PathWaypoint in zone.waypoints:
		if not wp.bPatrolLoop:
			continue
		var distSq := guardPos.distance_squared_to(Vector2(wp.position))
		if distSq < bestDistSq:
			bestDistSq = distSq
			bestId     = wp.id
	return bestId


# Returns the cardinal direction toward another entity, handling cross-zone cases.
# Same zone: compares tile coordinates directly.
# Different zone: compares zone-grid positions so the guard walks toward the exit.
func _cardinalTowardEntity(target: Entity) -> Vector2i:
	if target.worldPosition.z == entity.worldPosition.z:
		return _cardinalToward(
				Vector2i(entity.worldPosition.x, entity.worldPosition.y),
				Vector2i(target.worldPosition.x,  target.worldPosition.y))
	var w          := Globals.ZONE_GRID_WIDTH
	var currentCol := entity.worldPosition.z % w
	var currentRow := entity.worldPosition.z / w
	var targetCol  := target.worldPosition.z % w
	var targetRow  := target.worldPosition.z / w
	return _cardinalToward(Vector2i(currentCol, currentRow), Vector2i(targetCol, targetRow))


# Returns the dominant-axis cardinal direction from 'from' toward 'to'.
func _cardinalToward(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if abs(dx) >= abs(dy):
		return Vector2i(sign(dx), 0)
	return Vector2i(0, sign(dy))


# True when either guarding flag is set — zone crossing is blocked for both.
func _isZoneLocked() -> bool:
	return behaviorFlags & (EBehaviorFlags.guarding_zone | EBehaviorFlags.guarding_location)


func updateSpriteBorderByBehavior() -> void:
	var sprite = entity.getComponent(&"SpriteComponent") as SpriteComponent
	if sprite:
		if behaviorFlags & EBehaviorFlags.chasing_entity:
			sprite.setBorderState(SpriteComponent.ESpriteBorderStyle.hostile)
		elif behaviorFlags & (EBehaviorFlags.observing | EBehaviorFlags.returning_to_zone):
			sprite.setBorderState(SpriteComponent.ESpriteBorderStyle.observant)
		else:
			sprite.setBorderState(SpriteComponent.ESpriteBorderStyle.none)


# Sends the guard to investigate a crime scene location.
# If already investigating, just redirects and resets the countdown.
func _startInvestigating(crimeLocation: Vector2i) -> void:
	if currentState.stateName == &"investigating":
		currentState.data["location"]       = crimeLocation
		currentState.data["turnsRemaining"] = investigateDuration
		return
	var state := BehaviorState.new(&"investigating",
			(int(behaviorFlags) & ~EBehaviorFlags.guarding_zone) | EBehaviorFlags.guarding_location)
	state.data["location"]       = crimeLocation
	state.data["turnsRemaining"] = investigateDuration
	# Reset the path walker so it picks up fresh when patrol resumes.
	var pathWalker := entity.getComponent(&"PathWalkingComponent") as PathWalkingComponent
	if pathWalker:
		pathWalker.currentWaypointId = -1
	pushState(state)


# Restores the guard's prior state and resumes patrol.
func _stopInvestigating(bFoundNothing: bool = true) -> void:
	popState()
	if bFoundNothing:
		GameManager.spawnBark(entity, tr("bark_investigate_end"), FloatingShout.EShoutType.think)

# Begins shadowing the target entity for followDuration turns.
# If already following, redirects to the new target and resets the countdown.
func _startFollowingEntity(target: Entity) -> void:
	if currentState.stateName == &"following":
		currentState.data["target"]         = target
		currentState.data["turnsRemaining"] = followDuration
		return
	var state := BehaviorState.new(&"following",
			(int(behaviorFlags) & ~EBehaviorFlags.guarding_zone) | EBehaviorFlags.following_entity)
	state.data["target"]         = target
	state.data["turnsRemaining"] = followDuration
	pushState(state)


# Breaks off the follow and restores prior behavior.
func _stopFollowingEntity() -> void:
	popState()


# Begins relentlessly chasing the target with no time limit.
# If already chasing, redirects to the new target.
func _startChasing(target: Entity) -> void:
	alertLevel = 1.0
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.bCanBumpThings = true
	if currentState.stateName == &"chasing":
		currentState.data["target"] = target
		return
	var state := BehaviorState.new(&"chasing",
			(int(behaviorFlags) & ~(EBehaviorFlags.guarding_zone | EBehaviorFlags.following_entity)) \
			| EBehaviorFlags.chasing_entity)
	state.data["target"] = target
	# Reset the path walker so patrol picks up fresh if chase ever ends.
	var pathWalker := entity.getComponent(&"PathWalkingComponent") as PathWalkingComponent
	if pathWalker:
		pathWalker.currentWaypointId = -1
	pushState(state)


# Breaks off the chase and restores prior behavior.
# If the guard ended up outside their home zone, begins returning.
func _stopChasing() -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover.bCanBumpThings = false
	popState()
	if entity.worldPosition.z != homeZoneId:
		_startReturning()


# Walks the guard back to homeZoneId one zone at a time.
func _startReturning() -> void:
	var state := BehaviorState.new(&"returning", EBehaviorFlags.returning_to_zone)
	pushState(state)


# Called once the guard re-enters their home zone.
func _stopReturning() -> void:
	popState()
	# Reset path walker so patrol resumes from the nearest waypoint.
	var pathWalker := entity.getComponent(&"PathWalkingComponent") as PathWalkingComponent
	if pathWalker:
		pathWalker.currentWaypointId = -1


# Returns the tile-movement direction that carries the guard toward their home
# zone by comparing zone-grid coordinates (row-major, ZONE_GRID_WIDTH columns).
func _zoneGridDirectionTowardHome() -> Vector2i:
	var w          := Globals.ZONE_GRID_WIDTH
	var currentCol := entity.worldPosition.z % w
	var currentRow := entity.worldPosition.z / w
	var homeCol    := homeZoneId % w
	var homeRow    := homeZoneId / w
	return _cardinalToward(Vector2i(currentCol, currentRow), Vector2i(homeCol, homeRow))


# Points the guard's facing toward a tile without triggering movement.
func _faceTowardTile(from: Vector2i, to: Vector2i) -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover:
		mover._updateFacing(_cardinalToward(from, to))


func onSoftDetectCrime(event: CrimeEvent) -> void:
	bDetectedCrimeThisTurn = true

	# If already in hot pursuit, no change needed.
	if alertLevel >= 1.0:
		return

	alertLevel = min(0.99, alertLevel + 0.2)

	# Wondering if there's crime going on.
	if alertLevel <= 0.4:
		GameManager.spawnBark(entity, tr("bark_crime_suspect_01"), FloatingShout.EShoutType.think)
		return

	# Pretty sure something's going on...
	if alertLevel < 0.7:
		GameManager.spawnBark(entity, tr("bark_crime_suspect_02"), FloatingShout.EShoutType.think)
		_startInvestigating(Vector2i(event.location.x, event.location.y))
		return

	# Alert enough to follow the player
	GameManager.spawnBark(entity, tr("bark_crime_suspect_03"), FloatingShout.EShoutType.think)


func onHardDetectCrime(event: CrimeEvent) -> void:
	bDetectedCrimeThisTurn = true
	var perp := GameManager.getEntityByID(event.perpID)
	if perp == null:
		return
	GameManager.spawnBark(entity, tr("bark_crime_hard_detect_01"), FloatingShout.EShoutType.shout)
	_startChasing(perp)
