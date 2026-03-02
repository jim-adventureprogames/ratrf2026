class_name TimeKeeper
extends Resource

# How many in-game seconds each player turn represents.
@export var numberOfSecondsInTurn: float = 6.0

# The faire opens and closes at these 24-hour clock values.
@export var gameStartHour: float = 10.0
@export var gameEndHour:   float = 18.0

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


# Current game time as a 24-hour "HH:MM" string (e.g. "13:45").
func getTimeString() -> String:
	var elapsed        := _turnsTaken * numberOfSecondsInTurn
	var currentSeconds := gameStartHour * 3600.0 + elapsed
	var hours          := int(currentSeconds / 3600) % 24
	var minutes        := int(fmod(currentSeconds, 3600.0) / 60.0)
	return "%02d:%02d" % [hours, minutes]
