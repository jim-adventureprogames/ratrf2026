class_name MoverComponent
extends EntityComponent

signal movementCommitted(fromPixel: Vector2, toPixel: Vector2, bZoneChange: bool, newZoneId: int, direction: Vector2i)
signal movementBlocked(direction: Vector2i)
signal zoneCrossed(newZoneId: int)
signal turnTaken

enum EState {
	Idle,
	Moving,
	Bump,
}

const TWEEN_DURATION := 0.12

var state:  EState         = EState.Idle
var facing: Globals.EFacing = Globals.EFacing.Down

@export var bCanBumpThings: bool = false;

func setMovingComplete() -> void:
	state = EState.Idle


func setBumpComplete() -> void:
	state = EState.Idle


func tryMove(direction: Vector2i) -> bool:
	if state != EState.Idle:
		return false
	_updateFacing(direction)
	var target := resolveTargetWorldPosition(direction)
	if target.z < 0:
		state = EState.Bump
		movementBlocked.emit(direction)
		if not entity.is_inside_tree():
			state = EState.Idle
		return false
	var moveResult := MapManager.testDestinationTile(target, bCanBumpThings)
	if moveResult != Globals.EMoveTestResult.OK:
		state = EState.Bump
		if moveResult == Globals.EMoveTestResult.Bumpable:
			_triggerBumpablesAt(target)
		movementBlocked.emit(direction)
		if not entity.is_inside_tree():
			state = EState.Idle
		return false
	commitMove(direction, target)
	return true


func _updateFacing(direction: Vector2i) -> void:
	if direction.x > 0:
		facing = Globals.EFacing.Right
	elif direction.x < 0:
		facing = Globals.EFacing.Left
	elif direction.y < 0:
		facing = Globals.EFacing.Up
	else:
		facing = Globals.EFacing.Down


func commitMove(direction: Vector2i, target: Vector3i) -> void:
	_updateFacing(direction)
	var bZoneChange := target.z != entity.worldPosition.z
	var fromPixel   := tileToPixel(entity.worldPosition)
	var oldZoneId   := entity.worldPosition.z

	var oldTile := MapManager.getTileAt(entity.worldPosition)
	if oldTile:
		oldTile.entities.erase(entity)

	entity.worldPosition = target

	var newTile := MapManager.getTileAt(entity.worldPosition)
	if newTile:
		newTile.entities.append(entity)

	state = EState.Moving
	if not entity.is_inside_tree():
		# Off-screen entity — no SpriteComponent tween will call setMovingComplete(),
		# so reset immediately so the entity can act next turn.
		state = EState.Idle

	if bZoneChange:
		var isPlayer := entity.getComponent(&"PlayerInputComponent") != null
		if isPlayer:
			# Player zone crossing: reload the visual tilemap.  loadZone calls
			# refreshZoneSceneNodes which sets currentZoneId and manages all
			# entities' scene presence at once.
			MapManager.worldTileMap.loadZone(entity.worldPosition.z)
		else:
			# NPC zone crossing: only adjust this entity's scene node.
			# The tilemap stays on the player's zone.
			var newZoneId := entity.worldPosition.z
			if newZoneId == MapManager.currentZoneId and not entity.is_inside_tree():
				GameManager.entityLayer.add_child(entity)
			elif oldZoneId == MapManager.currentZoneId and entity.is_inside_tree():
				GameManager.entityLayer.remove_child(entity)
		zoneCrossed.emit(entity.worldPosition.z)

	movementCommitted.emit(fromPixel, tileToPixel(target), bZoneChange, entity.worldPosition.z, direction)
	turnTaken.emit()


# Returns the resolved world position after applying direction, including zone transitions.
# Handles cardinal and diagonal directions, including corner-tile diagonal zone crossings.
# Returns Vector3i with z = -1 if the move would leave the world grid.
func resolveTargetWorldPosition(direction: Vector2i) -> Vector3i:
	var targetTileX  := entity.worldPosition.x + direction.x
	var targetTileY  := entity.worldPosition.y + direction.y
	var targetZone   := entity.worldPosition.z
	var zoneStepDir  := Vector2i.ZERO

	# Resolve x and y independently so diagonal moves can cross two boundaries at once
	if targetTileX < 0:
		targetTileX    = Globals.ZONE_WIDTH_TILES - 1
		zoneStepDir.x  = -1
	elif targetTileX >= Globals.ZONE_WIDTH_TILES:
		targetTileX    = 0
		zoneStepDir.x  = 1

	if targetTileY < 0:
		targetTileY    = Globals.ZONE_HEIGHT_TILES - 1
		zoneStepDir.y  = -1
	elif targetTileY >= Globals.ZONE_HEIGHT_TILES:
		targetTileY    = 0
		zoneStepDir.y  = 1

	if zoneStepDir != Vector2i.ZERO:
		var adjacentZone := Globals.getAdjacentZoneId(entity.worldPosition.z, zoneStepDir)
		if adjacentZone == -1:
			return Vector3i(-1, -1, -1)
		targetZone = adjacentZone

	return Vector3i(targetTileX, targetTileY, targetZone)


# Fires trigger() on every BumpableComponent in the entities at the given tile.
func _triggerBumpablesAt(targetPos: Vector3i) -> void:
	for target: Entity in MapManager.getEntitiesAt(targetPos):
		var bumpable := target.getComponent(&"BumpableComponent") as BumpableComponent
		if bumpable:
			bumpable.trigger(entity)


static func tileToPixel(worldPos: Vector3i) -> Vector2:
	return Vector2(
		worldPos.x * Globals.TILE_SIZE + Globals.TILE_SIZE * 0.5,
		worldPos.y * Globals.TILE_SIZE + Globals.TILE_SIZE * 0.5
	)
