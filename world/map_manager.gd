extends Node




# All zones in the world, indexed by zone ID.
var zones: Array[Zone] = []

var entityRegistry: Dictionary = {}   # int → Entity
var nextEntityId:   int = 0
var currentZoneId:  int = -1

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
	entity.entityId  = nextEntityId
	nextEntityId    += 1
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


# ── TMX stamping ───────────────────────────────────────────────────────────────

# Parses a .tmx file from res://tiled/ and writes its tile data into the world
# at the given top-left world position (x, y = tile coords, z = zone ID).
# Only tiles with a non-zero GID overwrite the destination; zero GIDs are skipped
# so the underlying zone data shows through.
func stampTmx(tmxName: String, topLeft: Vector3i) -> void:
	var path   := "res://tiled/" + tmxName
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		push_error("MapManager.stampTmx: could not open '%s'" % path)
		return

	# Tile-layer state
	var currentLayer := ""
	var layerWidth   := 0
	var layerHeight  := 0
	var inData       := false

	# Spawn-layer state — populated across several element events before the
	# </object> closing tag fires and we finally act on the collected data.
	var inSpawnGroup  := false
	var inSpawnObject := false
	var spawnPixelX   := 0.0
	var spawnPixelY   := 0.0
	var spawnPrefab   := ""
	var spawnTag      := ""

	while parser.read() == OK:
		match parser.get_node_type():

			XMLParser.NODE_ELEMENT:
				var tag := parser.get_node_name()
				match tag:
					"layer":
						currentLayer = parser.get_named_attribute_value_safe("name")
						layerWidth   = int(parser.get_named_attribute_value_safe("width"))
						layerHeight  = int(parser.get_named_attribute_value_safe("height"))
						inData       = false
					"data":
						inData = true
					"objectgroup":
						if parser.get_named_attribute_value_safe("name") == "spawn":
							inSpawnGroup = true
					"object":
						if inSpawnGroup:
							inSpawnObject = true
							spawnPixelX   = parser.get_named_attribute_value_safe("x").to_float()
							spawnPixelY   = parser.get_named_attribute_value_safe("y").to_float()
							spawnPrefab   = ""
							spawnTag      = ""
					"property":
						# Each <property> is self-closing — read value here directly.
						if inSpawnObject:
							var propName := parser.get_named_attribute_value_safe("name")
							match propName:
								"prefab": spawnPrefab = parser.get_named_attribute_value_safe("value")
								"spawn":  spawnTag    = parser.get_named_attribute_value_safe("value")

			XMLParser.NODE_TEXT:
				if inData and currentLayer != "":
					_applyLayerData(parser.get_node_data(), currentLayer, layerWidth, layerHeight, topLeft)
					inData = false

			XMLParser.NODE_ELEMENT_END:
				match parser.get_node_name():
					"object":
						# All properties for this object have been read — act on them.
						if inSpawnObject:
							var tileX    := int(spawnPixelX / Globals.TILE_SIZE)
							var tileY    := int(spawnPixelY / Globals.TILE_SIZE)
							var worldPos := Vector3i(topLeft.x + tileX, topLeft.y + tileY, topLeft.z)
							if spawnPrefab != "":
								_spawnEntityFromPrefab(spawnPrefab, worldPos)
							if spawnTag != "":
								if not spawnPoints.has(spawnTag):
									spawnPoints[spawnTag] = []
								spawnPoints[spawnTag].append(worldPos)
						inSpawnObject = false
						spawnPrefab   = ""
						spawnTag      = ""
					"objectgroup":
						inSpawnGroup = false


func _spawnEntityFromPrefab(prefabName: String, worldPos: Vector3i) -> void:
	var scenePath := "res://entity_prefabs/" + prefabName + ".tscn"
	var packed    := load(scenePath) as PackedScene
	if packed == null:
		push_error("MapManager: could not load prefab '%s'" % scenePath)
		return
	var entity := packed.instantiate() as Entity
	if entity == null:
		push_error("MapManager: scene root is not an Entity in '%s'" % scenePath)
		return
	entity.worldPosition = worldPos
	applySpawnVariant(entity)
	registerEntity(entity)
	# Do NOT add to the scene tree here.  refreshZoneSceneNodes() handles
	# scene presence when the zone containing this entity is loaded.


# Applies any data-driven visual variants to a freshly instantiated entity.
# Currently: picks a random SpriteFrames for mark entities.
func applySpawnVariant(entity: Entity) -> void:
	var isMark := false
	var spriteComp: AnimatedSprite2D = null
	for child in entity.get_children():
		if child is MarkComponent:
			isMark = true
		if child is AnimatedSprite2D:
			spriteComp = child

	if not isMark or spriteComp == null:
		return
	if npcSettings.markSpriteFrames.is_empty():
		return

	spriteComp.sprite_frames = npcSettings.markSpriteFrames[randi() % npcSettings.markSpriteFrames.size()]


func _applyLayerData(csv: String, layerName: String, width: int, height: int, topLeft: Vector3i) -> void:
	var tokens := csv.split(",", false)
	var col    := 0
	var row    := 0
	for token: String in tokens:
		var trimmed := token.strip_edges()
		if trimmed.is_empty():
			continue
		var gid       := int(trimmed)
		var tileIndex := Tile.EMPTY_TILE if gid == 0 else gid - 1
		var worldPos  := Vector3i(topLeft.x + col, topLeft.y + row, topLeft.z)
		var tile      := getTileAt(worldPos)
		if tile:
			match layerName:
				"ground":            tile.ground           = tileIndex
				"ground_decoration": tile.groundDecoration = tileIndex
				"wall":              tile.wall             = tileIndex
				"wall_decoration":   tile.wallDecoration   = tileIndex
		col += 1
		if col >= width:
			col  = 0
			row += 1


# ── Procedural decoration ──────────────────────────────────────────────────────

# Fills every tile.wall in the rectangle [start..end] (inclusive) within the
# given zone with the wall tile ID for the given color.
# start and end can be in any order; the function normalises them.
func fillWallRect(start: Vector2i, end: Vector2i, zoneId: int, color: MapDataInfo.EWallColor) -> void:
	if not mapInfo.wallTileIds.has(color):
		push_warning("MapManager.fillWallRect: no tile ID configured for color %d" % color)
		return
	var tileId := mapInfo.wallTileIds[color]
	var x0     := mini(start.x, end.x)
	var x1     := maxi(start.x, end.x)
	var y0     := mini(start.y, end.y)
	var y1     := maxi(start.y, end.y)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var tile := getTileAt(Vector3i(x, y, zoneId))
			if tile:
				tile.wall = tileId


# ── Movement validation ─────────────────────────────────────────────────────────

func testDestinationTile(targetPosition: Vector3i) -> Globals.EMoveTestResult:
	var tile := getTileAt(targetPosition)
	if tile == null:
		return Globals.EMoveTestResult.Wall
	if tile.wall != Tile.EMPTY_TILE:
		return Globals.EMoveTestResult.Wall
	if tile.ground in mapInfo.wallTileIds:
		return Globals.EMoveTestResult.Wall
	for entity: Entity in tile.entities:
		if entity.getComponent(&"BlocksMovementComponent") != null:
			return Globals.EMoveTestResult.Entity
	return Globals.EMoveTestResult.OK
