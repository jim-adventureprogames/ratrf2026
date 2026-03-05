class_name Item
extends RefCounted

static var _nextId: int = 0

# Unique ID assigned at construction time.
var itemId: int = -1

# The archetype key that links this instance to its ItemData.
var archetypeName: String = ""

# How many of this item this stack represents.
var count: int = 1

# The last slot index this item occupied in an InventoryGrid (-1 = unassigned).
# Written by InventoryGrid.syncToInventory() and used by refresh() to restore position.
var gridSlotIndex: int = -1


func _init(archetype: String, stackCount: int = 1) -> void:
	itemId        = Item._nextId
	Item._nextId += 1
	archetypeName = archetype
	count         = stackCount


# Returns the display name from this item's archetype data.
# friendlyName is a translation key, so tr() is applied here.
func getFriendlyName() -> String:
	var data := ItemData.getByArchetype(archetypeName)
	if data == null:
		return archetypeName  # fallback: show the raw key
	return tr(data.friendlyName)


# Returns the flavour text. Also a translation key.
func getFlavorText() -> String:
	var data := ItemData.getByArchetype(archetypeName)
	if data == null:
		return ""
	return tr(data.flavorText)


# Returns the coin value of this item.
func getValue() -> int:
	var data := ItemData.getByArchetype(archetypeName)
	if data == null:
		return 0
	return data.value


# Returns the inventory/UI image for this item.
func getImage() -> Texture2D:
	var data := ItemData.getByArchetype(archetypeName)
	if data == null:
		return null
	return data.image


# Returns true if this item is unique — never stacks, one per slot.
func isUnique() -> bool:
	var data := ItemData.getByArchetype(archetypeName)
	if data == null:
		return false
	return data.bUnique


# Returns the quality tier of this item (1 = base).
func getTier() -> int:
	var data := ItemData.getByArchetype(archetypeName)
	if data == null:
		return 1
	return data.tier
