class_name HUD_GameOver
extends Control

static var _instance: HUD_GameOver

static func summon() -> HUD_GameOver:
	return _instance


# Wire in the editor.
@export var btnMainMenu:   Button
@export var txtFinalScore: Label
# Shown below the score — "You were caught!", "You escaped!", etc.
@export var txtReason:     Label

# shows final time played as "X turns (Y hours, Z minutes)"
@export var txtTurnsPlayed: Label

# shows fun as an int
@export var txtFun : Label

# shows final money in $x.yy format
@export var txtMoney : Label

# Maps the short reason key (passed from GameManager.goToGameOver / goToVictory)
# to human-readable copy.  Add entries here as new endings are written.
const _REASON_STRINGS: Dictionary = {
	"caught":   "You were caught stealing! The guards took all your money and tossed your ass out.",
	"defeated": "You were defeated.",
	"victory":  "You had a great day and left on your own terms!",
}


func _ready() -> void:
	_instance = self
	btnMainMenu.pressed.connect(_onMainMenuPressed)
	hide()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Displays the game-over screen.
# reason — short key like "caught", "defeated", or "victory"
# finalScore — pre-computed by FunManager.getFinalScore()
# bVictory — true for a winning run; false for a loss.  Controls the
#            tone of the display (could swap colors, show different art, etc.)
func showResult(reason: String, finalScore: int, bVictory: bool, coins: int = 0) -> void:
	HUD_ScreenFader.summon().fadeToClear(0.5);
	
	if txtReason:
		txtReason.text = str(_REASON_STRINGS.get(reason, reason))

	if txtFinalScore:
		txtFinalScore.text = "%d" % finalScore

	if txtMoney:
		txtMoney.text = "$%d.%02d" % [coins / 100, coins % 100]

	if txtFun:
		var fm := FunManager.summon()
		txtFun.text = "%d" % (fm.funScore if fm else 0)

	if txtTurnsPlayed:
		var tk := GameManager.timeKeeper
		if tk:
			var turns   := tk.getTurns()
			var elapsed := turns * tk.numberOfSecondsInTurn
			var hours   := int(elapsed / 3600)
			var minutes := int(fmod(elapsed, 3600.0) / 60)
			txtTurnsPlayed.text = "%d turns (%dh %02dm)" % [turns, hours, minutes]

	show()


func _onMainMenuPressed() -> void:
	hide()
	# Tear down the world and return to the title screen.
	# resetForNewGame() will call HUD_TitleScreen.turnOn() if wired up there.
	GameManager.resetForNewGame()
