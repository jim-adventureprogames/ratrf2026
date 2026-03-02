class_name HUDMiniMap
extends Control

static var _instance: HUDMiniMap

# Returns the single HUDMiniMap instance present in the scene.
static func summon() -> HUDMiniMap:
	return _instance


@export var gridMM:              GridContainer
@export var prefabZoneMMObject:  PackedScene

@export var colorDepthMin: Color  # applied to zones with paths (score 0)
@export var colorDepthMax: Color  # applied to zones at maximum wilderness

@export var colorPlayerLocation: Color  # applied to the zone the player currently occupies

# Zone objects indexed by zone ID — populated by populate().
var _zoneObjects:        Array[MMZoneObject] = []
# Base colors for each zone, so we can restore them when the player leaves.
var _zoneColors:         Array[Color]        = []
var _currentPlayerZone:  int                 = -1


func _ready() -> void:
	_instance = self

func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Clears and rebuilds the minimap grid from the current world state.
# Must be called after WorldGenerator.generateWorld() has completed.
func populate() -> void:
	for child in gridMM.get_children():
		child.queue_free()

	_zoneObjects.clear()
	_zoneColors.clear()
	_currentPlayerZone = -1
	gridMM.columns     = Globals.ZONE_GRID_WIDTH

	# Find the highest non-sentinel score so we can normalize to [0, 1].
	var maxScore := 1
	for zone: Zone in MapManager.zones:
		if zone.wildernessScore < 99 and zone.wildernessScore > maxScore:
			maxScore = zone.wildernessScore

	for i in Globals.ZONE_COUNT:
		var zone  := MapManager.getZone(i)
		var obj   := prefabZoneMMObject.instantiate() as MMZoneObject
		var t     := clampf(float(zone.wildernessScore) / float(maxScore), 0.0, 1.0)
		var color := colorDepthMin.lerp(colorDepthMax, t)
		obj.color        = color
		obj.lblInfo.text = str(zone.wildernessScore)
		gridMM.add_child(obj)
		_zoneObjects.append(obj)
		_zoneColors.append(color)


# Highlights the player's current zone and restores the previous one.
# Call this on zone entry and once after populate() to set the initial position.
func setPlayerZone(zoneId: int) -> void:
	if _currentPlayerZone >= 0:
		_zoneObjects[_currentPlayerZone].color = _zoneColors[_currentPlayerZone]
	_currentPlayerZone = zoneId
	if zoneId >= 0 and zoneId < _zoneObjects.size():
		_zoneObjects[zoneId].color = colorPlayerLocation
