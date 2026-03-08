class_name MerchantComponent
extends EntityComponent

@export var bAllowBuyFrom : bool
@export var bAllowSellTo : bool

#For first time vending.
@export var tablePopulateInventory : String

# the .dialogue we're using
@export var dialogFile : String

# where to start when vending
@export var dialogKeyStartVend : String

# where to start when the player is under alart
@export var dialogKeyWhileAlart : String

# how much more or less we value goods sold to us by the player.
@export var haggleMultiplier : float = -0.1;

# how many flips are needed to successfully haggle with us.
var haggleDifficulty : int = 1;

# Assigned by RetailManager.generateInfoForShop(); -1 means not yet assigned.
var shopId: int = -1;

@export var clip_onOpenSell : AudioStream;
@export var clip_onOpenBuy : AudioStream;
@export var clip_onSuccessfulTransaction : AudioStream;
@export var clip_onCancelTransaction : AudioStream;

func onAttached() -> void:
	super.onAttached()
	RetailManager.registerMerchant(self)
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable:
		bumpable.bumped.connect(_onBumped)
	else:
		push_warning("MarkComponent: no BumpableComponent found on entity '%s'." % entity.name)
	# var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	# if mover:
	# 	mover.movementBlocked.connect(_onMovementBlocked)
	
	updateSpriteBorder();

func onDetached() -> void:
	RetailManager.unregisterMerchant(self)
	var bumpable := entity.getComponent(&"BumpableComponent") as BumpableComponent
	if bumpable and bumpable.bumped.is_connected(_onBumped):
		bumpable.bumped.disconnect(_onBumped)
	# var mover := entity.getComponent(&"MoverComponent") as MoverComponent
	# if mover and mover.movementBlocked.is_connected(_onMovementBlocked):
	#	 mover.movementBlocked.disconnect(_onMovementBlocked)
		
func _onBumped(bumper: Entity) -> void:
	if( bumper == GameManager.playerEntity):
		if CrimeManager.getAlertRatio() > 0.0 :
			GameManager.spawnDialog(dialogFile, dialogKeyWhileAlart, entity);
		else:
			GameManager.spawnDialog(dialogFile, dialogKeyStartVend, entity);
			
		GameManager.setTargetMerchant(self);
		
func updateSpriteBorder() -> void:
	var sprite = entity.getComponent(&"SpriteComponent") as SpriteComponent;
	if sprite:
		sprite.setBorderState(SpriteComponent.ESpriteBorderStyle.is_merchant)

		
		
func onBeginTransactionSellToMe(inventory : InventoryComponent) -> void:
	var tx := SellToVendorTransaction.new()
	tx.valueMultiplier = haggleMultiplier
	HUD_SellToMerchant.summon().beginTransaction(inventory, tx)
	AudioManager.playSfx(clip_onOpenSell)

func onBeginTransactionBuyFromMe() -> void:
	var inv = entity.getComponent(&"InventoryComponent") as InventoryComponent;
	if( inv.is_empty() ) :
		inv.fill_for_shop(tablePopulateInventory);

	AudioManager.playSfx(clip_onOpenBuy)
	HUD_BuyFromMerchant.summon().open(self)

func onTransactionComplete() -> void:
	AudioManager.playSfx(clip_onSuccessfulTransaction)

func onTransactionCancel() -> void:
	AudioManager.playSfx(clip_onCancelTransaction)
		
	
func getHaggleDifficulty() -> int:
	return haggleDifficulty;
	
func onHaggleSuccess() -> void:
	if( bAllowBuyFrom ) :
		haggleMultiplier -= randf() * 0.2 + 0.1;
	else :
		haggleMultiplier += randf() * 0.2 + 0.1;
	haggleDifficulty += 1;
	
func onHaggleFail() -> void:
	if( bAllowBuyFrom ):
		haggleMultiplier += randf() * 0.1 + 0.05;
		if( haggleDifficulty > 1 ):
			haggleDifficulty -= 1;
	else:
		haggleMultiplier -= randf() * 0.1 + 0.05;
		if( haggleMultiplier <= 0.0 && haggleDifficulty > 1 ) :
			haggleDifficulty -= 1;

	
		
		
		
		
		
		
