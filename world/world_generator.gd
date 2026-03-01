class_name WorldGenerator
extends RefCounted

# ── Constants ───────────────────────────────────────────────────────────────────

# How many tiles inset from each zone edge the perimeter wall sits.
# A value of 4 means the wall tile is at index 4 (zero-based), leaving
# tiles 0-3 as an outer margin and tiles 5+ as interior space.
const WALL_INSET := 4

# Width of entrance_gate_north.tmx in tiles.
const NORTH_GATE_WIDTH := 8

# The TMX row inside entrance_gate_north.tmx that contains the opening/pillars.
# The gate is authored so row 2 is the structural wall row, meaning we stamp
# the TMX with topLeft.y = wallY - NORTH_GATE_WALL_ROW so that row 2 lands
# exactly on the wall tile line.
const NORTH_GATE_WALL_ROW := 2


# ── Public entry point ──────────────────────────────────────────────────────────

static func generateWorld() -> void:
	seed(Time.get_ticks_msec())
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


# ── Gate placement ──────────────────────────────────────────────────────────────

static func _placeNorthGate() -> void:
	# Choose a random zone along the north wall, excluding the two corner zones
	# (zoneX 0 and ZONE_GRID_WIDTH-1) so there is always solid wall at the corners.
	var gateZoneX := randi_range(1, Globals.ZONE_GRID_WIDTH - 2)

	# Choose a random x so the gate sits fully inside the zone with at least
	# one wall tile intact on each side (hence the +1/-1 margin).
	var gateX := randi_range(1, Globals.ZONE_WIDTH_TILES - NORTH_GATE_WIDTH - 1)

	# Offset the topLeft.y upward so that the gate's structural row
	# (NORTH_GATE_WALL_ROW) lands exactly on the wall tile line.
	var gateY := WALL_INSET - NORTH_GATE_WALL_ROW

	MapManager.stampTmx("entrance_gate_north.tmx", Vector3i(gateX, gateY, gateZoneX))
