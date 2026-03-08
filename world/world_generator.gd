class_name WorldGenerator
extends RefCounted

# ── Constants ───────────────────────────────────────────────────────────────────

# How many tiles inset from each zone edge the perimeter wall sits.
# A value of 4 means the wall tile is at index 4 (zero-based), leaving
# tiles 0-3 as an outer margin and tiles 5+ as interior space.
const WALL_INSET      := 4

# How many tiles inward from the interior-facing edge of a border zone the
# center-region fence wall is placed.
const CENTER_FENCE_INSET := 12

# How many tiles inward from a zone edge a path waypoint is placed.
# Keeps waypoints off the very boundary so they land on walkable ground.
const WAYPOINT_INSET  := 2

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

	_initZoneAStar()

	MapManager.zones.resize(Globals.ZONE_COUNT)
	for i in Globals.ZONE_COUNT:
		var zone          := Zone.new()
		zone.id            = i
		zone.friendlyName  = "Zone %d" % i
		zone.region        = Zone.EZoneRegion.Center
		ZoneGenerator.generateZone(zone)
		MapManager.zones[i] = zone

	var gateZones := _buildPerimeterWall()
	# Publish gate zone IDs so GameManager can spawn gate-adjacent NPCs.
	for zoneKey in gateZones:
		MapManager.gateZoneIds.append(gateZones[zoneKey])
	_assignZoneRegions(gateZones)
	_buildCenterFence()

	_buildDirtPaths(gateZones)
	_stampPennants()
	_stampBuildings()

	# Patrol routes are built after all buildings are stamped so that waypoints
	# spawned by building TMXes are already registered and can join the loop.
	for i in Globals.ZONE_COUNT:
		buildZonePatrolRoute(i)

	# Build tile-level A* graphs for every zone now that all tile data is final.
	# Interior zones that received no fillWallRect or stampTmx calls are covered here.
	for i in Globals.ZONE_COUNT:
		MapManager.buildZoneAStarGraph(i)


# ── Pennant placement ───────────────────────────────────────────────────────────

# Places two deco_pennants in every zone that has a dirtalized path.
# Pennant direction is chosen by the zone's EZoneRegion.
# Candidates must be grass tiles that border 1–2 dirt tiles (roadside, not
# road-centre) and are not already occupied by another entity.
static func _stampPennants() -> void:
	for zone: Zone in MapManager.zones:
		if zone.dirtalizedEdges.is_empty():
			continue
		_placeZonePennants(zone)


static func _placeZonePennants(zone: Zone) -> void:
	var prefabName := _pennantPrefabForRegion(zone.region)

	# Collect every grass tile that is roadside but not road-centre.
	var candidates: Array[Vector2i] = []
	for y in Globals.ZONE_HEIGHT_TILES:
		for x in Globals.ZONE_WIDTH_TILES:
			var tile := zone.getTile(x, y)
			if not _isGrassTile(tile):
				continue
			if not tile.entities.is_empty():
				continue
			var dirtCount := _countDirtCardinalNeighbors(zone, x, y)
			if dirtCount >= 1 and dirtCount <= 2:
				candidates.append(Vector2i(x, y))

	candidates.shuffle()
	var placed := 0
	for pos: Vector2i in candidates:
		if placed >= 2:
			break
		TmxStamper.spawnEntityFromPrefab(prefabName, Vector3i(pos.x, pos.y, zone.id))
		placed += 1


# Returns the prefab name for the pennant that matches a zone region.
# Center zones pick randomly among the four directions.
static func _pennantPrefabForRegion(region: Zone.EZoneRegion) -> String:
	match region:
		Zone.EZoneRegion.North: return "deco_pennant_north"
		Zone.EZoneRegion.South: return "deco_pennant_south"
		Zone.EZoneRegion.East:  return "deco_pennant_east"
		Zone.EZoneRegion.West:  return "deco_pennant_west"
	var options := ["deco_pennant_north", "deco_pennant_south",
					"deco_pennant_east",  "deco_pennant_west"]
	return options[randi() % 4]


