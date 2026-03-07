class_name SellToVendorTransaction
extends RefCounted

# Emitted whenever the staged item list changes (add, remove, or cancel).
# UI should connect to this to refresh totals and item display.
signal stagedItemsChanged

# Modifies the payout the player receives.
# 0.0 = full base value, 0.2 = +20%, -0.2 = -20%, etc.
# Applied as: payout = base * (1.0 + valueMultiplier), clamped to 0.
var valueMultiplier: float = 0.0

var _stagedItems: Array[Item] = []


# ── Staging ───────────────────────────────────────────────────────────────────

# Adds an item to the sale list.
# Returns false if the item is already staged; does nothing in that case.
func addItem(item: Item) -> bool:
	if isStaged(item):
		return false
	_stagedItems.append(item)
	stagedItemsChanged.emit()
	return true


# Removes an item from the sale list.
# No-op if the item is not currently staged.
func removeItem(item: Item) -> void:
	var idx := _findIndex(item)
	if idx >= 0:
		_stagedItems.remove_at(idx)
		stagedItemsChanged.emit()


# Returns true if the item is currently in the staged list.
func isStaged(item: Item) -> bool:
	return _findIndex(item) >= 0


# Returns the staged items. Do not modify the returned array directly.
func getStagedItems() -> Array[Item]:
	return _stagedItems


# ── Value ─────────────────────────────────────────────────────────────────────

# Returns the sum of base values for all staged items, before the multiplier.
func getBaseValue() -> int:
	var total: int = 0
	for item: Item in _stagedItems:
		total += item.getValue() * item.count
	return total


# Returns the coin payout the player will receive after applying valueMultiplier.
# Never returns a negative value.
func getTotalValue() -> int:
	return maxi(0, roundi(float(getBaseValue()) * (1.0 + valueMultiplier)))


# ── Completing / cancelling ───────────────────────────────────────────────────

# Abandons the transaction and clears the staged list.
# Items remain untouched in the player's inventory.
func cancel() -> void:
	_stagedItems.clear()
	stagedItemsChanged.emit()


# Finalises the sale: removes all staged items from the given inventory
# and returns the coin payout the caller should credit to the player.
# Returns 0 if the inventory is null or nothing is staged.
func complete(inventory: InventoryComponent) -> int:
	if inventory == null or _stagedItems.is_empty():
		return 0
	var payout := getTotalValue()
	# Copy the list before clearing so we iterate a stable snapshot.
	var toRemove := _stagedItems.duplicate()
	_stagedItems.clear()
	for item: Item in toRemove:
		inventory.removeItem(item.archetypeName, item.count)
	stagedItemsChanged.emit()
	return payout


# ── Internal ──────────────────────────────────────────────────────────────────

func _findIndex(item: Item) -> int:
	for i: int in _stagedItems.size():
		if _stagedItems[i].itemId == item.itemId:
			return i
	return -1
