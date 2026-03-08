class_name InventoryGrid
extends GridContainer

@export var maxWidth:            int        = 6
@export var maxHeight:           int        = 6
@export var itemContainerPrefab: PackedScene

# Bubbled up from any slot in this grid when the player right-clicks a filled slot.
signal item_right_clicked(item: Item)
# Bubbled up from any slot immediately when the cursor enters.
signal item_entered(item: Item)
# Bubbled up from any slot after the hover delay elapses.
signal item_hovered(item: Item, canvas_pos: Vector2)
# Bubbled up from any slot immediately when the cursor leaves.
signal item_unhovered()

var _inventory:    InventoryComponent
var tooltipPopup:  TooltipPopup

# Optional predicate: assign a Callable(item: Item) -> bool before populating.
# Slots whose item returns true will be drawn at 50 % opacity.
var shouldDimItem: Callable = Callable()


func _ready() -> void:
	for child in get_children():
		child.queue_free()


# Binds this grid to an InventoryComponent and builds the initial slot display.
# Disconnects any previously bound inventory first so only one signal is live.
func populate(inventory: InventoryComponent) -> void:
	if itemContainerPrefab == null:
		push_error("InventoryGrid: itemContainerPrefab is not assigned.")
		return

	if _inventory != null and _inventory.itemsChanged.is_connected(refresh):
		_inventory.itemsChanged.disconnect(refresh)

	_inventory = inventory
	columns    = maxWidth
	_inventory.itemsChanged.connect(refresh)
	refresh()


# Rebuilds all slots from the current inventory state.
# Items with a valid gridSlotIndex are placed at that slot; items without one
# fill the first available gap.  This preserves drag-and-drop arrangement
# across any itemsChanged refresh.
func refresh() -> void:
	for child in get_children():
		child.queue_free()

	var items      := _inventory.getItems()
	var totalSlots := maxWidth * maxHeight

	# Build a sparse slot map from items that already know where they live.
	var slotMap: Dictionary = {}   # int → Item
	var unslotted: Array    = []
	for item: Item in items:
		if item.gridSlotIndex >= 0 and item.gridSlotIndex < totalSlots \
				and not slotMap.has(item.gridSlotIndex):
			slotMap[item.gridSlotIndex] = item
		else:
			unslotted.append(item)

	# Fill slots in order, using pinned items first and spilling unslotted into gaps.
	var gapIdx := 0
	for i in totalSlots:
		var slot := itemContainerPrefab.instantiate() as ItemDisplayContainer
		add_child(slot)
		if slotMap.has(i):
			slot.setItem(slotMap[i])
			slot.setDimmed(shouldDimItem.is_valid() and shouldDimItem.call(slotMap[i]))
		elif gapIdx < unslotted.size():
			slot.setItem(unslotted[gapIdx])
			slot.setDimmed(shouldDimItem.is_valid() and shouldDimItem.call(unslotted[gapIdx]))
			gapIdx += 1
		else:
			slot.clearItem()
		if tooltipPopup != null:
			slot.item_hovered.connect(tooltipPopup.showForItem)
			slot.item_unhovered.connect(tooltipPopup.hide)
		slot.item_entered.connect(item_entered.emit)
		slot.item_hovered.connect(item_hovered.emit)
		slot.item_unhovered.connect(item_unhovered.emit)
		slot.item_right_clicked.connect(item_right_clicked.emit)


# Rebuilds the inventory's item order from the current slot display state and
# stamps each item's gridSlotIndex so refresh() can restore the arrangement.
# Called after every drag-and-drop to keep data in sync with the UI.
func syncToInventory() -> void:
	if _inventory == null:
		return
	var newOrder: Array = []
	for i in get_child_count():
		var slot := get_child(i) as ItemDisplayContainer
		var item := slot.getItem()
		if item != null:
			item.gridSlotIndex = i
		newOrder.append(item)  # null for empty slots, filtered in reorderItems
	_inventory.reorderItems(newOrder)