# Returns true if the tile is bare grass — not a wall, not a dirt-path tile.
static func _isGrassTile(tile: Tile) -> bool:
	if tile == null or tile.wall != Tile.EMPTY_TILE:
		return false
	if tile.ground != ZoneGenerator.GRASS_GROUND_INDEX:
		return false
	for entry: TileDecorationEntry in MapManager.grassSettings.dirtDecorations:
		if tile.groundDecoration == entry.tileId:
			return false
	return true


# Counts how many of the four cardinal neighbors are dirt-path tiles.
static func _countDirtCardinalNeighbors(zone: Zone, x: int, y: int) -> int:
	var count := 0
	for dir: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbor := zone.getTile(x + dir.x, y + dir.y)
		if neighbor == null:
			continue
		for entry: TileDecorationEntry in MapManager.grassSettings.dirtDecorations:
			if neighbor.groundDecoration == entry.tileId:
				count += 1
				break
	return count


# ── Building placement ──────────────────────────────────────────────────────────

# Iterates every zone and fills it with buildings from the appropriate array:
#   • Dirtalized zones  → roadsideBuildingArray  (multiple buildings encouraged)
#   • Undirtalized zones → emptyAreaBuildingArray (one building per zone)
# Skips zones whose building array is empty.
static func _stampBuildings() -> void:
	var settings := MapManager.worldSettings
	for zone: Zone in MapManager.zones:
		var bRoadside := not zone.dirtalizedEdges.is_empty()
		var buildingArray: Array[String] = settings.roadsideBuildingArray \
				if bRoadside else settings.emptyAreaBuildingArray
		if buildingArray.is_empty():
			continue
		var bounds := _getFaireInteriorBounds(zone.id)
		_fillZoneWithBuildings(zone.id, buildingArray, bounds, bRoadside)


# Tries to place at least one building in the zone (guaranteed attempt by
# shuffling the full array).  Roadside zones keep filling until no building
# from the array fits on the first try for every entry consecutively.
static func _fillZoneWithBuildings(zoneId: int, buildingArray: Array[String],
		bounds: Rect2i, bRoadside: bool) -> void:
	# Shuffle and try every building once to land the first guaranteed placement.
	var shuffled: Array[String] = buildingArray.duplicate()
	shuffled.shuffle()
	var placed := 0
	for tmxName: String in shuffled:
		if _stampBuildingInZone(tmxName, zoneId, bounds):
			placed += 1
			break

	if placed == 0 or not bRoadside:
		return

	# Roadside zones keep filling.  Give up after buildingArray.size() consecutive
	# failures — at that point the zone is effectively full.
	var consecutiveFails := 0
	while consecutiveFails < buildingArray.size():
		var tmxName := buildingArray[randi() % buildingArray.size()]
		if _stampBuildingInZone(tmxName, zoneId, bounds):
			consecutiveFails = 0
		else:
			consecutiveFails += 1


# Reads the TMX dimensions, finds a clear non-dirtalized spot inside the faire
# walls, and stamps it.  Returns true on success, false if no space was found.
static func _stampBuildingInZone(tmxName: String, zoneId: int, bounds: Rect2i) -> bool:
	var size := TmxStamper.getTmxSize(tmxName)
	if size.x < 0:
		push_warning("WorldGenerator: could not read TMX size for '%s'" % tmxName)
		return false
	var topLeft := MapManager.findClearRectInZone(zoneId, size.x, size.y, bounds)
	if topLeft.x < 0:
		return false
	TmxStamper.stampTmx(tmxName, Vector3i(topLeft.x, topLeft.y, zoneId))
	_reserveBuildingFootprint(topLeft, size, zoneId)
	return true


# Marks every tile in the building's footprint as reserved so that
# findClearRectInZone will not place another building on top of it.
static func _reserveBuildingFootprint(topLeft: Vector2i, size: Vector2i, zoneId: int) -> void:
	for y in range(topLeft.y, topLeft.y + size.y):
		for x in range(topLeft.x, topLeft.x + size.x):
			var tile := MapManager.getTileAt(Vector3i(x, y, zoneId))
			if tile:
				tile.bReserved = true


