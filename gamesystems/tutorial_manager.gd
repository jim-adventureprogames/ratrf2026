extends Node

static var _instance: TutorialManager

static func summon() -> TutorialManager:
	return _instance


# Tracks how far along each named tutorial the player is.
# Keys are tutorial identifiers (e.g. "pickpocket", "guards");
# values are the number of steps completed so far.
var mapTutorialSteps: Dictionary[String, int] = {}


func _ready() -> void:
	_instance = self


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Returns the number of completed steps for the given tutorial key.
# Returns 0 if the tutorial has not been started.
func getTutorialSteps(key: String) -> int:
	return mapTutorialSteps.get(key, 0)


# Advances the given tutorial by one step.
func advanceTutorial(key: String) -> void:
	mapTutorialSteps[key] = mapTutorialSteps.get_or_add(key, 0) + 1
