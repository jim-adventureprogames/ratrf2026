class_name HUD_Main
extends Control

static var _instance: HUD_Main

static func summon() -> HUD_Main:
	return _instance

@export var btnDebugStart:    Button
@export var inventoryGrid:    InventoryGrid
@export var txtTime:          Label
@export var txtCoin:          Label
@export var txtFun:	          Label

@export var tooltipPopup:     TooltipPopup
@export var alartMeter:       Control
@export var alartProgressBar: TextureProgressBar

@export var txtHeatWarning: Label

@export var txtStamina: Label
@export var txtThirst:  Label

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
	var fm := FunManager.summon()
	if fm:
		fm.funChanged.connect(_onFunChanged)


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


# Called by GameManager.startGame() after the world and player are ready.
# Connects the timeKeeper signal (idempotent — safe to call more than once)
# and does an initial refresh of all time-dependent displays.
func onGameStarted() -> void:
	if GameManager.timeKeeper != null \
			and not GameManager.timeKeeper.turnAdvanced.is_connected(_onTurnAdvanced):
		GameManager.timeKeeper.turnAdvanced.connect(_onTurnAdvanced)
	_updateTimeDisplay()
	_updateHeatWarning()


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
	if txtCoin:
		txtCoin.text     = ""
		txtCoin.modulate = Color.WHITE
	if _coinColorTween:
		_coinColorTween.kill()
		_coinColorTween = null
	_lastCoinAmount = 0
	if txtFun:
		txtFun.text            = ""
		txtFun.modulate        = Color.WHITE
	if _funColorTween:
		_funColorTween.kill()
		_funColorTween = null
	if txtHeatWarning:
		txtHeatWarning.hide()
	if _heatTween:
		_heatTween.kill()
		_heatTween = null
	if txtStamina:
		txtStamina.text = ""
	if txtThirst:
		txtThirst.text = ""
	updateAlartMeter()


func _onTurnAdvanced() -> void:
	_updateTimeDisplay()
	updateAlartMeter()
	_updateHeatWarning()


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


func _updateHeatWarning() -> void:
	if txtHeatWarning == null:
		return
	var tk := GameManager.timeKeeper
	if tk == null:
		return
	var bHot := tk.getHeatMultiplier() > 1.0
	if bHot and not txtHeatWarning.visible:
		txtHeatWarning.show()
		txtHeatWarning.modulate = Color.ORANGE
		_heatTween = create_tween().set_loops()
		_heatTween.tween_property(txtHeatWarning, "modulate", Color.YELLOW, 2.0)
		_heatTween.tween_property(txtHeatWarning, "modulate", Color.ORANGE, 2.0)
	elif not bHot and txtHeatWarning.visible:
		txtHeatWarning.hide()
		if _heatTween:
			_heatTween.kill()
			_heatTween = null


func _updateTimeDisplay() -> void:
	if txtTime == null:
		return
	txtTime.text = GameManager.timeKeeper.getTimeString()


func showPlayerStats(pcc: PlayerCharacterComponent) -> void:
	if pcc.staminaChanged.is_connected(_onStaminaChanged):
		pcc.staminaChanged.disconnect(_onStaminaChanged)
	if pcc.hydrationChanged.is_connected(_onHydrationChanged):
		pcc.hydrationChanged.disconnect(_onHydrationChanged)
	pcc.staminaChanged.connect(_onStaminaChanged)
	pcc.hydrationChanged.connect(_onHydrationChanged)
	_onStaminaChanged(pcc.stamina)
	_onHydrationChanged(pcc.hydration)


func _onStaminaChanged(newValue: float) -> void:
	if txtStamina:
		txtStamina.text = "%d" % ceili(newValue)


func _onHydrationChanged(newValue: float) -> void:
	if txtThirst:
		txtThirst.text = "%d" % ceili(newValue)


func showInventory(inventory: InventoryComponent) -> void:
	inventoryGrid.populate(inventory)
	if inventory.coinChanged.is_connected(_updateCoinDisplay):
		inventory.coinChanged.disconnect(_updateCoinDisplay)
	inventory.coinChanged.connect(_updateCoinDisplay)
	_updateCoinDisplay(inventory.getCoin())


func _onInventoryItemRightClicked(item: Item) -> void:
	# During a sell transaction: stage the item for sale.
	var sellHud := HUD_SellToMerchant.summon()
	if sellHud != null and sellHud.visible:
		sellHud.addItemToTransaction(item)
		return
	# During any other merchant transaction (buy HUD open): do nothing.
	if GameManager.getGamePhase() == GameManager.EGamePhase.Merchant:
		return
	# Normal play: consume the item if it is consumable.
	if not item.isConsumable():
		return
	var pcc := GameManager.getPlayerComponent()
	if pcc == null:
		return
	pcc.consumeItem(item)


func _updateCoinDisplay(amount: int) -> void:
	if txtCoin == null:
		return
	var dollars := amount / 100
	var cents   := amount % 100
	txtCoin.text = "$%d.%02d" % [dollars, cents]
	if amount != _lastCoinAmount:
		var flashColor := Color.GREEN if amount > _lastCoinAmount else Color.RED
		if _coinColorTween:
			_coinColorTween.kill()
		txtCoin.modulate = flashColor
		_coinColorTween  = create_tween()
		_coinColorTween.tween_property(txtCoin, "modulate", Color.WHITE, 1.0)
		_lastCoinAmount = amount


var _funColorTween:  Tween = null
var _coinColorTween: Tween = null
var _lastCoinAmount: int   = 0
var _heatTween:      Tween = null


func _onFunChanged(newScore: int) -> void:
	if txtFun == null:
		return
	txtFun.text = "%d" % newScore
	# Flash green, then lerp back to white over one second.
	if _funColorTween:
		_funColorTween.kill()
	txtFun.modulate    = Color.GREEN
	_funColorTween     = create_tween()
	_funColorTween.tween_property(txtFun, "modulate", Color.WHITE, 1.0)


const _FLOATING_DISPLAY := preload("res://hud/floating_display.tscn")

func spawnFloatingDisplay(worldPosition: Vector2, image: Texture2D = null, text: String = "",
		lifetime: float = 2.0, moveOffset: Vector2 = Vector2.ZERO, bFade: bool = true) -> void:
	var fd := _FLOATING_DISPLAY.instantiate() as FloatingDisplay
	add_child(fd)
	fd.display(worldPosition, image, text, lifetime, moveOffset, bFade)
