class_name PathWaypoint
extends RefCounted

# Auto-incrementing global counter — gives each waypoint a stable unique ID
# that prevId/nextId can reference without holding object references.
static var _nextId: int = 0

# Unique ID for this waypoint.
var id:       int

# Tile-coordinate position within the zone.
var position: Vector2i

# Zone this waypoint belongs to.
var zoneId:   int = -1

# IDs of the adjacent waypoints along the path chain.
# -1 means no connection in that direction.
var nextId:      int  = -1
var prevId:      int  = -1

# True for waypoints that form a closed patrol loop within a single zone
# (created by WorldGenerator.buildZonePatrolRoute).  Guards filter on this
# so they don't accidentally start following a cross-zone transition chain.
var bPatrolLoop: bool = false


func _init(pos: Vector2i, zone: int) -> void:
	id       = PathWaypoint._nextId
	PathWaypoint._nextId += 1
	position = pos
	zoneId   = zone
