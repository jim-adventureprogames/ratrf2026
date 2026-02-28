class_name ZoneGenerator
extends RefCounted

# Flat index of the base grass tile at atlas (4, 4)
const GRASS_GROUND_INDEX := 4 * 23 + 4  # = 96

static func generateZone(zone: Zone) -> void:
	zone.initializeTiles()
	for tile: Tile in zone.tiles:
		tile.ground = GRASS_GROUND_INDEX
		if randf() < MapManager.grassSettings.grassDecorationChance:
			tile.groundDecoration = MapManager.pickGrassDecoration()
