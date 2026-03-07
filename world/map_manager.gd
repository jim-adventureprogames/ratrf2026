extends Node




# All zones in the world, indexed by zone ID.
var zones: Array[Zone] = []

var entityRegistry: Dictionary = {}   # int → Entity
var waypointRegistry: Dictionary = {}   # int → PathWaypoint
var currentZoneId:  int = -1

# Zone IDs that contain a gate, populated by WorldGenerator after wall placement.
# Used by GameManager to know where to spawn gate-adjacent NPCs (fences, etc.).
var gateZoneIds: Array[int] = []

# Populated by stampTmx whenever an object carries a "spawn" property.
# Key = spawn value (e.g. "player"), value = Array of Vector3i world positions.
var spawnPoints: Dictionary = {}   # String → Array[Vector3i]

# Set by main.gd before the first zone load. Used by MoverComponent to
# trigger visual reloads on zone change without coupling to the scene tree.
var worldTileMap: WorldTileMap

# Loaded from data/grass_settings.tres — edit that file in the inspector.
var grassSettings: GrassSettings

# Loaded from data/npc_settings.tres — edit that file in the inspector.
var npcSettings: NpcSettings

# Loaded from data/world_settings.tres — edit that file in the inspector.
var worldSettings: WorldSettings

var mapInfo : MapDataInfo

var zoneAStar : AStarGrid2D = AStarGrid2D.new()

func _ready() -> void:
	mapInfo = load("res://world/map_data_info.tres") as MapDataInfo
	grassSettings = load("res://data/grass_settings.tres") as GrassSettings
	if grassSettings == null:
		push_warning("MapManager: grass_settings.tres not found, using defaults.")
		grassSettings = GrassSettings.new()
	npcSettings = load("res://data/npc_settings.tres") as NpcSettings
	if npcSettings == null:
		push_warning("MapManager: npc_settings.tres not found, using defaults.")
		npcSettings = NpcSettings.new()
	worldSettings = load("res://data/world_settings.tres") as WorldSettings
	if worldSettings == null:
		push_warning("MapManager: world_settings.tres not found, using defaults.")
		worldSettings = WorldSettings.new()


# Returns a tile ID chosen from grassSettings.grassDecorations by weight.
# Returns Tile.EMPTY_TILE if the array is empty.
func pickGrassDecoration() -> int:
	var decorations := grassSettings.grassDecorations
	if decorations.is_empty():
		return Tile.EMPTY_TILE

	var totalWeight := 0.0
	for entry: TileDecorationEntry in decorations:
		totalWeight += entry.weight

	var roll       := randf() * totalWeight
	var cumulative := 0.0
	for entry: TileDecorationEntry in decorations:
		cumulative += entry.weight
		if roll < cumulative:
			return entry.tileId

	return decorations.back().tileId  # fallback for floating-point edge cases


# Returns a tile ID chosen from grassSettings.dirtDecorations by weight.
# Returns Tile.EMPTY_TILE if the array is empty.
func pickDirtDecoration() -> int:
	var decorations := grassSettings.dirtDecorations
	if decorations.is_empty():
		return Tile.EMPTY_TILE

	var totalWeight := 0.0
	for entry: TileDecorationEntry in decorations:
		totalWeight += entry.weight

	var roll       := randf() * totalWeight
	var cumulative := 0.0
	for entry: TileDecorationEntry in decorations:
		cumulative += entry.weight
		if roll < cumulative:
			return entry.tileId

	return decorations.back().tileId  # fallback for floating-point edge cases


# ── World lookups ──────────────────────────────────────────────────────────────

# Returns the Zone for the given ID, or null if the ID is out of range.
func getZone(zoneId: int) -> Zone:
	if zoneId < 0 or zoneId >= zones.size():
		return null
	return zones[zoneId]


# Returns the Tile at the given world position, or null if the position is invalid.
func getTileAt(worldPos: Vector3i) -> Tile:
	var zone := getZone(worldPos.z)
	if zone == null:
		return null
	return zone.getTile(worldPos.x, worldPos.y)


# Returns the list of entities occupying the tile at the given world position.
# Returns an empty array if the position is invalid.
func getEntitiesAt(worldPos: Vector3i) -> Array[Entity]:
	var tile := getTileAt(worldPos)
	if tile == null:
		return []
	return tile.entities


func registerEntity(entity: Entity) -> void:
	# Ensure components are wired up even if the entity was never added to the
	# scene tree (e.g. entities spawned in zones the player hasn't visited yet).
	entity._initialize()
	entityRegistry[entity.entityId] = entity
	var tile := getTileAt(entity.worldPosition)
	if tile:
		tile.entities.append(entity)
	for child in entity.get_children():
		if child is AIBehaviorComponent:
			GameManager.registerAIComponent(child)


func unregisterEntity(entity: Entity) -> void:
	var tile := getTileAt(entity.worldPosition)
	if tile:
		tile.entities.erase(entity)
	for child in entity.get_children():
		if child is AIBehaviorComponent:
			GameManager.unregisterAIComponent(child)
	entityRegistry.erase(entity.entityId)
	entity.entityId = -1


