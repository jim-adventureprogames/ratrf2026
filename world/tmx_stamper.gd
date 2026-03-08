class_name TmxStamper
extends RefCounted

# Handles all TMX file parsing, tile stamping, and entity spawning.
# Extracted from MapManager to keep that autoload focused on world-state
# lookups rather than file I/O and XML parsing.
#
# All methods are static — call as TmxStamper.stampTmx(...) etc.


# Parses a .tmx file from res://tiled/ and writes its tile data into the world
# at the given top-left world position (x, y = tile coords, z = zone ID).
# Only tiles with a non-zero GID overwrite the destination; zero GIDs are skipped
# so the underlying zone data shows through.
static func stampTmx(tmxName: String, topLeft: Vector3i) -> void:
	var path   := "res://tiled/" + tmxName
	# In exported builds Godot may append ".remap" to non-resource files.
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".remap"):
		path += ".remap"
		print("Found a remap path: %s " % path);
	var parser := XMLParser.new()
	var result =  parser.open(path);
	if result != OK:
		push_error("TmxStamper.stampTmx: could not open '%s' '%s'" % path % result)
		return

	# Tile-layer state.
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
	var spawnProps: Dictionary = {}

	# Collects every entity spawned during this stamp so postStampCleanup
	# can hand each one the full peer list.
	# Each entry: { "entity": Entity, "props": Dictionary }
	var stampedEntityData: Array = []

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
						inSpawnGroup = true
					"object":
						if inSpawnGroup:
							inSpawnObject = true
							spawnPixelX   = parser.get_named_attribute_value_safe("x").to_float()
							spawnPixelY   = parser.get_named_attribute_value_safe("y").to_float()
							spawnPrefab   = ""
							spawnTag      = ""
							spawnProps    = {}
					"property":
						# Each <property> is self-closing — read value here directly.
						if inSpawnObject:
							var propName := parser.get_named_attribute_value_safe("name")
							var propVal  := parser.get_named_attribute_value_safe("value")
							match propName:
								"prefab": spawnPrefab = propVal
								"spawn":  spawnTag    = propVal
								_:        spawnProps[propName] = propVal

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
								var spawned := spawnEntityFromPrefab(spawnPrefab, worldPos)
								if spawned != null:
									stampedEntityData.append({"entity": spawned, "props": spawnProps.duplicate()})
							if spawnTag != "":
								if not MapManager.spawnPoints.has(spawnTag):
									MapManager.spawnPoints[spawnTag] = []
								MapManager.spawnPoints[spawnTag].append(worldPos)
						inSpawnObject = false
						spawnPrefab   = ""
						spawnTag      = ""
						spawnProps    = {}
					"objectgroup":
						inSpawnGroup = false

	# Tiles may have changed — rebuild the zone's pathfinding graph.
	MapManager.buildZoneAStarGraph(topLeft.z)

	# Give every spawned entity a chance to cross-reference its stamp peers.
	var stampedEntities: Array[Entity] = []
	for entry in stampedEntityData:
		stampedEntities.append(entry.entity)
	for entry in stampedEntityData:
		entry.entity.postStampCleanup(stampedEntities, entry.props)


# Reads the tile dimensions of a TMX file without fully parsing it.
# Returns Vector2i(-1, -1) if the file cannot be opened or has no <map> element.
static func getTmxSize(tmxName: String) -> Vector2i:
	var path   := "res://tiled/" + tmxName
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		push_error("TmxStamper.getTmxSize: could not open '%s'" % path)
		return Vector2i(-1, -1)
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT \
				and parser.get_node_name() == "map":
			var w := int(parser.get_named_attribute_value_safe("width"))
			var h := int(parser.get_named_attribute_value_safe("height"))
			return Vector2i(w, h)
	return Vector2i(-1, -1)


# Instantiates an entity prefab from res://entity_prefabs/, places it at
# worldPos, applies spawn variants, and registers it with MapManager.
# Does NOT add the entity to the scene tree — refreshZoneSceneNodes handles that.
static func spawnEntityFromPrefab(prefabName: String, worldPos: Vector3i) -> Entity:
	var scenePath := "res://entity_prefabs/" + prefabName + ".tscn"
	var packed    := load(scenePath) as PackedScene
	if packed == null:
		push_error("TmxStamper: could not load prefab '%s'" % scenePath)
		return null
	var entity := packed.instantiate() as Entity
	if entity == null:
		push_error("TmxStamper: scene root is not an Entity in '%s'" % scenePath)
		return null
	entity.worldPosition = worldPos
	applySpawnVariant(entity)
	MapManager.registerEntity(entity)
	return entity


# Applies data-driven visual variants to a freshly instantiated entity.
# Currently: picks a random SpriteFrames for mark and guard entities.
static func applySpawnVariant(entity: Entity) -> void:
	var spriteComp: AnimatedSprite2D = null
	var isMark:  bool = false
	var isGuard: bool = false
	for child in entity.get_children():
		if child is AnimatedSprite2D:
			spriteComp = child
		if child is MarkComponent:
			isMark = true
		if child is GuardComponent:
			isGuard = true

	if spriteComp == null:
		return

	if isMark and not MapManager.npcSettings.markSpriteFrames.is_empty():
		spriteComp.sprite_frames = MapManager.npcSettings.markSpriteFrames[randi() % MapManager.npcSettings.markSpriteFrames.size()]
	elif isGuard and not MapManager.npcSettings.guardSpriteFrames.is_empty():
		spriteComp.sprite_frames = MapManager.npcSettings.guardSpriteFrames[randi() % MapManager.npcSettings.guardSpriteFrames.size()]


static func _applyLayerData(csv: String, layerName: String, width: int, height: int, topLeft: Vector3i) -> void:
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
		var tile      := MapManager.getTileAt(worldPos)
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
