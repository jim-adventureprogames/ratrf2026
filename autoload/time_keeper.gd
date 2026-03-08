class_name TimeKeeper
extends Resource

# How many in-game seconds each player turn represents.
@export var numberOfSecondsInTurn: float = 6.0

# The faire opens and closes at these 24-hour clock values.
@export var gameStartHour: float = 10.0
@export var gameEndHour:   float = 18.0


# These are the hottest parts of the day
@export var heatPenaltyStartHour: float = 12.0
@export var heatPenaltyEndHour:   float = 15.0


signal turnAdvanced
signal halfHourPassed

var _turnsTaken:       int = 0
var _lastHalfHourSlot: int = 0


func advanceTurn() -> void:
	_turnsTaken += 1
	turnAdvanced.emit()
	var elapsed  := _turnsTaken * numberOfSecondsInTurn
	var slot     := int(elapsed / 1800.0)
	if slot > _lastHalfHourSlot:
		_lastHalfHourSlot = slot
		halfHourPassed.emit()


# ── Queries ───────────────────────────────────────────────────────────────────

# Raw turn count since the game started.
func getTurns() -> int:
	return _turnsTaken


# Day progress as a 0.0–1.0 ratio. Clamped so it never exceeds 1.0 after hours.
func getDayProgress() -> float:
	var totalSeconds := (gameEndHour - gameStartHour) * 3600.0
	return clampf((_turnsTaken * numberOfSecondsInTurn) / totalSeconds, 0.0, 1.0)


# Resets all time state to the start of a new game day.
# Call this before generating a new world so the clock begins at gameStartHour.
func resetForNewGame() -> void:
	_turnsTaken       = 0
	_lastHalfHourSlot = 0


# Current game time as a 24-hour "HH:MM" string (e.g. "13:45").
func getTimeString() -> String:
	var elapsed        := _turnsTaken * numberOfSecondsInTurn
	var currentSeconds := gameStartHour * 3600.0 + elapsed
	var hours          := int(currentSeconds / 3600) % 24
	var minutes        := int(fmod(currentSeconds, 3600.0) / 60.0)
	return "%02d:%02d" % [hours, minutes]
	
# Jumps the clock to the given elapsed-seconds value without emitting
# halfHourPassed — use this for debug time-skips only.
# Updates _lastHalfHourSlot so no spurious half-hour events fire afterward.
# Emits turnAdvanced so the HUD refreshes immediately.
func jumpToElapsedSeconds(elapsed: float) -> void:
	_turnsTaken       = int(elapsed / numberOfSecondsInTurn)
	_lastHalfHourSlot = int(elapsed / 1800.0)
	turnAdvanced.emit()


# stamina should last for three hours under normal circumstances, 
# but if you're being chased you burn it very quickly.
func getStaminaCostPerRound() -> float:
	if( CrimeManager.summon().bChaseMode ):
		return 0.75;
		
	var baseCost := (numberOfSecondsInTurn / (3600.0 * 3.0)) * 100.0
	return baseCost;
	
# hydration should cost a full meter (100.0) per hour, twice as much in the hottest 
# part of the day
func getHydrationCostPerRound() -> float:
	# 100 points depleted over one hour = 100 / 3600 points per second,
	# scaled by how many seconds this turn represents.
	var baseCost := (numberOfSecondsInTurn / 3600.0) * 100.0
	return baseCost * getHeatMultiplier()


func getHeatMultiplier() -> float:
	var elapsed     := _turnsTaken * numberOfSecondsInTurn
	var currentHour := (gameStartHour * 3600.0 + elapsed) / 3600.0
	if currentHour >= heatPenaltyStartHour and currentHour < heatPenaltyEndHour:
		return 2.0
	return 1.0
