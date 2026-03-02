@tool
class_name ItemData
extends Resource

# The unique key used to look up this archetype.
# Setting this auto-populates friendlyName and flavorText with their
# conventional translation keys, which can still be overridden manually.
@export var archetypeName: String = "":
	set(value):
		archetypeName = value
		friendlyName  = "itemname_" + value
		flavorText    = "flavor_"   + value
		emit_changed()

# Translation key — passed through tr() at display time.
@export var friendlyName: String = ""

# Flavour text shown in item descriptions. Also a translation key.
@export var flavorText: String = ""

# Coin value of this item.
@export var value: int = 0

# Maximum number of this item that can share a single inventory slot.
@export var maxStackCount: int = 99

# Inventory/UI image for this item.
@export var image: Texture2D = null

# ── Static registry ───────────────────────────────────────────────────────────

static var _registry: Dictionary = {}  # String → ItemData


# Loads all ItemData .tres files from res://items/data/.
# Called once at startup by Globals._ready().
static func loadAll() -> void:
	var dir := DirAccess.open("res://items/data")
	if dir == null:
		push_error("ItemData: could not open res://items/data directory")
		return
	dir.list_dir_begin()
	var fileName := dir.get_next()
	while fileName != "":
		if not dir.current_is_dir() and fileName.ends_with(".tres"):
			var data := load("res://items/data/" + fileName) as ItemData
			if data == null:
				push_warning("ItemData: skipping non-ItemData resource: %s" % fileName)
			elif data.archetypeName.is_empty():
				push_warning("ItemData: resource has no archetypeName, skipping: %s" % fileName)
			else:
				_registry[data.archetypeName] = data
		fileName = dir.get_next()
	dir.list_dir_end()


# Returns the ItemData for the given archetype name, or null if not found.
static func getByArchetype(archetypeName: String) -> ItemData:
	var data := _registry.get(archetypeName) as ItemData
	if data == null:
		push_error("ItemData: no archetype registered for '%s'" % archetypeName)
	return data
