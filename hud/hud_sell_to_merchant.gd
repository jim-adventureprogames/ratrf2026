class_name HUD_SellToMerchant
extends Control

@export var txtValue:      RichTextLabel
@export var txtBonus:      RichTextLabel
@export var gridSoldItems: GridContainer
@export var btnSell:       Button
@export var btnCancel:     Button
@export var btnHaggle:     Button

# How many columns the sold-items grid displays.
@export var gridColumns: int = 6

const _ITEM_SLOT := preload("res://hud/item_display_container.tscn")

var _transaction: SellToVendorTransaction = null
var _inventory:   InventoryComponent      = null


static var _instance : HUD_SellToMerchant;
static func summon() -> HUD_SellToMerchant:
	return _instance;

func _ready() -> void:
	_instance = self;
	gridSoldItems.columns = gridColumns
	btnSell.pressed.connect(onSell)
	btnCancel.pressed.connect(onCancel)
	btnHaggle.pressed.connect(onHaggle)


# Opens the HUD against a specific inventory and transaction.
# Pass an existing SellToVendorTransaction (items may already be staged)
# or a fresh one.
func beginTransaction(inventory: InventoryComponent,
		transaction: SellToVendorTransaction) -> void:
	if _transaction != null \
			and _transaction.stagedItemsChanged.is_connected(_onTransactionChanged):
		_transaction.stagedItemsChanged.disconnect(_onTransactionChanged)

	_inventory   = inventory
	_transaction = transaction
	_transaction.stagedItemsChanged.connect(_onTransactionChanged)

	GameManager.setGamePhase(GameManager.EGamePhase.Merchant);

	_refreshGrid()
	_updateLabels()
	show()


# Returns true if the given item is currently queued for sale.
# Used by HUD_Main's shouldDimItem predicate.
func isItemStaged(item: Item) -> bool:
	return _transaction != null and _transaction.isStaged(item)


# Updates the active transaction's value multiplier and refreshes the labels.
# Called by ChallengeManager after a haggle succeeds or fails.
func applyHaggleResult(newMultiplier: float) -> void:
	if _transaction == null:
		return
	_transaction.valueMultiplier = newMultiplier
	_updateLabels()


# Adds an item to the active transaction.
# No-op if no transaction is open or the item is already staged.
func addItemToTransaction(item: Item) -> void:
	if _transaction != null:
		_transaction.addItem(item)


# ── Transaction callbacks ──────────────────────────────────────────────────────

func _onTransactionChanged() -> void:
	_refreshGrid()
	_updateLabels()
	# Re-dim (or un-dim) items in the main inventory grid to match staged state.
	var mainHud := HUD_Main.summon()
	if mainHud != null:
		mainHud.inventoryGrid.refresh()


# ── Grid ──────────────────────────────────────────────────────────────────────

func _refreshGrid() -> void:
	for child in gridSoldItems.get_children():
		child.queue_free()

	if _transaction == null:
		return

	for item: Item in _transaction.getStagedItems():
		var slot := _ITEM_SLOT.instantiate() as ItemDisplayContainer
		gridSoldItems.add_child(slot)
		slot.setItem(item)
		# Capture item in a local so the lambda closes over the correct value.
		var captured := item
		slot.gui_input.connect(func(event: InputEvent) -> void:
			_onSlotInput(event, captured))


func _onSlotInput(event: InputEvent, item: Item) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		_transaction.removeItem(item)


# ── Labels ─────────────────────────────────────────────────────────────────────

func _updateLabels() -> void:
	_updateValueLabel()
	_updateBonusLabel()


func _updateValueLabel() -> void:
	var total   := _transaction.getTotalValue() if _transaction != null else 0
	var dollars := total / 100
	var cents   := total % 100
	txtValue.text = "$%d.%02d" % [dollars, cents]


func _updateBonusLabel() -> void:
	var mult := _transaction.valueMultiplier if _transaction != null else 0.0
	var pct  := mult * 100.0
	var sign := "+" if pct >= 0.0 else ""

	if pct > 0.0:
		txtBonus.text = "[color=#6688ff]%s%.0f%%[/color]" % [sign, pct]
	elif pct < 0.0:
		txtBonus.text = "[color=#ff5555]%s%.0f%%[/color]" % [sign, pct]
	else:
		txtBonus.text = "%s%.0f%%" % [sign, pct]

func turnOff() -> void: 
	if GameManager.getGamePhase() == GameManager.EGamePhase.Merchant:
		GameManager.setGamePhase(GameManager.EGamePhase.Player);
		
	hide();


# ── Button handlers ────────────────────────────────────────────────────────────

func onSell() -> void:
	if _transaction == null or _inventory == null:
		return
	var payout := _transaction.complete(_inventory)
	_inventory.addCoin(payout)
	var merchant := GameManager.getTargetMerchant()
	if merchant:
		merchant.onTransactionComplete()
	turnOff();


func onCancel() -> void:
	if _transaction != null:
		_transaction.cancel()
	var merchant := GameManager.getTargetMerchant()
	if merchant:
		merchant.onTransactionCancel()
	turnOff();


func onHaggle() -> void:
	ChallengeManager.BeginChallenge("haggle_merchant");
	pass
