class_name HUDDialog
extends Control

static var _instance: HUDDialog

static func summon() -> HUDDialog:
	return _instance

static func turnOn() -> void:
	if _instance:
		_instance.show();
		_instance._animateIn()

static func turnOff() -> void:
	if _instance:
		_instance._animateOut()

@export var dboxSpeak:  DialogBox_Speak
@export var dboxAnswer: DialogBox_Answer

# Duration of each box's slide, and how early the second box starts.
const SLIDE_DURATION := 0.20
const SLIDE_STAGGER  := 0.10

var _restPosSpeak:  Vector2
var _restPosAnswer: Vector2
var _activeTween:   Tween


func _ready() -> void:
	_instance    = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Capture the editor-placed positions as the "shown" resting positions.
	_restPosSpeak  = dboxSpeak.position
	_restPosAnswer = dboxAnswer.position
	# Park both boxes off-screen and hide them so they can't eat input.
	var w := get_viewport_rect().size.x
	dboxSpeak.position.x  = _restPosSpeak.x  - w
	dboxAnswer.position.x = _restPosAnswer.x + w
	dboxSpeak.hide()
	dboxAnswer.hide()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Sets the speak box content and populates answer replies from a DialogueLine.
# Call this before turnOn(), or after if the boxes are already visible.
func presentLine(line: DialogueLine, speakerEntity: Entity) -> void:
	dboxSpeak.speak(speakerEntity, line)
	dboxAnswer.populateFromLine(line)


# Speak slides in from the left first; answer follows before speak settles.
func _animateIn() -> void:
	if _activeTween:
		_activeTween.kill()
	dboxSpeak.show()
	dboxAnswer.show()
	_activeTween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_activeTween.tween_property(dboxSpeak,  "position:x", _restPosSpeak.x,  SLIDE_DURATION) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_activeTween.tween_property(dboxAnswer, "position:x", _restPosAnswer.x, SLIDE_DURATION) \
			.set_delay(SLIDE_STAGGER) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


# Answer slides out first; speak follows before answer fully exits.
func _animateOut() -> void:
	if _activeTween:
		_activeTween.kill()
	var w := get_viewport_rect().size.x
	_activeTween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_activeTween.tween_property(dboxAnswer, "position:x", _restPosAnswer.x + w, SLIDE_DURATION) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_activeTween.tween_property(dboxSpeak,  "position:x", _restPosSpeak.x  - w, SLIDE_DURATION) \
			.set_delay(SLIDE_STAGGER) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_activeTween.finished.connect(func():
		dboxSpeak.hide()
		dboxAnswer.hide())
