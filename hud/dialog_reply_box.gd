class_name DialogReply
extends Control

@export var imgBG:    TextureRect
@export var txtReply: RichTextLabel

const HOVER_DURATION := 0.33
const COLOR_GOLD     := Color(1.0, 0.84, 0.0)
const COLOR_NORMAL   := Color.WHITE

var _activeTween:  Tween
var _currentColor: Color = COLOR_NORMAL
var response:      DialogueResponse

signal clicked


func _ready() -> void:
	imgBG.offset_right = size.x
	imgBG.offset_left  = size.x
	txtReply.add_theme_color_override("default_color", _currentColor)
	mouse_entered.connect(_onHoverEnter)
	mouse_exited.connect(_onHoverExit)
	gui_input.connect(_onGuiInput)


func _onGuiInput(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		clicked.emit()


func select() -> void:
	_animateActivate(0.0, COLOR_GOLD)


func deselect() -> void:
	_animateDeactivate(size.x, COLOR_NORMAL)


func _onHoverEnter() -> void:
	select()


func _onHoverExit() -> void:
	deselect()


func _animateActivate(targetLeft: float, targetColor: Color) -> void:
	if _activeTween:
		_activeTween.kill()
	imgBG.show();
	var fromLeft  := imgBG.offset_left
	var fromColor := _currentColor
	txtReply.add_theme_color_override("default_color", targetColor);
	_activeTween = create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_activeTween.tween_property(imgBG, "offset_left", targetLeft, HOVER_DURATION)
	
			
func _animateDeactivate(targetLeft: float, targetColor: Color) ->void:
	if _activeTween:
		_activeTween.kill()
		
	txtReply.add_theme_color_override("default_color", targetColor);
	imgBG.offset_left = targetLeft;
	imgBG.hide();
