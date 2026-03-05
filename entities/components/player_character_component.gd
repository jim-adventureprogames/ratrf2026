class_name PlayerCharacterComponent
extends EntityComponent

signal apDepleted

@export var maxAP: int = 1

var currentAP: int = 1

var stats : Dictionary[Globals.ERogueStat, int];
var luckyCoins : int;

func _initialize() -> void:
	super._initialize()
	
	
func onNewGame() -> void : 
	luckyCoins = 0;
	stats.set(Globals.ERogueStat.Charm, 2)
	stats.set(Globals.ERogueStat.FastTalk, 2)
	stats.set(Globals.ERogueStat.Haggle, 2)
	stats.set(Globals.ERogueStat.Lockpick, 2)
	maxAP = 1;
	currentAP = 1;

# Deducts one action point. Emits apDepleted when the last AP is spent.
func spendAP() -> void:
	currentAP -= 1
	if currentAP <= 0:
		currentAP = 0
		apDepleted.emit()


# Restore AP at the end of each full turn cycle.
func onEndOfTurn() -> void:
	currentAP = maxAP
	
func getStat(stat : Globals.ERogueStat) -> int:
	return stats[stat];
	
func getLuckyCoins() -> int:
	return luckyCoins;
