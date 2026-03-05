extends Node

static var _instance: CrimeManager

static func summon() -> CrimeManager:
	return _instance


var crimeSettings: CrimeSettings

# Emitted immediately after a crime is recorded.
signal crimeRegistered(event: CrimeEvent)

# All recorded crimes, keyed by CrimeEvent.id.
var crimeRegistry: Dictionary = {}   # int → CrimeEvent


func _ready() -> void:
	_instance = self
	crimeSettings = load("res://data/crime_settings.tres") as CrimeSettings
	if crimeSettings == null:
		push_warning("CrimeManager: crime_settings.tres not found, using defaults.")
		crimeSettings = CrimeSettings.new()

func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Returns the detection radius for the given approach rating.
# Falls back to 0 if the entry is missing from the settings resource.
func getDetectionRadius(rating: GameManager.EApproachRating) -> float:
	if crimeSettings == null:
		return 0.0
	return float(crimeSettings.defaultCrimeRadiusByAudacity.get(rating, 0))


# Records a crime and returns the new CrimeEvent.
# items — every Item involved; unique items are stored by itemId,
#         stackable items are stored by archetypeName.
func registerCrime(perpID: int, victimID: int, location: Vector3i,
		items: Array[Item], detectionRadius: float) -> CrimeEvent:
	var event                := CrimeEvent.new()
	event.perpID             = perpID
	event.victimID           = victimID
	event.location           = location
	event.detectionRadius    = detectionRadius
	event.time               = GameManager.timeKeeper.getTurns() if GameManager.timeKeeper else 0

	for item: Item in items:
		if item.isUnique():
			event.uniqueStolenGoods.append(item.itemId)
		else:
			event.regularStolenGoodArchetypes.append(item.archetypeName)

	crimeRegistry[event.id] = event
	crimeRegistered.emit(event)
	return event


# Returns the CrimeEvent with the given ID, or null if not found.
func getCrimeByID(id: int) -> CrimeEvent:
	return crimeRegistry.get(id, null)


# Returns all crimes that occurred in the given zone.
func getCrimesInZone(zoneId: int) -> Array[CrimeEvent]:
	var result: Array[CrimeEvent] = []
	for event: CrimeEvent in crimeRegistry.values():
		if event.location.z == zoneId:
			result.append(event)
	return result


# Returns all crimes committed against the given entity ID.
func getCrimesAgainstEntity(entityId: int) -> Array[CrimeEvent]:
	var result: Array[CrimeEvent] = []
	for event: CrimeEvent in crimeRegistry.values():
		if event.victimID == entityId:
			result.append(event)
	return result
