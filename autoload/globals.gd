extends Node

enum EMoveTestResult {
	OK,				# move is fine
	Wall,			# a wall with nothing bumpable on it
	Entity,			# an entity that prevents movement, but doesn't respond to bump
	Bumpable,		# something that responds to bumping.
}

enum EFacing {
	Up,
	Right,
	Down,
	Left,
}

enum ERogueStat {
	Charm,
	FastTalk,
	Haggle,
	Lockpick,
}

const TILE_SIZE              := 12
const TILESET_WIDTH_TILES    := 23   # world.png is 276px wide  (276 / 12)
# TILESET_HEIGHT_TILES is intentionally absent — derived at runtime from the
# texture height in WorldTileMap._registerAllAtlasTiles() so it stays correct
# whenever world.png grows taller.

const ZONE_WIDTH_TILES  := 20
const ZONE_HEIGHT_TILES := 20
const ZONE_PIXEL_WIDTH  := TILE_SIZE * ZONE_WIDTH_TILES   # 240
const ZONE_PIXEL_HEIGHT := TILE_SIZE * ZONE_HEIGHT_TILES  # 240

const UI_PANEL_X        := ZONE_PIXEL_WIDTH               # 240 — right panel starts here
const UI_PANEL_WIDTH    := 80                             # 320 - 240

# These are vars (not consts) so WorldGenerator can set them at runtime
# after reading WorldSettings.  Read-only everywhere except WorldGenerator.generateWorld().
var ZONE_GRID_WIDTH:  int = 5
var ZONE_GRID_HEIGHT: int = 5
var ZONE_COUNT:       int = 25
var STARTING_ZONE:    int = 12


func _ready() -> void:
	initializeInputActions()
	RandomTable._loadAllTables()
	ItemData.loadAll()
	ItemData.populateTierIntoTable(1, "mark_loot_table_01")


# Defines all movement input actions at runtime.
# Cardinal actions map WASD, arrow keys, and numpad cardinals.
# Diagonal actions are numpad-only; WASD/arrow diagonals are handled by
# combining cardinal inputs in the player's getInputDirection().
func initializeInputActions() -> void:
	_defineAction("move_up",         [KEY_W, KEY_UP,    KEY_KP_8])
	_defineAction("move_down",        [KEY_S, KEY_DOWN,  KEY_KP_2])
	_defineAction("move_left",        [KEY_A, KEY_LEFT,  KEY_KP_4])
	_defineAction("move_right",       [KEY_D, KEY_RIGHT, KEY_KP_6])
	_defineAction("move_up_left",     [KEY_KP_7])
	_defineAction("move_up_right",    [KEY_KP_9])
	_defineAction("move_down_left",   [KEY_KP_1])
	_defineAction("move_down_right",  [KEY_KP_3])
	_defineAction("toggle_minimap",   [KEY_TAB])


func _defineAction(actionName: String, keycodes: Array) -> void:
	if not InputMap.has_action(actionName):
		InputMap.add_action(actionName)
	for keycode: Key in keycodes:
		var event     := InputEventKey.new()
		event.keycode  = keycode
		InputMap.action_add_event(actionName, event)


# Converts a flat tile index to atlas (col, row) coordinates.
func tileIndexToAtlasCoords(index: int) -> Vector2i:
	return Vector2i(index % TILESET_WIDTH_TILES, index / TILESET_WIDTH_TILES)


# Converts atlas (col, row) coordinates to a flat tile index.
func atlasCoordsToTileIndex(atlasCoords: Vector2i) -> int:
	return atlasCoords.y * TILESET_WIDTH_TILES + atlasCoords.x


# Returns the zone ID adjacent to zoneId in the given direction,
# or -1 if that direction leads off the edge of the world grid.
# Accepts cardinal and diagonal directions.
func getAdjacentZoneId(zoneId: int, direction: Vector2i) -> int:
	var zoneX := zoneId % ZONE_GRID_WIDTH
	var zoneY := zoneId / ZONE_GRID_WIDTH
	zoneX += direction.x
	zoneY += direction.y
	if zoneX < 0 or zoneX >= ZONE_GRID_WIDTH:
		return -1
	if zoneY < 0 or zoneY >= ZONE_GRID_HEIGHT:
		return -1
	return zoneY * ZONE_GRID_WIDTH + zoneX


# Returns the neighboring zone ID and the edge of that neighbor facing back toward
# the source zone.  Returns an empty Dictionary if the edge leads off the world grid.
# Example: getZoneNeighborByDirection(4, East) → { "zoneId": 5, "edge": West }
func getZoneNeighborByDirection(zoneId: int, edge: Zone.EZoneEdge) -> Dictionary:
	var direction  := _zoneEdgeToDirection(edge)
	var neighborId := getAdjacentZoneId(zoneId, direction)
	if neighborId == -1:
		return {}
	return { "zoneId": neighborId, "edge": _oppositeZoneEdge(edge) }


func _zoneEdgeToDirection(edge: Zone.EZoneEdge) -> Vector2i:
	match edge:
		Zone.EZoneEdge.North:  return Vector2i( 0, -1)
		Zone.EZoneEdge.South:  return Vector2i( 0,  1)
		Zone.EZoneEdge.East:   return Vector2i( 1,  0)
		Zone.EZoneEdge.West:   return Vector2i(-1,  0)
	return Vector2i.ZERO


func _oppositeZoneEdge(edge: Zone.EZoneEdge) -> Zone.EZoneEdge:
	match edge:
		Zone.EZoneEdge.North:  return Zone.EZoneEdge.South
		Zone.EZoneEdge.South:  return Zone.EZoneEdge.North
		Zone.EZoneEdge.East:   return Zone.EZoneEdge.West
		Zone.EZoneEdge.West:   return Zone.EZoneEdge.East
	return Zone.EZoneEdge.Center


# Shakes a Control by snapping it to rapid random offsets within 'radius' px,
# then returning it to its original position when the duration expires.
static func shakeControl(control: Control, radius: float, duration: float) -> void:
	var origin   := control.position
	var steps    := maxi(int(duration / 0.04), 2)
	var interval := duration / steps
	var tween    := control.create_tween()
	for i in steps:
		var offset := Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		tween.tween_callback(func(): control.position = origin + offset)
		tween.tween_interval(interval)
	tween.tween_callback(func(): control.position = origin)
