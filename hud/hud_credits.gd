class_name HUD_Credits
extends Control

static var _instance: HUD_Credits

static func summon() -> HUD_Credits:
	return _instance


# Wire in the editor.
@export var btnClose:   TextureButton
# Use a RichTextLabel with BBCode enabled and scroll enabled.
@export var txtCredits: RichTextLabel

# Plain-text (or BBCode) file that holds the credits copy.
# Create this file and fill it in — the label will display it as-is.
const CREDITS_FILE := "res://docs/credits.txt"


func _ready() -> void:
	_instance = self
	btnClose.pressed.connect(turnOff)
	_loadCredits()
	hide()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func turnOn() -> void:
	show()


func turnOff() -> void:
	hide()


func _loadCredits() -> void:
	if txtCredits == null:
		return
	if not FileAccess.file_exists(CREDITS_FILE):
		# Friendly placeholder until the real file is written.
		txtCredits.text = "[b]Credits[/b]\n\n(credits.txt not found at %s)" % CREDITS_FILE
		return
	var file := FileAccess.open(CREDITS_FILE, FileAccess.READ)
	if file == null:
		txtCredits.text = "[b]Credits[/b]\n\n(could not open credits.txt)"
		return
	# The file is treated as BBCode so the author can use formatting tags.
	txtCredits.text = file.get_as_text()