# Returns the Rect2i (tile coords, inclusive) of the playable area inside the
# faire walls for the given zone.  Edge zones are clipped one tile inside the
# perimeter wall on their outer sides; interior zones span the full zone.
static func _getFaireInteriorBounds(zoneId: int) -> Rect2i:
	var gridX    := zoneId % Globals.ZONE_GRID_WIDTH
	var gridY    := zoneId / Globals.ZONE_GRID_WIDTH
	var wallFarX := Globals.ZONE_WIDTH_TILES  - 1 - WALL_INSET
	var wallFarY := Globals.ZONE_HEIGHT_TILES - 1 - WALL_INSET
	var minX := (WALL_INSET + 1) if gridX == 0                           else 0
	var minY := (WALL_INSET + 1) if gridY == 0                           else 0
	var maxX := (wallFarX - 1)   if gridX == Globals.ZONE_GRID_WIDTH  - 1 else Globals.ZONE_WIDTH_TILES  - 1
	var maxY := (wallFarY - 1)   if gridY == Globals.ZONE_GRID_HEIGHT - 1 else Globals.ZONE_HEIGHT_TILES - 1
	return Rect2i(minX, minY, maxX - minX + 1, maxY - minY + 1)


# ── Zone region assignment ──────────────────────────────────────────────────────

# Assigns EZoneRegion to every zone using a two-pass approach:
#   1. The 3×3 block centered on the grid mid-point → EZoneRegion.Center.
#   2. All remaining zones → whichever gate is nearest (Voronoi by squared
#      Euclidean distance in grid coordinates).
static func _assignZoneRegions(gateZones: Dictionary) -> void:
	var centerGX := Globals.ZONE_GRID_WIDTH  / 2
	var centerGY := Globals.ZONE_GRID_HEIGHT / 2

	# Build a mapping from EZoneRegion → gate grid position (Vector2i).
	var seeds: Dictionary = {}
	for key: String in gateZones:
		var gateId   := gateZones[key] as int
		var gateGrid := Vector2i(gateId % Globals.ZONE_GRID_WIDTH, gateId / Globals.ZONE_GRID_WIDTH)
		match key:
			"north": seeds[Zone.EZoneRegion.North] = gateGrid
			"south": seeds[Zone.EZoneRegion.South] = gateGrid
			"east":  seeds[Zone.EZoneRegion.East]  = gateGrid
			"west":  seeds[Zone.EZoneRegion.West]  = gateGrid

	for zone: Zone in MapManager.zones:
		var gridX := zone.id % Globals.ZONE_GRID_WIDTH
		var gridY := zone.id / Globals.ZONE_GRID_WIDTH

		# 3×3 centre block.
		if abs(gridX - centerGX) <= 1 and abs(gridY - centerGY) <= 1:
			zone.region = Zone.EZoneRegion.Center
			continue

		# Outer zones: Voronoi — assign to the nearest gate region.
		var bestRegion := Zone.EZoneRegion.Center
		var bestDistSq := INF
		for region in seeds:
			var seed: Vector2i = seeds[region]
			var dx    := float(gridX - seed.x)
			var dy    := float(gridY - seed.y)
			var distSq := dx * dx + dy * dy
			if distSq < bestDistSq:
				bestDistSq = distSq
				bestRegion = region
		zone.region = bestRegion


# ── Zone AStar ──────────────────────────────────────────────────────────────────

# Configures the zone-level AStar grid.  Must be called after grid dimensions
# are set in generateWorld().  Each cell is one zone; diagonal movement disabled.
static func _initZoneAStar() -> void:
	MapManager.zoneAStar.region        = Rect2i(0, 0, Globals.ZONE_GRID_WIDTH, Globals.ZONE_GRID_HEIGHT)
	MapManager.zoneAStar.cell_size     = Vector2(1, 1)
	MapManager.zoneAStar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	MapManager.zoneAStar.update()