# Tears down all world state in preparation for a new game.
# Frees every registered entity from the scene tree and clears all data
# structures.  GameManager.resetForNewGame() calls this before rebuilding the
# world with generateWorld() + startGame().
#
# NOTE: entity.queue_free() is deferred, but GameManager nulls playerEntity
# immediately, and the new game is not started until at least one frame later
# (player presses a button), so all nodes will be gone by then.
#
# Add new registries / caches here as the game grows.
func resetForNewGame() -> void:
	# Free every entity node (player + all NPCs).
	# The entities are children of GameManager.entityLayer; queue_free removes
	# them from the scene tree and releases all their child components.
	for entity: Entity in entityRegistry.values():
		entity.queue_free()
	entityRegistry.clear()

	# Discard all zone data.  Zone objects and their Tile arrays are
	# RefCounted, so clearing the array is enough to release them.
	zones.clear()

	# Spawn points are repopulated by WorldGenerator.generateWorld() via
	# stampTmx calls, so they must be cleared before each new world build.
	spawnPoints.clear()

	# Waypoints are placed by WorldGenerator; clear before regenerating.
	waypointRegistry.clear()

	# No zone is loaded after a reset.
	currentZoneId = -1

	# Gate zones are repopulated by WorldGenerator each run.
	gateZoneIds.clear()

	# Blank the four visual tilemap layers so nothing stale shows on screen
	# while the new world is being generated.
	if worldTileMap:
		worldTileMap.clearAllLayers()


func processTurn() -> void:
	for entity: Entity in entityRegistry.values():
		entity.onTakeTurn()


# Clears and rebuilds tile.entities for every tile in the given zone using
# the authoritative entityRegistry.  Called whenever a zone is loaded so that
# tile data is always consistent regardless of how entities were added or moved.
func refreshZoneEntityTiles(zoneId: int) -> void:
	var zone := getZone(zoneId)
	if zone == null:
		return
	for tile: Tile in zone.tiles:
		tile.entities.clear()
	for entity: Entity in entityRegistry.values():
		if entity.worldPosition.z == zoneId:
			var tile := getTileAt(entity.worldPosition)
			if tile:
				tile.entities.append(entity)


# Adds entities that belong to zoneId to the scene tree (entityLayer) and
# removes entities that belong to other zones.  Entities always live in the
# registry; this only controls physical scene presence for rendering/processing.
func refreshZoneSceneNodes(zoneId: int) -> void:
	currentZoneId = zoneId
	for entity: Entity in entityRegistry.values():
		var belongsHere := entity.worldPosition.z == zoneId
		var inScene     := entity.is_inside_tree()
		if belongsHere and not inScene:
			GameManager.entityLayer.add_child(entity)
		elif not belongsHere and inScene:
			GameManager.entityLayer.remove_child(entity)


# ── Procedural decoration ──────────────────────────────────────────────────────

# Fills every tile.wall in the rectangle [start..end] (inclusive) within the
# given zone with the wall tile ID for the given color.
# start and end can be in any order; the function normalises them.
# Pass 1: set all tiles to the base wall tile.
# Pass 2: any tile whose southern neighbour is not a wall (or is out of zone)
#         is switched to the cap tile — one row above on the tileset.
func fillWallRect(start: Vector2i, end: Vector2i, zoneId: int, color: MapDataInfo.EWallColor) -> void:
	if not mapInfo.wallTileIds.has(color):
		push_warning("MapManager.fillWallRect: no tile ID configured for color %d" % color)
		return
	var tileId    := mapInfo.wallTileIds[color]
	var capTileId := tileId - Globals.TILESET_WIDTH_TILES
	var x0        := mini(start.x, end.x)
	var x1        := maxi(start.x, end.x)
	var y0        := mini(start.y, end.y)
	var y1        := maxi(start.y, end.y)

	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var tile := getTileAt(Vector3i(x, y, zoneId))
			if tile:
				tile.wall = tileId

	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var tile := getTileAt(Vector3i(x, y, zoneId))
			if tile == null:
				continue
			var tileBelow    := getTileAt(Vector3i(x, y + 1, zoneId))
			var isBottomEdge := tileBelow == null or tileBelow.wall == Tile.EMPTY_TILE
			if isBottomEdge:
				tile.wall = capTileId


# ── Waypoints ──────────────────────────────────────────────────────────────────

# Registers a waypoint in the global registry and in its zone's list.
func registerWaypoint(wp: PathWaypoint) -> void:
	waypointRegistry[wp.id] = wp
	var zone := getZone(wp.zoneId)
	if zone:
		zone.waypoints.append(wp)


# Returns the waypoint with the given ID, or null if not found.
func getWaypoint(wpId: int) -> PathWaypoint:
	return waypointRegistry.get(wpId) as PathWaypoint


# ── Pathfinding ────────────────────────────────────────────────────────────────

