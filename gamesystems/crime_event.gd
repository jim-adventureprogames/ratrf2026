class_name CrimeEvent
extends RefCounted

static var _nextId: int = 0

# Case number — unique, assigned at construction.
var id: int = -1

# Where the event took place (x/y = tile, z = zone ID).
var location: Vector3i

# When, in game turns.
var time: int

# Which entity was the victim.
var victimID: int

# Which entity was the perp? Almost always the player, but maybe not.
var perpID: int

# IDs of stolen items that are unique (bUnique = true).
var uniqueStolenGoods: Array[int]

# Archetypes of stolen items that stack (bUnique = false).
var regularStolenGoodArchetypes: Array[String]

# How far from the crime tile this event was detectable, in tiles.
var detectionRadius: float


func _init() -> void:
	id              = CrimeEvent._nextId
	CrimeEvent._nextId += 1
