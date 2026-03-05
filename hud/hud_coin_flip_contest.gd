class_name HUDCoinFlipContest
extends Control

enum EChallengeFlipState
{
	ready,
	flipping,
	done,
}

static var _instance: HUDCoinFlipContest

static func summon() -> HUDCoinFlipContest:
	return _instance

@export var prefabCoin:   PackedScene
@export var prefabResult: PackedScene
@export var hboxResults:  HBoxContainer

@export var txtChallenge: RichTextLabel
@export var txtStat:      RichTextLabel
@export var txtScore:     RichTextLabel
@export var txtLucky:     RichTextLabel

@export var btnFlip:     Button

signal challengeComplete(bSuccess: bool)

var flipState : EChallengeFlipState;

# Stagger delay between successive coin launches, in seconds.
const LAUNCH_STAGGER := 0.15

# Emitted when a coin finishes settling. bHeads = true for heads, false for tails.
signal coinLanded(bHeads: bool)

var _resultControls:  Array[CoinResultControl] = []
var _pendingCoins:    int = 0   # coins still in the air during a flip
var _nextResultIndex: int = 0
var _totalFlipCoins:  int = 0   # total coins to generate when btnFlip is pressed

var _bSuccess : bool = true;
var _numSuccesses : int = 0;
var _targetNumber : int = 0;

func _ready() -> void:
	_instance = self
	btnFlip.pressed.connect(_onClickFlip)
	hide();


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func setChallenge(title: String, stat: Globals.ERogueStat, luckyCoins: int, requiredSuccesses: int) -> void:
	setRequiredSuccesses(requiredSuccesses)
	txtChallenge.text = title
	txtStat.text      = tr("stat_" + Globals.ERogueStat.keys()[stat].to_lower() + "_name")
	txtLucky.text     = str(luckyCoins)
	var pcc := GameManager.playerEntity.getComponent(&"PlayerCharacterComponent") as PlayerCharacterComponent
	if pcc == null:
		return
	var statScore     := pcc.getStat(stat)
	txtScore.text      = str(statScore)
	_totalFlipCoins    = statScore + luckyCoins

	flipState = EChallengeFlipState.ready;
	btnFlip.text = "FLIP";


func _onClickFlip() -> void:
	match flipState:
		EChallengeFlipState.ready:
			btnFlip.hide()
			var results: Array[bool] = []
			for i in _totalFlipCoins:
				results.append(randi() % 2 == 0)
			flip(results)
		EChallengeFlipState.done:
			challengeComplete.emit(_bSuccess);
			hide();


# Clears the result row and creates one CoinResultControl per required success.
func setRequiredSuccesses(count: int) -> void:
	for child in hboxResults.get_children():
		child.queue_free()
	_resultControls.clear()
	_targetNumber = count;
	for i in count:
		var ctrl := prefabResult.instantiate() as CoinResultControl
		hboxResults.add_child(ctrl)
		_resultControls.append(ctrl)


# Clears any coins from a previous flip, then launches one coin per entry in 'results'.
# true = heads (blue), false = tails (red).
func flip(results: Array[bool]) -> void:
	_clearCoins()
	_pendingCoins    = results.size()
	_nextResultIndex = 0
	for ctrl in _resultControls:
		ctrl.play(&"default")
	for idx in results.size():
		var coin   := _spawnCoin()
		var bHeads := results[idx]
		if idx == 0:
			_launchCoin(coin, bHeads, idx)
		else:
			get_tree().create_timer(idx * LAUNCH_STAGGER).timeout.connect(
					func(): _launchCoin(coin, bHeads, idx))


func _clearCoins() -> void:
	for child in get_children():
		if child is AnimatedSprite2D:
			child.queue_free()


func _spawnCoin() -> AnimatedSprite2D:
	var coin: AnimatedSprite2D
	if prefabCoin:
		coin = prefabCoin.instantiate() as AnimatedSprite2D
	coin.visible = false
	add_child(coin)
	return coin


func _launchCoin(coin: AnimatedSprite2D, bHeads: bool, idx: int) -> void:
	var minX           := 16.0 + 32 * idx
	var startX         := randf_range(minX, minX + 16.0)
	var startY         := 260.0
	var finalX         := startX + randf_range(-8.0, 8.0)
	var finalY         := randf_range(64.0, 96.0)
	var peakY          := finalY - randf_range(32.0, 56.0)
	var riseDuration   := randf_range(0.45, 0.60)
	var settleDuration := 0.12

	coin.position = Vector2(startX, startY)
	coin.play(&"flipping")
	coin.visible  = true

	# X: smooth drift to resting position over the full flight time.
	var tweenX := create_tween()
	tweenX.tween_property(coin, "position:x", finalX, riseDuration + settleDuration) \
			.set_trans(Tween.TRANS_SINE)

	# Y: ease up to peak, reveal result, ease down to rest, then notify.
	var tweenY := create_tween()
	tweenY.tween_property(coin, "position:y", peakY, riseDuration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tweenY.tween_callback(func(): coin.play(&"heads" if bHeads else &"tails"))
	tweenY.tween_property(coin, "position:y", finalY, settleDuration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tweenY.tween_callback(func(): _onCoinLanded(bHeads))


func _onCoinLanded(bHeads: bool) -> void:
	coinLanded.emit(bHeads)
	_pendingCoins -= 1
	if bHeads:
		_numSuccesses += 1;
	if bHeads and _nextResultIndex < _resultControls.size():
		_resultControls[_nextResultIndex].play(&"success")
		_nextResultIndex += 1
	if _pendingCoins <= 0:
		for i in range(_nextResultIndex, _resultControls.size()):
			_resultControls[i].play(&"fail")
			Globals.shakeControl(_resultControls[i], 4.0, 0.5)
		_bSuccess  = _numSuccesses >= _targetNumber
		flipState  = EChallengeFlipState.done
		_onChallengeComplete()


func _onChallengeComplete() -> void:
	btnFlip.text = "WIN!" if _bSuccess else "FAIL!"
	btnFlip.show()
	if not _bSuccess:
		Globals.shakeControl(btnFlip, 4.0, 0.5)
	
