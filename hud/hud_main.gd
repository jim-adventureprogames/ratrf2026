class_name HUD_Main
extends Control

static var _instance: HUD_Main

static func summon() -> HUD_Main:
	return _instance

@export var btnDebugStart: Button
@export var inventoryGrid:  InventoryGrid
@export var txtTime:        Label
@export var txtCoin:        Label
@export var tooltipPopup:   TooltipPopup


func _ready() -> void:
	_instance = self
	btnDebugStart.pressed.connect(_OnDebugStartPressed)
	inventoryGrid.tooltipPopup = tooltipPopup
	if tooltipPopup != null:
		tooltipPopup.hide()


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
	if inventory.coinChanged.is_connected(_updateCoinDisplay):
		inventory.coinChanged.disconnect(_updateCoinDisplay)
	inventory.coinChanged.connect(_updateCoinDisplay)
	_updateCoinDisplay(inventory.getCoin())


func _updateCoinDisplay(amount: int) -> void:
	if txtCoin == null:
		return
	var dollars := amount / 100
	var cents   := amount % 100
	txtCoin.text = "$%d.%02d" % [dollars, cents]


const _FLOATING_DISPLAY := preload("res://hud/floating_display.tscn")

func spawnFloatingDisplay(worldPosition: Vector2, image: Texture2D = null, text: String = "",
		lifetime: float = 2.0, moveOffset: Vector2 = Vector2.ZERO, bFade: bool = true) -> void:
	var fd := _FLOATING_DISPLAY.instantiate() as FloatingDisplay
	add_child(fd)
	fd.display(worldPosition, image, text, lifetime, moveOffset, bFade)
