class_name PlayerCharacterComponent
extends EntityComponent

signal apDepleted

@export var maxAP: int = 1

var currentAP: int = 1


# Deducts one action point. Emits apDepleted when the last AP is spent.
func spendAP() -> void:
	currentAP -= 1
	if currentAP <= 0:
		currentAP = 0
		apDepleted.emit()


# Restore AP at the end of each full turn cycle.
func onEndOfTurn() -> void:
	currentAP = maxAP
