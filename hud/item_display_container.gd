class_name ItemDisplayContainer
extends TextureRect

# The item image displayed inside the container.
@export var imgItem: TextureRect

# Stack count label — hidden when the stack is only 1.
@export var lblCount: Label

var _currentItem: Item = null

# Seconds of continuous hover required before item_hovered fires.
const HOVER_DELAY := 0.5

# Emitted immediately when the cursor enters a filled slot.
signal item_entered(item: Item)
# Emitted after the hover delay if the cursor is still over a filled slot.
signal item_hovered(item: Item, canvas_pos: Vector2)
# Emitted immediately when the cursor leaves, regardless of delay state.
signal item_unhovered()
# Emitted when the player right-clicks a filled slot.
signal item_right_clicked(item: Item)

# True while the cursor is inside this control waiting for the delay to expire.
var _hoverPending: bool = false


func _ready() -> void:
	mouse_entered.connect(_onMouseEntered)
	mouse_exited.connect(_onMouseExited)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _currentItem != null:
		item_right_clicked.emit(_currentItem)


func _onMouseEntered() -> void:
	if _currentItem == null:
		return
	item_entered.emit(_currentItem)
	_hoverPending = true
	get_tree().create_timer(HOVER_DELAY).timeout.connect(_onHoverTimerExpired)


func _onMouseExited() -> void:
	_hoverPending = false
	item_unhovered.emit()


func _onHoverTimerExpired() -> void:
	if _hoverPending and _currentItem != null:
		item_hovered.emit(_currentItem, get_global_rect().position)


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


# Dims the slot to 50 % opacity when true; restores full opacity when false.
func setDimmed(bDimmed: bool) -> void:
	modulate.a = 0.5 if bDimmed else 1.0


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
