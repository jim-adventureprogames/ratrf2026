class_name WorldTileMap
extends TileMapLayer

const GROUND_SOURCE_ID := 0

# Set by main.gd before the first loadZone call
var decorationLayer: TileMapLayer


func loadZone(zoneId: int) -> void:
	clear()
	if decorationLayer:
		decorationLayer.clear()

	var zone := MapManager.getZone(zoneId)
	if zone == null:
		return

	for x in Globals.ZONE_WIDTH_TILES:
		for y in Globals.ZONE_HEIGHT_TILES:
			var tile := zone.getTile(x, y)
			if tile == null:
				continue
			var coords := Vector2i(x, y)

			if tile.ground != Tile.EMPTY_TILE:
				set_cell(coords, GROUND_SOURCE_ID,
						Globals.tileIndexToAtlasCoords(tile.ground))

			if tile.groundDecoration != Tile.EMPTY_TILE and decorationLayer:
				decorationLayer.set_cell(coords, GROUND_SOURCE_ID,
						Globals.tileIndexToAtlasCoords(tile.groundDecoration))


func testDestinationTile(targetPosition: Vector3i) -> Globals.EMoveTestResult:
	var tile := MapManager.getTileAt(targetPosition)
	if tile == null:
		return Globals.EMoveTestResult.Wall
	if tile.wall != Tile.EMPTY_TILE:
		return Globals.EMoveTestResult.Wall
	for entity: Entity in tile.entities:
		if entity.getComponent(&"BlocksMovementComponent") != null:
			return Globals.EMoveTestResult.Entity
	return Globals.EMoveTestResult.OK
