extends Node

static var _instance: CrimeManager

static func summon() -> CrimeManager:
	return _instance


var crimeSettings: CrimeSettings

# Emitted immediately after a crime is recorded.
signal crimeRegistered(event: CrimeEvent)

# All recorded crimes, keyed by CrimeEvent.id.
var crimeRegistry: Dictionary = {}   # int → CrimeEvent

# ── Chase mode ────────────────────────────────────────────────────────────────

# Emitted the moment a guard first enters chase mode.
# HUD_Main listens to this for an immediate show — no need to wait for turnAdvanced.
signal chaseStarted

# True while at least one guard is actively chasing the player.
var bChaseMode: bool = false

# 0–100. Resets to 100 whenever a guard reports seeing the player this turn.
# Decays by CHASE_ALERT_DECAY each turn the player is out of sight.
# Hits 0 → all guards give up the chase.
var chaseAlertValue: float = 0.0

# How much chaseAlertValue drops per turn when no guard sees the player.
# 10.0 → player escapes in 10 consecutive unseen turns.
const CHASE_ALERT_DECAY: float = 10.0

const CHASE_MAX_ALART: float = 100.0

# Set to true during a turn by any guard that spots the player; cleared in onEndOfTurn.
var _bPlayerSeenThisTurn: bool = false


func _ready() -> void:
	_instance = self
	crimeSettings = load("res://data/crime_settings.tres") as CrimeSettings
	if crimeSettings == null:
		push_warning("CrimeManager: crime_settings.tres not found, using defaults.")
		crimeSettings = CrimeSettings.new()
	GameManager.cancelGuardAlert.connect(_onCancelGuardAlert)

func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# ── Chase mode API ───────────────────────────────────────────────────────────

# Called by GuardComponent._startChasing() — switches the world into chase mode.
# Resets the alert value to full so the countdown starts fresh.
func enterChaseMode() -> void:
	var bWasChasing := bChaseMode
	bChaseMode      = true
	chaseAlertValue = CHASE_MAX_ALART
	AudioManager.summon().setMusicState(AudioManager.EMusicState.Alart)
	if not bWasChasing:
		chaseStarted.emit()

func getAlertRatio() -> float:
	return chaseAlertValue / CHASE_MAX_ALART;

# Called by GuardComponent.onEndOfTurn() when a chasing guard has line-of-sight
# to the player this turn.  Keeps the alert value at maximum for the next cycle.
# Returns true if this is the first sighting this turn after a turn where nobody
# saw the player (i.e. the alert had started to decay).  Callers use this to
# decide whether to spawn a visual indicator.
func reportPlayerSighted() -> bool:
	var bRespot := not _bPlayerSeenThisTurn and chaseAlertValue < 100.0
	_bPlayerSeenThisTurn = true
	return bRespot


# Called by GameManager._processEndOfTurnCleanup(), after all entities have
# processed onEndOfTurn().  Handles alert decay and chase-mode exit.
func onEndOfTurn() -> void:
	if not bChaseMode:
		return

	if _bPlayerSeenThisTurn:
		# At least one guard saw the player — keep the heat at maximum.
		chaseAlertValue = CHASE_MAX_ALART
	else:
		# Nobody saw the player this turn — tick the countdown down.
		chaseAlertValue -= CHASE_ALERT_DECAY
		chaseAlertValue  = max(chaseAlertValue, 0.0)

	_bPlayerSeenThisTurn = false

	# Alert fully decayed — call off the chase.
	if chaseAlertValue <= 0.0:
		bChaseMode = false
		GameManager.cancelGuardAlert.emit()


# Called whenever GameManager.cancelGuardAlert is emitted — whether by
# CrimeManager itself (alert decayed to 0) or by an external trigger like
# a dialogue result.  Zeros the alert and hides the meter immediately.
func _onCancelGuardAlert() -> void:
	bChaseMode           = false
	chaseAlertValue      = 0.0
	_bPlayerSeenThisTurn = false
	var theAudio = AudioManager.summon();
	if theAudio.getMusicState() == AudioManager.EMusicState.Alart or \
	   theAudio.getMusicState() == AudioManager.EMusicState.Tension :
		AudioManager.summon().setMusicState(AudioManager.EMusicState.Normal)
	var hud := HUD_Main.summon()
	if hud:
		hud.updateAlartMeter()


# Resets all chase-mode state for a fresh game.
func resetForNewGame() -> void:
	bChaseMode           = false
	chaseAlertValue      = 0.0
	_bPlayerSeenThisTurn = false


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