# Converts a zone ID to its grid position in the AStar grid.
static func _zoneIdToGrid(zoneId: int) -> Vector2i:
	return Vector2i(zoneId % Globals.ZONE_GRID_WIDTH, zoneId / Globals.ZONE_GRID_WIDTH)


# Converts a Vector2i movement direction to the ZoneEdge it entered from.
# e.g. moving East (1,0) means we entered via the West edge.
static func _directionToEntryEdge(dir: Vector2i) -> Zone.EZoneEdge:
	match dir:
		Vector2i( 0, -1): return Zone.EZoneEdge.South  # moved North → entered from South
		Vector2i( 0,  1): return Zone.EZoneEdge.North  # moved South → entered from North
		Vector2i( 1,  0): return Zone.EZoneEdge.West   # moved East  → entered from West
		Vector2i(-1,  0): return Zone.EZoneEdge.East   # moved West  → entered from East
	return Zone.EZoneEdge.Center


# Converts a Vector2i movement direction to the ZoneEdge we are exiting through.
# e.g. moving East (1,0) means we leave via the East edge.
static func _directionToExitEdge(dir: Vector2i) -> Zone.EZoneEdge:
	match dir:
		Vector2i( 0, -1): return Zone.EZoneEdge.North
		Vector2i( 0,  1): return Zone.EZoneEdge.South
		Vector2i( 1,  0): return Zone.EZoneEdge.East
		Vector2i(-1,  0): return Zone.EZoneEdge.West
	return Zone.EZoneEdge.Center


# Traces an AStar path between two zones and draws a dirtalized trail through
# every zone along the route.  The start zone gets Center→exit, the end zone
# gets entry→Center, and every intermediate zone gets entry→exit.
static func dirtalizeZonePath(startZoneId: int, endZoneId: int, radius: int) -> void:
	var path := MapManager.zoneAStar.get_point_path(
		_zoneIdToGrid(startZoneId), _zoneIdToGrid(endZoneId))
	if path.is_empty():
		return

	var prevExitWp: PathWaypoint = null

	for i in path.size():
		var gridPos := Vector2i(int(path[i].x), int(path[i].y))
		var zoneId  := gridPos.y * Globals.ZONE_GRID_WIDTH + gridPos.x

		var entryEdge := Zone.EZoneEdge.Center
		var exitEdge  := Zone.EZoneEdge.Center

		if i > 0:
			var prevGrid := Vector2i(int(path[i - 1].x), int(path[i - 1].y))
			entryEdge    = _directionToEntryEdge(gridPos - prevGrid)

		if i < path.size() - 1:
			var nextGrid := Vector2i(int(path[i + 1].x), int(path[i + 1].y))
			exitEdge     = _directionToExitEdge(nextGrid - gridPos)

		var zoneWaypoints := dirtalizePathInZone(zoneId, entryEdge, exitEdge, radius)
		var entryWp := zoneWaypoints.get("entry") as PathWaypoint
		var exitWp  := zoneWaypoints.get("exit")  as PathWaypoint

		# Stitch the cross-zone link: previous zone's exit → this zone's entry.
		if prevExitWp != null and entryWp != null:
			prevExitWp.nextId = entryWp.id
			entryWp.prevId    = prevExitWp.id

		prevExitWp = exitWp


# ── Wall construction ───────────────────────────────────────────────────────────

static func _buildPerimeterWall() -> Dictionary:
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

	return {
		"north": _placeNorthGate(),
		"south": _placeSouthGate(),
		"east":  _placeEastGate(),
		"west":  _placeWestGate(),
	}


