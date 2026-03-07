class_name HUD_Main
extends Control

static var _instance: HUD_Main

static func summon() -> HUD_Main:
	return _instance

@export var btnDebugStart:    Button
@export var inventoryGrid:    InventoryGrid
@export var txtTime:          Label
@export var txtCoin:          Label
@export var tooltipPopup:     TooltipPopup
@export var alartMeter:       Control
@export var alartProgressBar: TextureProgressBar

@export var btnHowToPlay: TextureButton
@export var btnOptions:   TextureButton
@export var btnMap:       TextureButton
@export var btnStats:     TextureButton


func _ready() -> void:
	_instance = self
	btnDebugStart.pressed.connect(_OnDebugStartPressed)
	btnHowToPlay.pressed.connect(_onHowToPlayPressed)
	btnOptions.pressed.connect(_onOptionsPressed)
	btnMap.pressed.connect(_onMapPressed)
	btnStats.pressed.connect(_onStatsPressed)
	inventoryGrid.tooltipPopup = tooltipPopup
	inventoryGrid.item_right_clicked.connect(_onInventoryItemRightClicked)
	inventoryGrid.shouldDimItem = func(item: Item) -> bool:
		var sellHud := HUD_SellToMerchant.summon()
		return sellHud != null and sellHud.visible and sellHud.isItemStaged(item)
	if tooltipPopup != null:
		tooltipPopup.hide()
	CrimeManager.summon().chaseStarted.connect(_onChaseStarted)
	updateAlartMeter()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _onHowToPlayPressed() -> void:
	pass


func _onOptionsPressed() -> void:
	var options := HUD_Options.summon()
	if options == null:
		return
	if options.visible:
		options.turnOff()
	else:
		options.turnOn()


func _onMapPressed() -> void:
	pass


func _onStatsPressed() -> void:
	pass


func _OnDebugStartPressed() -> void:
	GameManager.startGame()
	btnDebugStart.hide()
	GameManager.timeKeeper.turnAdvanced.connect(_onTurnAdvanced)
	_updateTimeDisplay()


# Resets the HUD to its pre-game state so the player can start a new run.
# Called by GameManager.resetForNewGame() before the world is torn down.
#
# Add new HUD elements here as they are introduced (minimap state, objective
# displays, score counters, etc.).
func resetForNewGame() -> void:
	# Stop listening to the old timeKeeper — a fresh one will reconnect via
	# _OnDebugStartPressed when the next game begins.
	if GameManager.timeKeeper != null \
			and GameManager.timeKeeper.turnAdvanced.is_connected(_onTurnAdvanced):
		GameManager.timeKeeper.turnAdvanced.disconnect(_onTurnAdvanced)

	# Bring back the start button so the player can kick off a new run.
	btnDebugStart.show()

	# Blank out the time and coin labels; they will repopulate once the
	# new game starts and the first turn / coin event fires.
	if txtTime: txtTime.text = ""
	if txtCoin: txtCoin.text = ""
	updateAlartMeter()


func _onTurnAdvanced() -> void:
	_updateTimeDisplay()
	updateAlartMeter()


func _onChaseStarted() -> void:
	updateAlartMeter()


# Syncs AlartMeter visibility and fill to the current CrimeManager chase state.
# Call any time chase mode or chaseAlertValue may have changed.
func updateAlartMeter() -> void:
	if alartMeter == null or alartProgressBar == null:
		return
	var cm := CrimeManager.summon()
	alartMeter.visible       = cm != null and cm.bChaseMode
	alartProgressBar.value   = cm.chaseAlertValue if cm != null else 0.0


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


func _onInventoryItemRightClicked(item: Item) -> void:
	var sellHud := HUD_SellToMerchant.summon()
	if sellHud != null and sellHud.visible:
		sellHud.addItemToTransaction(item)


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
