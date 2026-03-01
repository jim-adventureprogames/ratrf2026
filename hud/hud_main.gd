class_name HUD_Main
extends Control

@export var btnDebugStart: Button


func _ready() -> void:
	btnDebugStart.pressed.connect(GameManager.startGame);
