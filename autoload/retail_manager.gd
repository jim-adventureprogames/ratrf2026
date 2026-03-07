extends Node

# Registry of all active MerchantComponents in the world.
var _registeredMerchants: Array[MerchantComponent] = []

# Maps shopId → MerchantComponent for merchants that have been assigned an ID.
var _merchantsByShopId: Dictionary = {}  # int → MerchantComponent

var _nextShopId: int = 0


func registerMerchant(merchant: MerchantComponent) -> void:
	if not _registeredMerchants.has(merchant):
		_registeredMerchants.append(merchant)


func unregisterMerchant(merchant: MerchantComponent) -> void:
	_registeredMerchants.erase(merchant)
	if merchant.shopId >= 0:
		_merchantsByShopId.erase(merchant.shopId)


# Assigns a unique shop ID to the merchant and returns a dictionary of shop
# info strings.  Calling this a second time on the same merchant removes the
# old ID and issues a new one.
func generateInfoForShop(merchant: MerchantComponent, numRacks: int) -> Dictionary:
	# Clean up any previous ID this merchant held.
	if merchant.shopId >= 0:
		_merchantsByShopId.erase(merchant.shopId)

	var id       := _nextShopId
	_nextShopId  += 1
	merchant.shopId              = id
	_merchantsByShopId[id]       = merchant

	var info: Dictionary = {}

	info["shopId"] = str(id)
	info["sign_message"] = "Ye Olde Shoppe"
	
	var shopRackItems : Array[Item];
	
	for idx in numRacks:
		var archetype := RandomTable.rollOnTable("clothing_loot_table_01")
		var newItem = Item.new(archetype);
		#maybe item becomes unique
		#maybe item gets fancy name?
		shopRackItems.append(newItem);
		
	info["shop_items"] = shopRackItems;
	
	return info


# Returns the MerchantComponent registered to the given shop ID, or null.
func getMerchantByID(shopId: int) -> MerchantComponent:
	return _merchantsByShopId.get(shopId, null)