# Returns true if the tile should block movement in the pathfinding graph.
# Checks static geometry AND any entity currently occupying the tile that
# carries a BlocksMovementComponent, so banners, racks, etc. are respected.
func _isTileSolid(tile: Tile) -> bool:
	if tile == null:
		return true
	if tile.wall != Tile.EMPTY_TILE:
		return true
	if tile.ground in mapInfo.wallTileIds:
		return true
	for entity: Entity in tile.entities:
		if entity.getComponent(&"BlocksMovementComponent") != null:
			return true
	return false


# Builds (or fully rebuilds) the AStarGrid2D for a single zone from its
# current tile data.  Safe to call multiple times — always produces a correct
# graph for the tiles as they stand right now.
func buildZoneAStarGraph(zoneId: int) -> void:
	var zone := getZone(zoneId)
	if zone == null:
		return

	if zone.astar == null:
		zone.astar               = AStarGrid2D.new()
		zone.astar.region        = Rect2i(0, 0, Globals.ZONE_WIDTH_TILES, Globals.ZONE_HEIGHT_TILES)
		zone.astar.cell_size     = Vector2(1, 1)
		zone.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER

	# update() resets all solid flags and re-initialises the grid from the
	# region/cell_size properties, so we always start from a clean slate.
	zone.astar.update()

	for y in Globals.ZONE_HEIGHT_TILES:
		for x in Globals.ZONE_WIDTH_TILES:
			if _isTileSolid(zone.getTile(x, y)):
				zone.astar.set_point_solid(Vector2i(x, y), true)


# Updates a single tile's solid state in its zone's graph without a full
# rebuild.  Use this for individual runtime tile changes (e.g. a door opening).
func refreshAStarTile(worldPos: Vector3i) -> void:
	var zone := getZone(worldPos.z)
	if zone == null or zone.astar == null:
		return
	var tile := getTileAt(worldPos)
	zone.astar.set_point_solid(Vector2i(worldPos.x, worldPos.y), _isTileSolid(tile))


# ── Building placement ──────────────────────────────────────────────────────────

# Returns the top-left tile position of the first clear rectangle found in the
# zone, or Vector2i(-1, -1) if no space exists.  "Clear" means every tile has
# no wall, no paved-ground tile, and no dirt-path ground decoration.
# Candidates are shuffled so placements vary between runs.
#
# faireBounds constrains the search to a sub-region of the zone (tile coords,
# inclusive).  Pass Rect2i(0,0,0,0) to search the full zone.
# WorldGenerator uses this to exclude tiles outside the perimeter wall.
func findClearRectInZone(zoneId: int, rectWidth: int, rectHeight: int,
		faireBounds: Rect2i = Rect2i(0, 0, 0, 0)) -> Vector2i:
	var bFullZone := faireBounds.size == Vector2i.ZERO
	var minX := 0                                       if bFullZone else faireBounds.position.x
	var minY := 0                                       if bFullZone else faireBounds.position.y
	var maxX := Globals.ZONE_WIDTH_TILES  - rectWidth   if bFullZone else faireBounds.end.x - rectWidth
	var maxY := Globals.ZONE_HEIGHT_TILES - rectHeight  if bFullZone else faireBounds.end.y - rectHeight
	var candidates: Array[Vector2i] = []
	for y in range(minY, maxY + 1):
		for x in range(minX, maxX + 1):
			candidates.append(Vector2i(x, y))
	candidates.shuffle()
	for topLeft: Vector2i in candidates:
		if _isRectClearForBuilding(topLeft.x, topLeft.y, zoneId, rectWidth, rectHeight):
			return topLeft
	return Vector2i(-1, -1)


func _isRectClearForBuilding(x: int, y: int, zoneId: int, w: int, h: int) -> bool:
	for ty in range(y, y + h):
		for tx in range(x, x + w):
			if not _isTileClearForBuilding(getTileAt(Vector3i(tx, ty, zoneId))):
				return false
	return true


func _isTileClearForBuilding(tile: Tile) -> bool:
	if tile == null:
		return false
	if tile.bReserved:
		return false
	if tile.wall != Tile.EMPTY_TILE:
		return false
	if tile.ground in mapInfo.wallTileIds:
		return false
	# Reject tiles that have been dirtalized into a path.
	for entry: TileDecorationEntry in grassSettings.dirtDecorations:
		if tile.groundDecoration == entry.tileId:
			return false
	return true


# ── Movement validation ─────────────────────────────────────────────────────────

func testDestinationTile(targetPosition: Vector3i, bCheckBump: bool) -> Globals.EMoveTestResult:
	var tile := getTileAt(targetPosition)
	if tile == null:
		return Globals.EMoveTestResult.Wall
	for entity: Entity in tile.entities:
		if bCheckBump and entity.getComponent(&"BumpableComponent") != null:
			return Globals.EMoveTestResult.Bumpable
		if entity.getComponent(&"BlocksMovementComponent") != null:
			return Globals.EMoveTestResult.Entity
	if tile.wall != Tile.EMPTY_TILE:
		return Globals.EMoveTestResult.Wall
	if tile.ground in mapInfo.wallTileIds:
		return Globals.EMoveTestResult.Wall

	return Globals.EMoveTestResult.OK
