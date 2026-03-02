class_name InventoryComponent
extends EntityComponent

signal itemsChanged

# Maximum number of item stacks this inventory can hold. 0 = unlimited.
@export var maxItems: int = 0

var _items:     Array[Item] = []
var _coinPurse: int         = 0


# ── Coin purse ────────────────────────────────────────────────────────────────

func getCoin() -> int:
	return _coinPurse

func setCoin(amount: int) -> void:
	_coinPurse = max(0, amount)

func addCoin(amount: int) -> void:
	_coinPurse += amount

# Deducts amount and returns true. Returns false without deducting if insufficient funds.
func removeCoin(amount: int) -> bool:
	if _coinPurse < amount:
		return false
	_coinPurse -= amount
	return true

func canAfford(amount: int) -> bool:
	return _coinPurse >= amount

# Returns the purse balance as a formatted dollars-and-cents string (e.g. "$3.07").
func getDisplayCoin() -> String:
	var dollars := _coinPurse / 100
	var cents   := _coinPurse % 100
	return "$%d.%02d" % [dollars, cents]


# Returns all item stacks in this inventory.
func getItems() -> Array[Item]:
	return _items


# Returns the first stack matching the given archetype, or null if not present.
func findItem(archetypeName: String) -> Item:
	for item: Item in _items:
		if item.archetypeName == archetypeName:
			return item
	return null


# Returns true if the inventory contains at least one of the given archetype.
func hasItem(archetypeName: String) -> bool:
	return findItem(archetypeName) != null


# Adds an item to the inventory, respecting each stack's maxStackCount.
# Fills existing stacks first, then opens new slots for any overflow.
# Returns the number of items that could NOT be placed (0 = everything fit).
func addItem(item: Item) -> int:
	var data      := ItemData.getByArchetype(item.archetypeName)
	var maxStack  := data.maxStackCount if data else 99
	var remaining := item.count

	# Fill existing stacks of the same archetype up to their cap.
	for existing: Item in _items:
		if existing.archetypeName != item.archetypeName:
			continue
		var space := maxStack - existing.count
		if space > 0:
			var toAdd      := mini(remaining, space)
			existing.count += toAdd
			remaining      -= toAdd
		if remaining == 0:
			break

	# Open new slots for whatever is left.
	while remaining > 0:
		if maxItems > 0 and _items.size() >= maxItems:
			itemsChanged.emit()
			return remaining  # inventory full — caller handles the leftovers
		var newStack := Item.new(item.archetypeName, mini(remaining, maxStack))
		_items.append(newStack)
		remaining -= newStack.count

	itemsChanged.emit()
	return 0


# Replaces the item order with a new sequence, skipping null entries.
# Called by InventoryGrid after a drag-and-drop reorder.
func reorderItems(newOrder: Array) -> void:
	_items.clear()
	for item in newOrder:
		if item is Item:
			_items.append(item)


# Removes the given count from the stack matching archetypeName.
# Removes the stack entirely when its count reaches zero.
# Returns false if the archetype is not present or has insufficient count.
func removeItem(archetypeName: String, count: int = 1) -> bool:
	var existing := findItem(archetypeName)
	if existing == null or existing.count < count:
		return false
	existing.count -= count
	if existing.count <= 0:
		_items.erase(existing)
	itemsChanged.emit()
	return true