# Draws a purple fence wall around the 3×3 EZoneRegion.Center block.
# The wall runs along the outer edges of the center 3×3 region, placed
# CENTER_FENCE_INSET tiles from the outer edge of each border center zone.
# Corner zones receive both a horizontal and a vertical segment that share
# exactly one corner tile, matching the same clipping logic as _buildPerimeterWall.
# Requires at least 3 zones in both dimensions — skipped on smaller grids.
static func _buildCenterFence() -> void:
	if Globals.ZONE_GRID_WIDTH < 3 or Globals.ZONE_GRID_HEIGHT < 3:
		return

	var cGX := Globals.ZONE_GRID_WIDTH  / 2
	var cGY := Globals.ZONE_GRID_HEIGHT / 2

	# Wall coordinate on each axis, measured from the outer edge of each zone.
	# fenceX/Y    = near the western/northern edge of border center zones.
	# fenceFarX/Y = near the eastern/southern edge of border center zones.
	var fenceX    := CENTER_FENCE_INSET
	var fenceFarX := Globals.ZONE_WIDTH_TILES  - 1 - CENTER_FENCE_INSET
	var fenceY    := CENTER_FENCE_INSET
	var fenceFarY := Globals.ZONE_HEIGHT_TILES - 1 - CENTER_FENCE_INSET

	# ── Horizontal walls (top and bottom rows of the center block) ──────────────
	# Placed inside zones at gridY = cGY-1 (y=fenceY) and gridY = cGY+1 (y=fenceFarY).
	# Corner zones clip so the horizontal wall begins/ends at the vertical fence
	# tile, preventing a cross artifact at each corner.
	for gridX in range(cGX - 1, cGX + 2):
		var northId := (cGY - 1) * Globals.ZONE_GRID_WIDTH + gridX
		var southId := (cGY + 1) * Globals.ZONE_GRID_WIDTH + gridX

		var wallLeft  := fenceX    if gridX == cGX - 1 else 0
		var wallRight := fenceFarX if gridX == cGX + 1 else Globals.ZONE_WIDTH_TILES - 1

		MapManager.fillWallRect(
			Vector2i(wallLeft, fenceY), Vector2i(wallRight, fenceY),
			northId, MapDataInfo.EWallColor.purple)
		MapManager.fillWallRect(
			Vector2i(wallLeft, fenceFarY), Vector2i(wallRight, fenceFarY),
			southId, MapDataInfo.EWallColor.purple)

	# ── Vertical walls (left and right columns of the center block) ─────────────
	# Placed inside zones at gridX = cGX-1 (x=fenceX) and gridX = cGX+1 (x=fenceFarX).
	# Corner clipping: vertical walls start/end at the tile shared with the
	# horizontal wall, not at the zone boundary.
	for gridY in range(cGY - 1, cGY + 2):
		var westId := gridY * Globals.ZONE_GRID_WIDTH + (cGX - 1)
		var eastId := gridY * Globals.ZONE_GRID_WIDTH + (cGX + 1)

		var wallTop    := fenceY    if gridY == cGY - 1 else 0
		var wallBottom := fenceFarY if gridY == cGY + 1 else Globals.ZONE_HEIGHT_TILES - 1

		MapManager.fillWallRect(
			Vector2i(fenceX, wallTop), Vector2i(fenceX, wallBottom),
			westId, MapDataInfo.EWallColor.purple)
		MapManager.fillWallRect(
			Vector2i(fenceFarX, wallTop), Vector2i(fenceFarX, wallBottom),
			eastId, MapDataInfo.EWallColor.purple)

	# Exclude the exact centre zone from zone-level pathfinding so dirt paths
	# between gates route around the fenced interior rather than cutting through it.
	MapManager.zoneAStar.set_point_solid(Vector2i(cGX, cGY), true)


# ── Gate placement ──────────────────────────────────────────────────────────────

static func _placeNorthGate() -> int:
	# Avoid the two corner zones so there is always solid wall at the corners.
	var gateZoneX := randi_range(1, Globals.ZONE_GRID_WIDTH - 2)
	# Random x — gate fits fully inside the zone with one tile of wall on each side.
	var gateX     := randi_range(1, Globals.ZONE_WIDTH_TILES - GATE_SIZE - 1)
	# Shift up so NORTH_GATE_WALL_ROW lands on the wall tile line (y = WALL_INSET).
	var gateY     := WALL_INSET - NORTH_GATE_WALL_ROW
	TmxStamper.stampTmx("entrance_gate_north.tmx", Vector3i(gateX, gateY, gateZoneX))
	return gateZoneX


