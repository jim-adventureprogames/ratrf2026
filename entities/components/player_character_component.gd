class_name PlayerCharacterComponent
extends EntityComponent

signal apDepleted
signal staminaChanged(newValue: float)
signal hydrationChanged(newValue: float)

@export var maxAP: float = 1.0

var currentAP: float = 1.0

var stats : Dictionary[Globals.ERogueStat, int];
var luckyCoins : int;

# reaches 0 you run at half speed
var stamina : float = 100.0

# reaches 0 you pass out
var hydration : float = 100.0

func _initialize() -> void:
	super._initialize()
	onNewGame();
	
	
func onNewGame() -> void:
	luckyCoins = 0
	stats.set(Globals.ERogueStat.Carouse, 2)
	stats.set(Globals.ERogueStat.FastTalk, 2)
	stats.set(Globals.ERogueStat.Haggle, 2)
	stats.set(Globals.ERogueStat.Lockpick, 2)
	maxAP     = 1
	currentAP = 1
	stamina   = 100.0
	hydration = 100.0
	staminaChanged.emit(stamina)
	hydrationChanged.emit(hydration)

# Deducts one action point. Emits apDepleted when the last AP is spent.
func spendAP() -> void:
	currentAP -= 1.0
	if currentAP <= 0:
		currentAP = 0
		apDepleted.emit()


# Restore AP at the end of each full turn cycle.
func onEndOfTurn() -> void:
	if( stamina <= 0.0 ):
		currentAP += 0.5
	else:
		currentAP += 1.0;
		
	currentAP = min(currentAP,maxAP)
	
	#shade bonus, check this out
	
	stamina   = clampf(stamina   - GameManager.timeKeeper.getStaminaCostPerRound(),   0.0, 100.0)
	hydration = clampf(hydration - GameManager.timeKeeper.getHydrationCostPerRound(), 0.0, 100.0)
	staminaChanged.emit(stamina)
	hydrationChanged.emit(hydration)
	
# Consumes one of the given item: restores stamina/hydration and removes it
# from the player's InventoryComponent.
func consumeItem(item: Item) -> void:
	stamina   = clampf(stamina   + item.getRestoreStamina(),   0.0, 100.0)
	hydration = clampf(hydration + item.getRestoreHydration(), 0.0, 100.0)
	staminaChanged.emit(stamina)
	hydrationChanged.emit(hydration)
	var inv := entity.getComponent(&"InventoryComponent") as InventoryComponent
	if inv:
		inv.removeItem(item.archetypeName, 1)


func getStat(stat : Globals.ERogueStat) -> int:
	return stats[stat];
	
func getLuckyCoins() -> int:
	return luckyCoins;
