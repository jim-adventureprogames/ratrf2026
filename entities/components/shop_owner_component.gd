class_name ShopOwnerComponent
extends AIBehaviorComponent

# This component exists to help a MerchantComponent connect to all the cool things
# in the shop, like signs and other vendor bits and bobs. It also helps them
# behave correctly in the shop.

var myShopSigns: Array[ReadableSignComponent];
var myItemRacks: Array[ItemRackComponent];


func decideWhatToDo() -> void:
	#do nothing for now
	return

func onPostStampCleanup(stampedEntities: Array[Entity], properties: Dictionary) -> void:
	
	for peer: Entity in stampedEntities:
		var itemRack = peer.getComponent(&"ItemRackComponent") as ItemRackComponent;
		if( itemRack ):
			myItemRacks.append(itemRack);
		var sign = peer.getComponent(&"ReadableSignComponent") as ReadableSignComponent
		if( sign ):
			myShopSigns.append(sign);

	_prepareShopInformation();

func _prepareShopInformation() -> void:
	var mc = entity.getComponent(&"MerchantComponent") as MerchantComponent;
	var inventory = entity.getComponent(&"InventoryComponent") as InventoryComponent;
	var shopDictionary = RetailManager.generateInfoForShop(mc, myItemRacks.size());
	
	#assign a dialog_file and dialog_key to every sign based on our name.
	for sign in myShopSigns:
		sign.message = shopDictionary["sign_message"];
		
	var shopItems := shopDictionary["shop_items"] as Array[Item];
	
	var idxItem = 0;
	for rack in myItemRacks :
		rack.assignItem(shopItems[idxItem]);
		inventory.addItem(shopItems[idxItem]);
		idxItem += 1;
	
