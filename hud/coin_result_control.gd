class_name CoinResultControl
extends Control

@export var imgResults: AnimatedSprite2D


func play(animName: StringName) -> void:
	imgResults.play(animName)
