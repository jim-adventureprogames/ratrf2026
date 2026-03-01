class_name WorldGenerator
extends RefCounted

# ── Constants ───────────────────────────────────────────────────────────────────

# How many tiles inset from each zone edge the perimeter wall sits.
# A value of 4 means the wall tile is at index 4 (zero-based), leaving
# tiles 0-3 as an outer margin and tiles 5+ as interior space.
const WALL_INSET := 4

# All four gate TMX files are 8×8 tiles.
const GATE_SIZE := 8

# For north/south gates: the row index inside the TMX that sits on the wall line.
# For east/west gates:   the col index inside the TMX that sits on the wall line.
# Stamp offset = wallCoord - GATE_WALL_ROW/COL so the structural row/col lands
# exactly on the perimeter wall.
const NORTH_GATE_WALL_ROW := 2
const SOUTH_GATE_WALL_ROW := 5
const EAST_GATE_WALL_COL  := 5
const WEST_GATE_WALL_COL  := 2


# ── Public entry point ──────────────────────────────────────────────────────────

static func generateWorld() -> void:
	seed(Time.get_ticks_msec())

	# Pick a random grid size within the configured bounds and publish to Globals
	# so every other system reads the live values for this session.
	var settings := MapManager.worldSettings
	Globals.ZONE_GRID_WIDTH  = randi_range(settings.zoneGridMinWidth,  settings.zoneGridMaxWidth)
	Globals.ZONE_GRID_HEIGHT = randi_range(settings.zoneGridMinHeight, settings.zoneGridMaxHeight)
	Globals.ZONE_COUNT       = Globals.ZONE_GRID_WIDTH * Globals.ZONE_GRID_HEIGHT
	Globals.STARTING_ZONE    = Globals.ZONE_GRID_WIDTH  * (Globals.ZONE_GRID_HEIGHT / 2) \
							 + Globals.ZONE_GRID_WIDTH  / 2

	MapManager.zones.resize(Globals.ZONE_COUNT)
	for i in Globals.ZONE_COUNT:
		var zone          := Zone.new()
		zone.id            = i
		zone.friendlyName  = "Zone %d" % i
		zone.region        = "The Faire Grounds"
		ZoneGenerator.generateZone(zone)
		MapManager.zones[i] = zone

	_buildPerimeterWall()


# ── Wall construction ───────────────────────────────────────────────────────────

static func _buildPerimeterWall() -> void:
	# The wall forms a rectangle around the entire faire.  Each side runs
	# through one row or column of zones at a fixed inset from the zone edge.
	#
	# World layout (5×5 example, each cell = one zone):
	#
	#   [0][1][2][3][4]   ← north row  (wall at y = WALL_INSET)
	#   [5][6][7][8][9]
	#   ...
	#   [20][21][22][23][24]  ← south row (wall at y = wallFarY)
	#
	# Left column  = zone IDs 0, 5, 10, 15, 20  (wall at x = WALL_INSET)
	# Right column = zone IDs 4, 9, 14, 19, 24  (wall at x = wallFarX)
	#
	# Corner zones belong to BOTH a row pass and a column pass.  To avoid a
	# "+" cross at the corners, each segment is clipped so it starts/ends
	# exactly at the corner point rather than running past it.

	var wallFarX := Globals.ZONE_WIDTH_TILES  - 1 - WALL_INSET  # 15
	var wallFarY := Globals.ZONE_HEIGHT_TILES - 1 - WALL_INSET  # 15

	# ── Horizontal walls (north and south) ─────────────────────────────────────
	# Iterate every zone in the top row (north) and bottom row (south).
	# In corner zones the horizontal segment is clipped on the relevant side:
	#   - Left-edge zone:  wall starts at WALL_INSET (not 0) so it doesn't
	#     extend into the area left of the west vertical wall.
	#   - Right-edge zone: wall ends at wallFarX (not ZONE_WIDTH_TILES-1) so it
	#     doesn't extend past the east vertical wall.
	# Non-corner zones run the full zone width (x = 0 .. ZONE_WIDTH_TILES-1).
	for zoneX in Globals.ZONE_GRID_WIDTH:
		var northId := zoneX
		var southId := (Globals.ZONE_GRID_HEIGHT - 1) * Globals.ZONE_GRID_WIDTH + zoneX

		var wallLeft  := WALL_INSET                    if zoneX == 0                          else 0
		var wallRight := wallFarX                      if zoneX == Globals.ZONE_GRID_WIDTH - 1 else Globals.ZONE_WIDTH_TILES - 1

		MapManager.fillWallRect(
			Vector2i(wallLeft, WALL_INSET), Vector2i(wallRight, WALL_INSET),
			northId, MapDataInfo.EWallColor.light_blue)
		MapManager.fillWallRect(
			Vector2i(wallLeft, wallFarY), Vector2i(wallRight, wallFarY),
			southId, MapDataInfo.EWallColor.light_blue)

	# ── Vertical walls (west and east) ─────────────────────────────────────────
	# Iterate every zone in the left column (west) and right column (east).
	# Same clipping logic, now in the vertical axis:
	#   - Top-edge zone:    wall starts at WALL_INSET (not 0) — corner already
	#     placed by the horizontal pass above.
	#   - Bottom-edge zone: wall ends at wallFarY (not ZONE_HEIGHT_TILES-1).
	# Non-corner column zones run the full zone height (y = 0 .. ZONE_HEIGHT_TILES-1).
	for zoneY in Globals.ZONE_GRID_HEIGHT:
		var westId := zoneY * Globals.ZONE_GRID_WIDTH
		var eastId := zoneY * Globals.ZONE_GRID_WIDTH + (Globals.ZONE_GRID_WIDTH - 1)

		var wallTop    := WALL_INSET                     if zoneY == 0                           else 0
		var wallBottom := wallFarY                       if zoneY == Globals.ZONE_GRID_HEIGHT - 1 else Globals.ZONE_HEIGHT_TILES - 1

		MapManager.fillWallRect(
			Vector2i(WALL_INSET, wallTop), Vector2i(WALL_INSET, wallBottom),
			westId, MapDataInfo.EWallColor.light_blue)
		MapManager.fillWallRect(
			Vector2i(wallFarX, wallTop), Vector2i(wallFarX, wallBottom),
			eastId, MapDataInfo.EWallColor.light_blue)

	_placeNorthGate()
	_placeSouthGate()
	_placeEastGate()
	_placeWestGate()


