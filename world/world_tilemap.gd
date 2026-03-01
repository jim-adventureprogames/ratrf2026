class_name WorldTileMap
extends TileMapLayer

const GROUND_SOURCE_ID := 0

# Set by main.gd before the first loadZone call
var groundDecorationLayer: TileMapLayer
var wallLayer:             TileMapLayer
var wallDecorationLayer:   TileMapLayer


func _ready() -> void:
	_registerAllAtlasTiles()


func _registerAllAtlasTiles() -> void:
	var source := tile_set.get_source(GROUND_SOURCE_ID) as TileSetAtlasSource
	if source == null:
		push_error("WorldTileMap: no TileSetAtlasSource at source ID %d" % GROUND_SOURCE_ID)
		return
	for y in Globals.TILESET_HEIGHT_TILES:
		for x in Globals.TILESET_WIDTH_TILES:
			var coords := Vector2i(x, y)
			if not source.has_tile(coords):
				source.create_tile(coords)


func loadZone(zoneId: int) -> void:
	clear()
	if groundDecorationLayer: groundDecorationLayer.clear()
	if wallLayer:             wallLayer.clear()
	if wallDecorationLayer:   wallDecorationLayer.clear()

	MapManager.refreshZoneEntityTiles(zoneId)
	MapManager.refreshZoneSceneNodes(zoneId)

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

			if tile.groundDecoration != Tile.EMPTY_TILE and groundDecorationLayer:
				groundDecorationLayer.set_cell(coords, GROUND_SOURCE_ID,
						Globals.tileIndexToAtlasCoords(tile.groundDecoration))

			if tile.wall != Tile.EMPTY_TILE and wallLayer:
				wallLayer.set_cell(coords, GROUND_SOURCE_ID,
						Globals.tileIndexToAtlasCoords(tile.wall))

			if tile.wallDecoration != Tile.EMPTY_TILE and wallDecorationLayer:
				wallDecorationLayer.set_cell(coords, GROUND_SOURCE_ID,
						Globals.tileIndexToAtlasCoords(tile.wallDecoration))
