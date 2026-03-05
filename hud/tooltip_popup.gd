class_name TooltipPopup
extends Control

# Minimum display width — matches the MarginContainer's initial offset_right in the scene.
const TOOLTIP_WIDTH  := 170.0
const TOOLTIP_HEIGHT :=  50.0
# Gap between the hovered item and the left edge of the tooltip.
const OFFSET_FROM_ITEM := 4.0

@export var itemBox         : ItemDisplayContainer
@export var itemTierDisplay : ItemTierDisplay
@export var txtName         : Label
@export var txtFlavor       : Label
@export var txtValue        : Label           

var targetItem : Item


func populate(item: Item) -> void:
	targetItem = item
	itemBox.setItem(item)
	itemTierDisplay.setItemTier(item.getTier())
	txtName.text   = item.getFriendlyName()
	txtFlavor.text = item.getFlavorText()
	var coinValue := item.getValue()
	if coinValue > 0:
		txtValue.text    = "$%d.%02d" % [coinValue / 100, coinValue % 100]
		txtValue.visible = true
	else:
		txtValue.visible = false


# Shows the tooltip for an item, positioned near the given canvas coordinate.
func showForItem(item: Item, canvasPos: Vector2) -> void:
	populate(item)
	_positionNear(canvasPos)
	show()


# Places the inner container near canvasPos.
# TODO: replace with proper dynamic positioning once size reporting is sorted.
func _positionNear(_canvasPos: Vector2) -> void:
	global_position = Vector2(48, 48)
