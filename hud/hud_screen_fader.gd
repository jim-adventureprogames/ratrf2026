class_name HUD_ScreenFader
extends Control

static var _instance: HUD_ScreenFader

static func summon() -> HUD_ScreenFader:
	return _instance


@export var colorRect: ColorRect

# The color faded to by fadeToBlack() — set to your desired off-black in the inspector.
@export var fadeColor: Color = Color(0.05, 0.02, 0.05, 1.0)


func _ready() -> void:
	_instance = self
	if colorRect:
		colorRect.color = Color.TRANSPARENT


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


# Fades the overlay from transparent to fadeColor over `duration` seconds.
# Optional callback fires when the fade completes.
func fadeToBlack(duration: float = 0.5, onComplete: Callable = Callable()) -> void:
	if colorRect == null:
		return
	show();
	colorRect.color = Color(fadeColor, 0.0)
	colorRect.show()
	var tween := create_tween()
	tween.tween_property(colorRect, "color", fadeColor, duration)
	if onComplete.is_valid():
		tween.tween_callback(onComplete)


# Fades the overlay from fadeColor to transparent over `duration` seconds.
# Hides the ColorRect once fully clear.
func fadeToClear(duration: float = 0.5, onComplete: Callable = Callable()) -> void:
	if colorRect == null:
		return
	show();
	colorRect.color = fadeColor
	colorRect.show()
	var tween := create_tween()
	tween.tween_property(colorRect, "color", Color(fadeColor, 0.0), duration)
	tween.tween_callback(colorRect.hide)
	tween.tween_callback(hide)
	if onComplete.is_valid():
		tween.tween_callback(onComplete)
