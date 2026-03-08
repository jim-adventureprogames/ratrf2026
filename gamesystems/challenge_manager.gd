extends Node

static var _instance: ChallengeManager


static func summon() -> ChallengeManager:
	return _instance

var activeChallengeType : String
var targetEntities : Dictionary[String, Entity];

var challengeSuccessCount : Dictionary[String, int];

func _ready() -> void:
	_instance = self
	Console.add_command("test_challenge", _cmdTestChallenge, [], 0, "Shows the coin flip challenge HUD with a test FastTalk challenge.")


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Clears all per-run challenge state for a fresh game.
# challengeSuccessCount tracks escalating difficulty (e.g. guards get harder
# to talk down each time the player is caught), so it must be wiped on reset.
#
# Add any new per-run state here as challenges are expanded.
func resetForNewGame() -> void:
	# Cancel any challenge that was mid-flight when the reset was triggered.
	activeChallengeType = ""
	targetEntities.clear()

	# Reset difficulty escalation — every playthrough starts fresh.
	challengeSuccessCount.clear()


static func BeginChallenge(challengeType: String) -> void:
	_instance._beginChallengeInternal(challengeType);
	pass
	
func _beginChallengeInternal(challengeType: String) -> void:
	var pcc := GameManager.getPlayerComponent();
	
	activeChallengeType = challengeType;
	var requiredSuccess = 1;
	
	match activeChallengeType:
		"fast_talk_guard":
			requiredSuccess = _getNumSuccessesRequiredForFastTalkGuard();
			_startChallenge("challenge_fasttalk_guard", Globals.ERogueStat.FastTalk, 
			pcc.getLuckyCoins(), requiredSuccess);
			
		"haggle_merchant":
			var mc = GameManager.getTargetMerchant();
			requiredSuccess = mc.getHaggleDifficulty();
			_startChallenge("challenge_haggle", Globals.ERogueStat.Haggle, 
			pcc.getLuckyCoins(), requiredSuccess);
			
				

func _startChallenge(title: String, stat: Globals.ERogueStat, luckyCoins: int, requiredSuccesses: int) -> void:
	GameManager.setGamePhase(GameManager.EGamePhase.CoinChallenge);
	var hud := HUDCoinFlipContest.summon()
	if hud == null:
		return
	hud.show()
	hud.setChallenge(title, stat, luckyCoins, requiredSuccesses)
	if not hud.challengeComplete.is_connected(HandleChallengeComplete):
		hud.challengeComplete.connect(HandleChallengeComplete)


func HandleChallengeComplete(bSuccess: bool) -> void:
	if( GameManager.getGamePhase() == GameManager.EGamePhase.CoinChallenge):
		GameManager.setGamePhase(GameManager.EGamePhase.Player);

	if bSuccess:
		challengeSuccessCount[activeChallengeType] = challengeSuccessCount.get_or_add(activeChallengeType, 1) + 1
		# Award FUN for winning any coin flip challenge.
		var fm := FunManager.summon()
		if fm:
			fm.addFun(FunManager.FUN_COIN_CHALLENGE, "coin challenge win: " + activeChallengeType)

	match activeChallengeType:
		"fast_talk_guard":
			if( bSuccess ):
				GameManager.cancelGuardAlert.emit();
				GameManager.spawnDialog("guard_dialog", "let_player_go", targetEntities["guard"])
			else:
				GameManager.goToGameOver("caught");
		
		"haggle_merchant":
			var mc = GameManager.getTargetMerchant()
			if bSuccess:
				mc.onHaggleSuccess()
			else:
				mc.onHaggleFail()
			# Notify whichever merchant HUD is currently open.
			if HUD_SellToMerchant.summon() and HUD_SellToMerchant.summon().visible:
				HUD_SellToMerchant.summon().applyHaggleResult(mc.haggleMultiplier)
			if HUD_BuyFromMerchant.summon() and HUD_BuyFromMerchant.summon().visible:
				HUD_BuyFromMerchant.summon().applyHaggleResult(mc.haggleMultiplier)

				
	activeChallengeType = "";
	targetEntities.clear();
	pass


func _cmdTestChallenge() -> void:
	if HUDCoinFlipContest.summon() == null:
		Console.print_warning("test_challenge: HUD_CoinFlipContest not ready.")
		return
	_startChallenge("Talk your way out of trouble.", Globals.ERogueStat.FastTalk, 2, 2)
	Console.print_line("test_challenge: ready. Click flip!")


# number go up each time the player gets caught.
func _getNumSuccessesRequiredForFastTalkGuard() -> int:
	return 1 + challengeSuccessCount.get_or_add("fast_talk_guard" , 0);
	
func clearTargetEntities() -> void:
	targetEntities.clear();
		
func setTargetEntity(key: String, value: Entity) -> void:
	targetEntities[key] = value;
