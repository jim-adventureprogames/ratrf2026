extends Node

static var _instance: FunManager

static func summon() -> FunManager:
	return _instance


# FUN is the excitement currency — earned by doing risky or clever things.
# It accumulates over the run and contributes to the final score.
signal funChanged(newScore: int)

var funScore: int = 0

# Each coin cent contributes this much to the final score.
# Default 0.01 means $1.00 = 1 FUN point, keeping money a minor bonus
# relative to the FUN earned from high-risk play.
# Tune this in the inspector to shift the score weight toward money.
@export var finalScoreMoneyMultiplier: float = 0.01

# FUN values for each trigger type.  Adjust these to tune how exciting
# each action feels relative to the others.
const FUN_GUARD_CHASE:    int = 20  # a guard begins chasing the player
const FUN_PICKPOCKET:     int = 5   # successful pickpocket of any item or coin
const FUN_COIN_CHALLENGE: int = 10  # player wins a coin flip challenge


func _ready() -> void:
	_instance = self
	# Award FUN automatically when a guard first spots the player.
	# CrimeManager is an autoload so it should already exist when this fires.
	CrimeManager.summon().chaseStarted.connect(_onChaseStarted)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Awards FUN and logs the event so the designer can track score growth.
# reason is a short human-readable label for the log (e.g. "pickpocket").
func addFun(amount: int, reason: String) -> void:
	funScore += amount
	print("FunManager: +%d FUN [%s] → total %d" % [amount, reason, funScore])
	funChanged.emit(funScore)


# Computes the final run score from accumulated FUN and the player's money.
# coins is the raw cent value from InventoryComponent.getCoin().
# Score = funScore + floor(coins * finalScoreMoneyMultiplier)
func getFinalScore(coins: int) -> int:
	return funScore + int(float(coins) * finalScoreMoneyMultiplier)


# Wipes all per-run state so the next run starts from zero.
func resetForNewGame() -> void:
	funScore = 0


func _onChaseStarted() -> void:
	addFun(FUN_GUARD_CHASE, "guard chase")
