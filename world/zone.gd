class_name Zone
extends Resource

enum EZoneEdge { North, South, East, West, Center }

@export var id:           int    = 0
@export var friendlyName: String = ""
@export var region:       String = ""

# Flat 1D array of tiles; index with (y * ZONE_WIDTH_TILES + x)
var tiles: Array[Tile] = []

# Path waypoints added when dirtalization runs through this zone.
var waypoints: Array[PathWaypoint] = []

# Which edges (including Center) have had a dirt path run through them.
# Populated by WorldGenerator.dirtalizePathInZone(); used to build patrol routes.
var dirtalizedEdges: Array[Zone.EZoneEdge] = []

# Tile-level pathfinding graph for this zone.
# Built by MapManager.buildZoneAStarGraph() after generation and after any
# stampTmx call.  Null until first built.
var astar: AStarGrid2D = null

# How untouched this zone feels.  Starts at 99 (fully wild).
# Set to 0 when a dirt path runs through the zone, then re-scored by
# WorldGenerator._determineZoneWilderness() as BFS distance from the
# nearest dirtalized zone.
var wildernessScore: int = 99

# Landmark positions in local tile coordinates (x, y within this zone).
var northCenter:  Vector2i
var southCenter:  Vector2i
var westCenter:   Vector2i
var eastCenter:   Vector2i
var centerCenter: Vector2i


# Called by MapManager after construction to populate the tile array.
func initializeTiles() -> void:
	var count  := Globals.ZONE_WIDTH_TILES * Globals.ZONE_HEIGHT_TILES
	var halfX  := Globals.ZONE_WIDTH_TILES  / 2
	var halfY  := Globals.ZONE_HEIGHT_TILES / 2
	var farX   := Globals.ZONE_WIDTH_TILES  - 1
	var farY   := Globals.ZONE_HEIGHT_TILES - 1

	northCenter  = Vector2i(halfX, 0)
	southCenter  = Vector2i(halfX, farY)
	westCenter   = Vector2i(0,     halfY)
	eastCenter   = Vector2i(farX,  halfY)
	centerCenter = Vector2i(halfX, halfY)

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
