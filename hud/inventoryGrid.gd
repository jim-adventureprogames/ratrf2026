class_name InventoryGrid
extends GridContainer

@export var maxWidth:            int        = 6
@export var maxHeight:           int        = 6
@export var itemContainerPrefab: PackedScene

var _inventory: InventoryComponent


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
# Called automatically when itemsChanged fires; also safe to call directly.
func refresh() -> void:
	for child in get_children():
		child.queue_free()

	var items      := _inventory.getItems()
	var totalSlots := maxWidth * maxHeight

	for i in totalSlots:
		var slot := itemContainerPrefab.instantiate() as ItemDisplayContainer
		add_child(slot)
		if i < items.size():
			slot.setItem(items[i])
		else:
			slot.clearItem()


# Rebuilds the inventory's item order from the current slot display state.
# Called after every drag-and-drop to keep the data in sync with the UI.
func syncToInventory() -> void:
	if _inventory == null:
		return
	var newOrder: Array = []
	for child in get_children():
		newOrder.append(child.getItem())  # null for empty slots, filtered in reorderItems
	_inventory.reorderItems(newOrder)
