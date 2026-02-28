class_name Zone
extends Resource

@export var id:           int    = 0
@export var friendlyName: String = ""
@export var region:       String = ""

# Flat 1D array of tiles; index with (y * ZONE_WIDTH_TILES + x)
var tiles: Array[Tile] = []


# Called by MapManager after construction to populate the tile array.
func initializeTiles() -> void:
	var count := Globals.ZONE_WIDTH_TILES * Globals.ZONE_HEIGHT_TILES
	tiles.resize(count)
	for i in count:
		tiles[i] = Tile.new()


# Returns the Tile at local tile coordinates (x, y), or null if out of bounds.
func getTile(x: int, y: int) -> Tile:
	if x < 0 or x >= Globals.ZONE_WIDTH_TILES:
		return null
	if y < 0 or y >= Globals.ZONE_HEIGHT_TILES:
		return null
	return tiles[y * Globals.ZONE_WIDTH_TILES + x]


# Convenience overload: accepts a Vector3i world position and uses only x and y.
# GDScript has no true overloading, so this carries a distinct name.
func getTileAtWorldPosition(worldPos: Vector3i) -> Tile:
	return getTile(worldPos.x, worldPos.y)