static func _placeSouthGate() -> int:
	var gateZoneX := randi_range(1, Globals.ZONE_GRID_WIDTH - 2)
	var gateX     := randi_range(1, Globals.ZONE_WIDTH_TILES - GATE_SIZE - 1)
	# Shift down so SOUTH_GATE_WALL_ROW lands on the south wall line (y = wallFarY).
	var wallFarY  := Globals.ZONE_HEIGHT_TILES - 1 - WALL_INSET
	var gateY     := wallFarY - SOUTH_GATE_WALL_ROW
	var zoneId    := (Globals.ZONE_GRID_HEIGHT - 1) * Globals.ZONE_GRID_WIDTH + gateZoneX
	TmxStamper.stampTmx("entrance_gate_south.tmx", Vector3i(gateX, gateY, zoneId))
	return zoneId


static func _placeEastGate() -> int:
	# Avoid the two corner zones (zoneY 0 and ZONE_GRID_HEIGHT-1).
	var gateZoneY := randi_range(1, Globals.ZONE_GRID_HEIGHT - 2)
	# Random y — gate fits fully inside the zone with one tile of wall on each side.
	var gateY     := randi_range(1, Globals.ZONE_HEIGHT_TILES - GATE_SIZE - 1)
	# Shift right so EAST_GATE_WALL_COL lands on the east wall line (x = wallFarX).
	var wallFarX  := Globals.ZONE_WIDTH_TILES - 1 - WALL_INSET
	var gateX     := wallFarX - EAST_GATE_WALL_COL
	var zoneId    := gateZoneY * Globals.ZONE_GRID_WIDTH + (Globals.ZONE_GRID_WIDTH - 1)
	TmxStamper.stampTmx("entrance_gate_east.tmx", Vector3i(gateX, gateY, zoneId))
	return zoneId


static func _placeWestGate() -> int:
	var gateZoneY := randi_range(1, Globals.ZONE_GRID_HEIGHT - 2)
	var gateY     := randi_range(1, Globals.ZONE_HEIGHT_TILES - GATE_SIZE - 1)
	# Shift left so WEST_GATE_WALL_COL lands on the west wall line (x = WALL_INSET).
	var gateX     := WALL_INSET - WEST_GATE_WALL_COL
	var zoneId    := gateZoneY * Globals.ZONE_GRID_WIDTH
	TmxStamper.stampTmx("entrance_gate_west.tmx", Vector3i(gateX, gateY, zoneId))
	return zoneId


# ── Dirt paths ──────────────────────────────────────────────────────────────────

# Connects the four gate zones with dirtalized paths in clockwise order:
# north → east → south → west → north.
# After all paths are drawn, scores every zone by its distance from the
# nearest dirtalized zone.
# Patrol route building is intentionally deferred to generateWorld() so that
# waypoints stamped from building TMXes are included.
static func _buildDirtPaths(gateZones: Dictionary) -> void:
	var radius := 2
	dirtalizeZonePath(gateZones["north"], gateZones["east"],  radius)
	dirtalizeZonePath(gateZones["east"],  gateZones["south"], radius)
	dirtalizeZonePath(gateZones["south"], gateZones["west"],  radius)
	dirtalizeZonePath(gateZones["west"],  gateZones["north"], radius)
	_determineZoneWilderness()


# Multi-source BFS from every dirtalized zone (wildernessScore == 0).
# Each step away from a dirtalized zone increments the wilderness score by 1.
# Zones unreachable from any path keep their default score of 99.
static func _determineZoneWilderness() -> void:
	var queue: Array[int] = []
	for zone: Zone in MapManager.zones:
		if zone.wildernessScore == 0:
			queue.append(zone.id)

	var cardinals := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var head      := 0
	while head < queue.size():
		var zoneId := queue[head]
		head       += 1
		var zone   := MapManager.getZone(zoneId)
		for dir: Vector2i in cardinals:
			var neighborId := Globals.getAdjacentZoneId(zoneId, dir)
			if neighborId == -1:
				continue
			var neighbor := MapManager.getZone(neighborId)
			if neighbor == null or neighbor.wildernessScore != 99:
				continue
			neighbor.wildernessScore = zone.wildernessScore + 1
			queue.append(neighborId)


