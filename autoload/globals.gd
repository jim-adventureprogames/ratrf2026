extends Node

enum EMoveTestResult {
	OK,
	Wall,
	Entity,
}

enum EFacing {
	Up,
	Right,
	Down,
	Left,
}

const TILE_SIZE              := 12
const TILESET_WIDTH_TILES    := 23   # world.png is 276px wide  (276 / 12)
const TILESET_HEIGHT_TILES   := 11   # world.png is 132px tall  (132 / 12)

const ZONE_WIDTH_TILES  := 20
const ZONE_HEIGHT_TILES := 20
const ZONE_PIXEL_WIDTH  := TILE_SIZE * ZONE_WIDTH_TILES   # 240
const ZONE_PIXEL_HEIGHT := TILE_SIZE * ZONE_HEIGHT_TILES  # 240

const UI_PANEL_X        := ZONE_PIXEL_WIDTH               # 240 — right panel starts here
const UI_PANEL_WIDTH    := 80                             # 320 - 240

const ZONE_GRID_WIDTH   := 5
const ZONE_GRID_HEIGHT  := 5
const ZONE_COUNT        := ZONE_GRID_WIDTH * ZONE_GRID_HEIGHT
# Integer division gives centre index: (5*5-1)/2 = 12
const STARTING_ZONE     := ZONE_GRID_WIDTH * (ZONE_GRID_HEIGHT / 2) + (ZONE_GRID_WIDTH / 2)


func _ready() -> void:
	initializeInputActions()


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
