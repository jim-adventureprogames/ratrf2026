class_name ItemDisplayContainer
extends TextureRect

# The item image displayed inside the container.
@export var imgItem: TextureRect

# Stack count label — hidden when the stack is only 1.
@export var lblCount: Label

var _currentItem: Item = null


# Assigns an item and refreshes the display.
func setItem(item: Item) -> void:
	_currentItem      = item
	imgItem.texture   = item.getImage()
	imgItem.visible   = true
	if item.count > 1:
		lblCount.text    = str(item.count)
		lblCount.visible = true
	else:
		lblCount.visible = false


# Clears the item and resets the display to an empty slot.
func clearItem() -> void:
	_currentItem     = null
	imgItem.texture  = null
	imgItem.visible  = false
	lblCount.visible = false


# Returns the currently assigned item, or null if the slot is empty.
func getItem() -> Item:
	return _currentItem


# ── Drag and drop ─────────────────────────────────────────────────────────────

func _get_drag_data(at_position: Vector2) -> Variant:
	if _currentItem == null:
		return null
	# Build a small preview that follows the cursor.
	var preview    := TextureRect.new()
	preview.texture          = imgItem.texture
	preview.custom_minimum_size = imgItem.size
	set_drag_preview(preview)
	return { "item": _currentItem, "source": self }


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item") and data.has("source")


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var source      := data["source"] as ItemDisplayContainer
	var draggedItem := data["item"]   as Item
	if source == self:
		return
	# Swap: put our current item back in the source, take the dragged item.
	if _currentItem != null:
		source.setItem(_currentItem)
	else:
		source.clearItem()
	setItem(draggedItem)
	# Sync the new display order back to the underlying InventoryComponent.
	var grid := get_parent() as InventoryGrid
	if grid:
		grid.syncToInventory()