# Returns the tile position for a waypoint on the given edge, stepped
# WAYPOINT_INSET tiles inward so it sits on walkable ground, not the boundary.
# Center edge needs no inset — it's already in the middle of the zone.
static func _waypointPosition(zone: Zone, edge: Zone.EZoneEdge) -> Vector2i:
	var p := _resolveZoneEdge(zone, edge)
	match edge:
		Zone.EZoneEdge.North:  return Vector2i(p.x, p.y + WAYPOINT_INSET)
		Zone.EZoneEdge.South:  return Vector2i(p.x, p.y - WAYPOINT_INSET)
		Zone.EZoneEdge.West:   return Vector2i(p.x + WAYPOINT_INSET, p.y)
		Zone.EZoneEdge.East:   return Vector2i(p.x - WAYPOINT_INSET, p.y)
		_:                     return p  # Center: no inset


# Builds a closed patrol loop for a single zone using edges that have a dirt
# path running through them plus any waypoints spawned by TMX stamps in this zone.
# No new dirtalization is performed.
# Zones with neither dirtalized edges nor TMX waypoints get no patrol route.
#
# Edge stops are interleaved with a center visit so guards travel through the
# middle of the zone: Edge → Center → Edge → Center → …
# TMX waypoints (spawn tag "waypoint") are appended after the edge/center stops
# and linked into the same closed loop without an extra center detour.
static func buildZonePatrolRoute(zoneId: int) -> void:
	var zone := MapManager.getZone(zoneId) as Zone
	if zone == null:
		return

	var positions: Array[Vector2i] = []

	# Edge-based stops: each cardinal edge interleaved with the zone center.
	if not zone.dirtalizedEdges.is_empty():
		var centerPos := zone.centerCenter
		for edge in zone.dirtalizedEdges:
			if edge != Zone.EZoneEdge.Center:
				positions.append(_waypointPosition(zone, edge))
				positions.append(centerPos)

	# TMX-spawned waypoints for this zone (spawn tag "waypoint").
	# These are appended directly without a center detour — they mark
	# specific interior points such as vendor stalls or building corners.
	var tmxWaypoints: Array = MapManager.spawnPoints.get("waypoint", [])
	for worldPos: Vector3i in tmxWaypoints:
		if worldPos.z == zoneId:
			positions.append(Vector2i(worldPos.x, worldPos.y))

	if positions.is_empty():
		return

	var wps: Array[PathWaypoint] = []
	for pos in positions:
		var wp        := PathWaypoint.new(pos, zoneId)
		wp.bPatrolLoop = true
		wps.append(wp)
		MapManager.registerWaypoint(wp)

	for i in wps.size():
		var curr := wps[i]
		var next := wps[(i + 1) % wps.size()]
		curr.nextId = next.id
		next.prevId = curr.id


# Draws a drunken dirt path between two named edge points in a zone.
# Half the time the path goes directly from start to end.
# The other half it routes via the zone's centerCenter, producing an L-shaped trail.
# Returns a Dictionary { "entry": PathWaypoint, "exit": PathWaypoint } so the
# caller can stitch cross-zone prevId/nextId links.
static func dirtalizePathInZone(zoneId: int, from: Zone.EZoneEdge, to: Zone.EZoneEdge, radius: int) -> Dictionary:
	var zone := MapManager.getZone(zoneId) as Zone
	if zone == null:
		return {}

	zone.wildernessScore = 0

	# Record which edges this path uses so patrol routes can be built later.
	# Center is included — guards on start/end zones should walk to the center too.
	if not zone.dirtalizedEdges.has(from):
		zone.dirtalizedEdges.append(from)
	if not zone.dirtalizedEdges.has(to):
		zone.dirtalizedEdges.append(to)

	var startPos := _resolveZoneEdge(zone, from)
	var endPos   := _resolveZoneEdge(zone, to)
	var startV3  := Vector3i(startPos.x, startPos.y, zoneId)
	var endV3    := Vector3i(endPos.x,   endPos.y,   zoneId)

	if randf() < 0.5:
		dirtalizeLine(startV3, endV3, radius)
	else:
		var centerV3 := Vector3i(zone.centerCenter.x, zone.centerCenter.y, zoneId)
		dirtalizeLine(startV3, centerV3, radius)
		dirtalizeLine(centerV3, endV3, radius)

	# Place waypoints WAYPOINT_INSET tiles inward from each edge so they land
	# on walkable ground.  Connect them within the zone, then return them so
	# dirtalizeZonePath can stitch the cross-zone chain.
	var entryWp := PathWaypoint.new(_waypointPosition(zone, from), zoneId)
	var exitWp  := PathWaypoint.new(_waypointPosition(zone, to),   zoneId)
	entryWp.nextId = exitWp.id
	exitWp.prevId  = entryWp.id
	MapManager.registerWaypoint(entryWp)
	MapManager.registerWaypoint(exitWp)

	return { "entry": entryWp, "exit": exitWp }


