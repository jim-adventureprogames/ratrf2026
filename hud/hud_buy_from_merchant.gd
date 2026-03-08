class_name HUD_BuyFromMerchant
extends Control

static var _instance: HUD_BuyFromMerchant

static func summon() -> HUD_BuyFromMerchant:
	return _instance


@export var inventoryGrid:  InventoryGrid
@export var btnClose:       Button
@export var btnHaggle:      Button
@export var txtHaggle:      RichTextLabel
@export var txtPrice:       RichTextLabel


var _merchant:         MerchantComponent  = null
var _playerInventory:  InventoryComponent = null


func _ready() -> void:
	_instance = self
	btnClose.pressed.connect(turnOff)
	btnHaggle.pressed.connect(_onHaggle)
	inventoryGrid.tooltipPopup = HUD_Main.summon().tooltipPopup
	inventoryGrid.item_right_clicked.connect(_onItemRightClicked)
	inventoryGrid.item_entered.connect(_onItemEntered)
	inventoryGrid.item_unhovered.connect(_onItemUnhovered)
	hide()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Opens the shop HUD displaying the merchant's inventory.
# Called by MerchantComponent.onBeginTransactionBuyFromMe().
func open(merchant: MerchantComponent) -> void:
	_merchant = merchant

	var playerEntity := GameManager.playerEntity
	if playerEntity == null:
		return
	_playerInventory = playerEntity.getComponent(&"InventoryComponent") as InventoryComponent
	if _playerInventory == null:
		return

	# Connect coin display — disconnect first so we never double-connect.
	if _playerInventory.coinChanged.is_connected(_onPlayerCoinChanged):
		_playerInventory.coinChanged.disconnect(_onPlayerCoinChanged)
	_playerInventory.coinChanged.connect(_onPlayerCoinChanged)
	_onPlayerCoinChanged(_playerInventory.getCoin())

	var merchantInventory := merchant.entity.getComponent(&"InventoryComponent") as InventoryComponent
	if merchantInventory == null:
		push_warning("HUD_BuyFromMerchant: merchant has no InventoryComponent.")
		return

	inventoryGrid.populate(merchantInventory)
	_updateHaggleLabel()
	GameManager.setGamePhase(GameManager.EGamePhase.Merchant)
	show()


func turnOff() -> void:
	if _playerInventory and _playerInventory.coinChanged.is_connected(_onPlayerCoinChanged):
		_playerInventory.coinChanged.disconnect(_onPlayerCoinChanged)
	_merchant        = null
	_playerInventory = null
	if txtPrice:
		txtPrice.text = ""
	if GameManager.getGamePhase() == GameManager.EGamePhase.Merchant:
		GameManager.setGamePhase(GameManager.EGamePhase.Player)
	hide()


# Right-clicking an item attempts to purchase it.
# Price = item base value scaled up by the merchant's haggleMultiplier.
# e.g. haggleMultiplier = 0.5 → 50 % markup → $1.00 item costs $1.50.
func _onItemRightClicked(item: Item) -> void:
	if _merchant == null or _playerInventory == null:
		return

	var basePrice  := item.getValue()
	var price      := int(float(basePrice) * (1.0 + _merchant.haggleMultiplier))

	if not _playerInventory.canAfford(price):
		# TODO: surface a "can't afford" floater or sound.
		return

	var merchantInventory := _merchant.entity.getComponent(&"InventoryComponent") as InventoryComponent
	if merchantInventory == null:
		return

	# Transfer: deduct coin, move item from merchant to player.
	_playerInventory.removeCoin(price)
	merchantInventory.removeItem(item.archetypeName, 1)
	_playerInventory.addItem(Item.new(item.archetypeName, 1))
	_merchant.onTransactionComplete()


func _onItemEntered(item: Item) -> void:
	if txtPrice == null or _merchant == null:
		return
	var price := int(float(item.getValue()) * (1.0 + _merchant.haggleMultiplier))
	txtPrice.text = "$%d.%02d" % [price / 100, price % 100]


func _onItemUnhovered() -> void:
	if txtPrice:
		txtPrice.text = ""


func _onHaggle() -> void:
	if _merchant == null:
		return
	ChallengeManager.BeginChallenge("haggle_merchant")


# Called by ChallengeManager after a haggle_merchant challenge resolves.
func applyHaggleResult(_newMultiplier: float) -> void:
	_updateHaggleLabel()


func _updateHaggleLabel() -> void:
	if txtHaggle == null or _merchant == null:
		return
	var pct := _merchant.haggleMultiplier * 100.0
	if pct >= 0.0:
		txtHaggle.text = "[color=red]+%d%%[/color]" % int(pct)
	else:
		txtHaggle.text = "[color=green]%d%%[/color]" % int(pct)


func _onPlayerCoinChanged(newAmount: int) -> void:
	pass