# ── Gate placement ──────────────────────────────────────────────────────────────

static func _placeNorthGate() -> void:
	# Avoid the two corner zones so there is always solid wall at the corners.
	var gateZoneX := randi_range(1, Globals.ZONE_GRID_WIDTH - 2)
	# Random x — gate fits fully inside the zone with one tile of wall on each side.
	var gateX     := randi_range(1, Globals.ZONE_WIDTH_TILES - GATE_SIZE - 1)
	# Shift up so NORTH_GATE_WALL_ROW lands on the wall tile line (y = WALL_INSET).
	var gateY     := WALL_INSET - NORTH_GATE_WALL_ROW
	MapManager.stampTmx("entrance_gate_north.tmx", Vector3i(gateX, gateY, gateZoneX))


static func _placeSouthGate() -> void:
	var gateZoneX := randi_range(1, Globals.ZONE_GRID_WIDTH - 2)
	var gateX     := randi_range(1, Globals.ZONE_WIDTH_TILES - GATE_SIZE - 1)
	# Shift down so SOUTH_GATE_WALL_ROW lands on the south wall line (y = wallFarY).
	var wallFarY  := Globals.ZONE_HEIGHT_TILES - 1 - WALL_INSET
	var gateY     := wallFarY - SOUTH_GATE_WALL_ROW
	var zoneId    := (Globals.ZONE_GRID_HEIGHT - 1) * Globals.ZONE_GRID_WIDTH + gateZoneX
	MapManager.stampTmx("entrance_gate_south.tmx", Vector3i(gateX, gateY, zoneId))


static func _placeEastGate() -> void:
	# Avoid the two corner zones (zoneY 0 and ZONE_GRID_HEIGHT-1).
	var gateZoneY := randi_range(1, Globals.ZONE_GRID_HEIGHT - 2)
	# Random y — gate fits fully inside the zone with one tile of wall on each side.
	var gateY     := randi_range(1, Globals.ZONE_HEIGHT_TILES - GATE_SIZE - 1)
	# Shift right so EAST_GATE_WALL_COL lands on the east wall line (x = wallFarX).
	var wallFarX  := Globals.ZONE_WIDTH_TILES - 1 - WALL_INSET
	var gateX     := wallFarX - EAST_GATE_WALL_COL
	var zoneId    := gateZoneY * Globals.ZONE_GRID_WIDTH + (Globals.ZONE_GRID_WIDTH - 1)
	MapManager.stampTmx("entrance_gate_east.tmx", Vector3i(gateX, gateY, zoneId))


static func _placeWestGate() -> void:
	var gateZoneY := randi_range(1, Globals.ZONE_GRID_HEIGHT - 2)
	var gateY     := randi_range(1, Globals.ZONE_HEIGHT_TILES - GATE_SIZE - 1)
	# Shift left so WEST_GATE_WALL_COL lands on the west wall line (x = WALL_INSET).
	var gateX     := WALL_INSET - WEST_GATE_WALL_COL
	var zoneId    := gateZoneY * Globals.ZONE_GRID_WIDTH
	MapManager.stampTmx("entrance_gate_west.tmx", Vector3i(gateX, gateY, zoneId))


# ── Procedural decoration ───────────────────────────────────────────────────────

# Scatters dirt decorations across a square area centred on `center`.
# `radius` controls the half-extent: radius=1 gives a 3×3 square, radius=2
# gives a 5×5 square, and so on.
# The centre tile always receives a decoration.  Every surrounding tile rolls
# against grassSettings.dirtDecorationChance for its decoration.
# Tiles outside the zone bounds are silently skipped.
static func dirtalizeSection(center: Vector3i, radius: int) -> void:
	var chance := MapManager.grassSettings.dirtDecorationChance
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos  := Vector3i(center.x + dx, center.y + dy, center.z)
			var tile := MapManager.getTileAt(pos)
			if tile == null:
				continue
			var isCenter := dx == 0 and dy == 0
			if isCenter or randf() < chance:
				var decoration := MapManager.pickDirtDecoration()
				if decoration != Tile.EMPTY_TILE:
					tile.groundDecoration = decoration