static func _resolveZoneEdge(zone: Zone, edge: Zone.EZoneEdge) -> Vector2i:
	match edge:
		Zone.EZoneEdge.North:   return zone.northCenter
		Zone.EZoneEdge.South:   return zone.southCenter
		Zone.EZoneEdge.East:    return zone.eastCenter
		Zone.EZoneEdge.West:    return zone.westCenter
		Zone.EZoneEdge.Center:  return zone.centerCenter
	return zone.centerCenter


# ── Procedural decoration ───────────────────────────────────────────────────────

# Scatters dirt decorations across a square area centred on `center`.
# `radius` controls the half-extent: radius=1 gives a 3×3 square, radius=2
# gives a 5×5 square, and so on.
# The centre tile always receives a decoration.  Every surrounding tile rolls
# against grassSettings.dirtalizeGroundNotCenterChance for its decoration.
# Tiles outside the zone bounds or not on base grass are silently skipped.
static func dirtalizeSection(center: Vector3i, radius: int) -> void:
	var chance := MapManager.grassSettings.dirtalizeGroundNotCenterChance
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var pos  := Vector3i(center.x + dx, center.y + dy, center.z)
			var tile := MapManager.getTileAt(pos)
			if tile == null or tile.ground != ZoneGenerator.GRASS_GROUND_INDEX:
				continue
			var isCenter := dx == 0 and dy == 0
			if isCenter or randf() < chance:
				var decoration := MapManager.pickDirtDecoration()
				if decoration != Tile.EMPTY_TILE:
					tile.groundDecoration = decoration


# Drunken-walks from start to end, calling dirtalizeSection at each step.
# The path is biased toward the destination but occasionally stumbles in a
# random cardinal direction, controlled by grassSettings.dirtalizeDriftChance.
# start and end must share the same zone (z value).
# maxSteps is capped at 4× the Manhattan distance to guarantee termination.
static func dirtalizeLine(start: Vector3i, end: Vector3i, radius: int) -> void:
	var current   := start
	var maxSteps  := (int)(abs(end.x - start.x) + abs(end.y - start.y)) * 4
	var steps     := 0
	var driftChance := MapManager.grassSettings.dirtalizeDriftChance

	dirtalizeSection(current, radius)

	while (current.x != end.x or current.y != end.y) and steps < maxSteps:
		steps += 1
		var dx := end.x - current.x
		var dy := end.y - current.y

		var step: Vector2i
		if randf() >= driftChance:
			# Bias toward goal — pick whichever axis has remaining distance.
			# When both axes do, choose randomly between them.
			if dx == 0:
				step = Vector2i(0, sign(dy))
			elif dy == 0:
				step = Vector2i(sign(dx), 0)
			elif randf() < 0.5:
				step = Vector2i(sign(dx), 0)
			else:
				step = Vector2i(0, sign(dy))
		else:
			# Random stumble in any cardinal direction.
			var cardinals := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			step = cardinals[randi() % 4]

		current = Vector3i(current.x + step.x, current.y + step.y, current.z)
		dirtalizeSection(current, radius)
