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

# Quality tier — 1 is base quality, higher values indicate better items.
@export var tier: int = 1:
	set(value):
		tier = max(1, value)
		emit_changed()

# Relative probability weight used when this item is added to a loot table.
@export var dropWeight: int = 10

# When true, right-clicking this item in the player inventory consumes it.
@export var bConsumable: bool = false

# Stamina restored on consumption (0 = none).
@export var restoreStamina: float = 0.0

# Hydration restored on consumption (0 = none).
@export var restoreHydration: float = 0.0

# When true, this item never stacks and each instance occupies its own slot.
# Takes precedence over maxStackCount.
@export var bUnique: bool = false

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
		# In exported builds Godot appends ".remap" to resource filenames.
		# Strip it before loading — load() resolves the remap automatically.
		var baseName := fileName.trim_suffix(".remap")
		if not dir.current_is_dir() and baseName.ends_with(".tres"):
			var data := load("res://items/data/" + baseName) as ItemData
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


# Adds every item of the given tier to a named RandomTable with the supplied weight.
# Call after both ItemData.loadAll() and RandomTable tables are loaded.
static func populateTierIntoTable(tier: int, tableName: String) -> void:
	for data: ItemData in _registry.values():
		if data.tier == tier:
			RandomTable.addEntryToTable(tableName, data.archetypeName, data.dropWeight)
