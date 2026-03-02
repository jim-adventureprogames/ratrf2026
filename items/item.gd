class_name Item
extends RefCounted

# The archetype key that links this instance to its ItemData.
var archetypeName: String = ""

# How many of this item this stack represents.
var count: int = 1


func _init(archetype: String, stackCount: int = 1) -> void:
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
