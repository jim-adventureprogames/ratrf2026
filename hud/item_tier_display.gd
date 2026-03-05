class_name ItemTierDisplay
extends Control

@export var starSprites : Array[AnimatedSprite2D];

var tier : int;

func setItemTier(newTier: int) -> void:
	tier = newTier;
	for idx in starSprites.size():
		if idx <= tier:
			starSprites[idx].animation = "on";
		else:
			starSprites[idx].animation = "off";
			
		starSprites[idx].play();
		
		
