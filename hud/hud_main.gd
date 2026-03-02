class_name HUD_Main
extends Control

static var _instance: HUD_Main

static func summon() -> HUD_Main:
	return _instance

@export var btnDebugStart: Button
@export var inventoryGrid:  InventoryGrid
@export var txtTime:        Label


func _ready() -> void:
	_instance = self
	btnDebugStart.pressed.connect(_OnDebugStartPressed)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _OnDebugStartPressed() -> void:
	GameManager.startGame()
	btnDebugStart.hide()
	GameManager.timeKeeper.turnAdvanced.connect(_onTurnAdvanced)
	_updateTimeDisplay()


func _onTurnAdvanced() -> void:
	_updateTimeDisplay()


func _updateTimeDisplay() -> void:
	if txtTime == null:
		return
	txtTime.text = GameManager.timeKeeper.getTimeString()


func showInventory(inventory: InventoryComponent) -> void:
	inventoryGrid.populate(inventory)


const _FLOATING_DISPLAY := preload("res://hud/floating_display.tscn")

func spawnFloatingDisplay(worldPosition: Vector2, image: Texture2D = null, text: String = "",
		lifetime: float = 2.0, moveOffset: Vector2 = Vector2.ZERO, bFade: bool = true) -> void:
	var fd := _FLOATING_DISPLAY.instantiate() as FloatingDisplay
	add_child(fd)
	fd.display(worldPosition, image, text, lifetime, moveOffset, bFade)
