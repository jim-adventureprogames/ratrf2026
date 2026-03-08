class_name PlayerInputComponent
extends EntityComponent

# Stored click path: a sequence of tile positions to walk toward.
# Cleared when the player gives keyboard input or reaches the destination.
var _clickPath: Array[Vector2i] = []

# Pixels from a screen edge that count as "move toward the next zone".
# Lets the player click near the edge of the playfield to cross a zone boundary
# even though the click lands in their own tile.
const ZONE_EXIT_THRESHOLD := 4


func processInput() -> void:
	# Explicit wait: keyboard Space / KP5.
	if Input.is_action_just_pressed("wait_turn"):
		_spendAP()
		return

	# Mouse left-click: set a new destination or wait in place.
	if Input.is_action_just_pressed("mouse_move"):
		var bWait := _updateClickPath()
		if bWait:
			_spendAP()
			return
		# Fall through — _clickPath now has the new route; take the first step below.

	# Keyboard direction: cancels any stored mouse path.
	var keyDir := _getKeyboardDirection()
	if keyDir != Vector2i.ZERO:
		_clickPath.clear()
		_tryMoveAndSpend(keyDir)
		return

	# Follow stored mouse click path one step per turn.
	if not _clickPath.is_empty():
		var step := _popNextStep()
		if step != Vector2i.ZERO:
			_tryMoveAndSpend(step)


# Returns true if the player clicked their own tile (wait in place).
# Otherwise builds a new _clickPath toward the clicked tile and returns false.
# Ignores clicks in the UI panel (x >= ZONE_PIXEL_WIDTH).
func _updateClickPath() -> bool:
	_clickPath.clear()
	var mousePixel := get_viewport().get_mouse_position()
	if mousePixel.x >= Globals.ZONE_PIXEL_WIDTH:
		return false

	var clickTile  := Vector2i(int(mousePixel.x / Globals.TILE_SIZE),
							   int(mousePixel.y / Globals.TILE_SIZE))
	var playerTile := Vector2i(entity.worldPosition.x, entity.worldPosition.y)

	if clickTile == playerTile:
		# Check if the click is near a screen edge the player is standing on —
		# if so, treat it as a step toward the next zone rather than a wait.
		var exitDir := _getEdgeExitDirection(mousePixel, playerTile)
		if exitDir != Vector2i.ZERO:
			_clickPath.append(playerTile + exitDir)
			return false
		return true  # clicked self → wait turn

	_buildPathTo(clickTile)
	return false


# Returns a non-zero direction if the player is on a zone-edge tile and the
# click pixel is within ZONE_EXIT_THRESHOLD pixels of the corresponding screen
# edge.  Handles diagonals (corner tiles) by combining x and y components.
func _getEdgeExitDirection(mousePixel: Vector2, playerTile: Vector2i) -> Vector2i:
	var dir := Vector2i.ZERO
	if playerTile.x == 0 and mousePixel.x < ZONE_EXIT_THRESHOLD:
		dir.x = -1
	elif playerTile.x == Globals.ZONE_WIDTH_TILES - 1 \
			and mousePixel.x >= Globals.ZONE_PIXEL_WIDTH - ZONE_EXIT_THRESHOLD:
		dir.x = 1
	if playerTile.y == 0 and mousePixel.y < ZONE_EXIT_THRESHOLD:
		dir.y = -1
	elif playerTile.y == Globals.ZONE_HEIGHT_TILES - 1 \
			and mousePixel.y >= Globals.ZONE_PIXEL_HEIGHT - ZONE_EXIT_THRESHOLD:
		dir.y = 1
	return dir


# Fills _clickPath with an A* path to targetTile.
# Falls back to a single dead-reckoned step if A* returns no path.
func _buildPathTo(targetTile: Vector2i) -> void:
	var playerTile := Vector2i(entity.worldPosition.x, entity.worldPosition.y)
	var zone       := MapManager.getZone(entity.worldPosition.z)

	if zone != null and zone.astar != null:
		var rawPath := zone.astar.get_point_path(playerTile, targetTile)
		if not rawPath.is_empty():
			for v: Vector2 in rawPath:
				_clickPath.append(Vector2i(int(v.x), int(v.y)))
			return

	# No A* path — dead-reckon one step toward the target.
	var diff := targetTile - playerTile
	_clickPath.append(playerTile + Vector2i(sign(diff.x), sign(diff.y)))


# Pops and returns the next step direction from _clickPath.
# Skips tiles the player has already reached (e.g. from a partial move).
func _popNextStep() -> Vector2i:
	var playerTile := Vector2i(entity.worldPosition.x, entity.worldPosition.y)
	while not _clickPath.is_empty() and _clickPath[0] == playerTile:
		_clickPath.pop_front()
	if _clickPath.is_empty():
		return Vector2i.ZERO
	var nextTile := (Vector2i)(_clickPath.pop_front());
	var diff     := nextTile - playerTile
	return Vector2i(sign(diff.x), sign(diff.y))


# Returns true if there is movement input that will fire on the next turn —
# either a keyboard direction is held or a mouse click path is queued.
# Used by SpriteComponent to decide whether to stay in the walk animation.
func hasMovementInput() -> bool:
	return not _clickPath.is_empty() or _getKeyboardDirection() != Vector2i.ZERO


func _tryMoveAndSpend(direction: Vector2i) -> void:
	var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	if mover and mover.tryMove(direction):
		_spendAP()


func _spendAP() -> void:
	var pcc := entity.getComponent(&"PlayerCharacterComponent") as PlayerCharacterComponent
	if pcc:
		pcc.spendAP()


# Numpad diagonals are checked first — single key, unambiguous.
# Cardinal actions are then combined, giving WASD/arrow diagonal support
# by holding two keys (e.g. W+D = up-right).
func _getKeyboardDirection() -> Vector2i:
	if Input.is_action_pressed("move_up_left"):    return Vector2i(-1, -1)
	if Input.is_action_pressed("move_up_right"):   return Vector2i( 1, -1)
	if Input.is_action_pressed("move_down_left"):  return Vector2i(-1,  1)
	if Input.is_action_pressed("move_down_right"): return Vector2i( 1,  1)

	var x := 0
	var y := 0
	if Input.is_action_pressed("move_right"): x += 1
	if Input.is_action_pressed("move_left"):  x -= 1
	if Input.is_action_pressed("move_down"):  y += 1
	if Input.is_action_pressed("move_up"):    y -= 1
	return Vector2i(x, y)
