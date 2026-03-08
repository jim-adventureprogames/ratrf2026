class_name HUD_HowToPlay
extends Control

static var _instance: HUD_HowToPlay

static func summon() -> HUD_HowToPlay:
	return _instance


# Wire in the editor.
@export var btnClose:   TextureButton
@export var txtContent: RichTextLabel

const HOW_TO_PLAY_FILE := "res://docs/how_to_play.txt"


func _ready() -> void:
	_instance = self
	btnClose.pressed.connect(turnOff)
	_loadContent()
	hide()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func turnOn() -> void:
	show()


func turnOff() -> void:
	hide()


func _loadContent() -> void:
	if txtContent == null:
		return
	if not FileAccess.file_exists(HOW_TO_PLAY_FILE):
		txtContent.text = "[b]How to Play[/b]\n\n(how_to_play.txt not found at %s)" % HOW_TO_PLAY_FILE
		return
	var file := FileAccess.open(HOW_TO_PLAY_FILE, FileAccess.READ)
	if file == null:
		txtContent.text = "[b]How to Play[/b]\n\n(could not open how_to_play.txt)"
		return
	txtContent.text = file.get_as_text()
