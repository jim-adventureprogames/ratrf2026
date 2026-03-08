class_name HUD_TitleScreen
extends Control

static var _instance: HUD_TitleScreen

static func summon() -> HUD_TitleScreen:
	return _instance


# Wire all of these in the editor scene.
@export var btnStartGame: Button
@export var btnHowToPlay: Button
@export var btnOptions:   Button
@export var btnCredits:   Button
# Copyright / version label at the bottom of the screen.
@export var lblCopyright: RichTextLabel


func _ready() -> void:
	_instance = self
	btnStartGame.pressed.connect(_onStartGamePressed)
	btnHowToPlay.pressed.connect(_onHowToPlayPressed)
	btnOptions.pressed.connect(_onOptionsPressed)
	btnCredits.pressed.connect(_onCreditsPressed)
	turnOn()


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func turnOn() -> void:
	show()
	AudioManager.summon().setMusicState(AudioManager.EMusicState.MainMenu)


func turnOff() -> void:
	hide()


func _onStartGamePressed() -> void:
	turnOff()
	GameManager.startGame()


func _onHowToPlayPressed() -> void:
	var howToPlay := HUD_HowToPlay.summon()
	if howToPlay == null:
		return
	howToPlay.turnOn()


func _onOptionsPressed() -> void:
	var options := HUD_Options.summon()
	if options == null:
		return
	options.turnOn()


func _onCreditsPressed() -> void:
	var credits := HUD_Credits.summon()
	if credits == null:
		return
	credits.turnOn()
