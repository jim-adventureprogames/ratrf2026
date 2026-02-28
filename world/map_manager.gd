extends Node

# All zones in the world, indexed by zone ID.
var zones: Array[Zone] = []

var entityRegistry: Dictionary = {}   # int → Entity
var nextEntityId: int = 0

# Loaded from data/grass_settings.tres — edit that file in the inspector.
var grassSettings: GrassSettings


func _ready() -> void:
	grassSettings = load("res://data/grass_settings.tres") as GrassSettings
	if grassSettings == null:
		push_warning("MapManager: grass_settings.tres not found, using defaults.")
		grassSettings = GrassSettings.new()


# Returns a tile ID chosen from grassSettings.grassDecorations by weight.
# Returns Tile.EMPTY_TILE if the array is empty.
func pickGrassDecoration() -> int:
	var decorations := grassSettings.grassDecorations
	if decorations.is_empty():
		return Tile.EMPTY_TILE

	var totalWeight := 0.0
	for entry: GrassDecorationEntry in decorations:
		totalWeight += entry.weight

	var roll       := randf() * totalWeight
	var cumulative := 0.0
	for entry: GrassDecorationEntry in decorations:
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


func unregisterEntity(entity: Entity) -> void:
	var tile := getTileAt(entity.worldPosition)
	if tile:
		tile.entities.erase(entity)
	entityRegistry.erase(entity.entityId)
	entity.entityId = -1


func processTurn() -> void:
	for entity: Entity in entityRegistry.values():
		entity.onTakeTurn()
