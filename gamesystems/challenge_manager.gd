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


static func BeginChallenge(challengeType: String) -> void:
	_instance._beginChallengeInternal(challengeType);
	pass
	
func _beginChallengeInternal(challengeType: String) -> void:
	var pcc := GameManager.getPlayerComponent();
	
	activeChallengeType = challengeType;
	
	match activeChallengeType:
		"fast_talk_guard":
			var requiredSuccess = _getNumSuccessesRequiredForFastTalkGuard();
			_startChallenge("challenge_fasttalk_guard", Globals.ERogueStat.FastTalk, 
			pcc.getLuckyCoins, requiredSuccess);
			
			
				

func _startChallenge(title: String, stat: Globals.ERogueStat, luckyCoins: int, requiredSuccesses: int) -> void:
	var hud := HUDCoinFlipContest.summon()
	if hud == null:
		return
	hud.show()
	hud.setChallenge(title, stat, luckyCoins, requiredSuccesses)
	if not hud.challengeComplete.is_connected(HandleChallengeComplete):
		hud.challengeComplete.connect(HandleChallengeComplete)


func HandleChallengeComplete(bSuccess: bool) -> void:
	
	if( bSuccess ) :
		challengeSuccessCount[activeChallengeType] = challengeSuccessCount.get_or_add(activeChallengeType, 1) + 1;
	
	
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
