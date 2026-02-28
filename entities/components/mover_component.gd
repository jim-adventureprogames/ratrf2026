class_name MoverComponent
extends EntityComponent

signal movementCommitted(fromPixel: Vector2, toPixel: Vector2, bZoneChange: bool, newZoneId: int, direction: Vector2i)
signal zoneCrossed(newZoneId: int)
signal turnTaken

const TWEEN_DURATION := 0.12

var worldMap: WorldTileMap   # set by main.gd before first use
var bMoving: bool = false


func setMovingComplete() -> void:
	bMoving = false


func tryMove(direction: Vector2i) -> bool:
	if bMoving:
		return false
	var target := resolveTargetWorldPosition(direction)
	if target.z < 0:
		return false
	if worldMap.testDestinationTile(target) != Globals.EMoveTestResult.OK:
		return false
	commitMove(direction, target)
	return true


func commitMove(direction: Vector2i, target: Vector3i) -> void:
	var bZoneChange := target.z != entity.worldPosition.z
	var fromPixel   := tileToPixel(entity.worldPosition)

	var oldTile := MapManager.getTileAt(entity.worldPosition)
	if oldTile:
		oldTile.entities.erase(entity)

	entity.worldPosition = target

	var newTile := MapManager.getTileAt(entity.worldPosition)
	if newTile:
		newTile.entities.append(entity)

	bMoving = true

	if bZoneChange:
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


static func tileToPixel(worldPos: Vector3i) -> Vector2:
	return Vector2(
		worldPos.x * Globals.TILE_SIZE + Globals.TILE_SIZE * 0.5,
		worldPos.y * Globals.TILE_SIZE + Globals.TILE_SIZE * 0.5
	)
