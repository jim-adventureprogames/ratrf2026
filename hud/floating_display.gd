class_name FloatingDisplay
extends Control

@export var imgDisplay: TextureRect
@export var lblDisplay: Label


# Positions this display at a world pixel position and begins any configured animation.
# worldPosition — pixel coords in the 320x240 world space (e.g. from MoverComponent.tileToPixel)
# image         — texture to show; hidden if null
# text          — string to show; hidden if empty
# lifetime      — seconds before queue_free; 0 = never auto-free
# moveOffset    — pixel offset to tween toward over the lifetime (Vector2.ZERO = no movement)
# bFade         — fade modulate alpha to 0 over the lifetime
func display(worldPosition: Vector2, image: Texture2D = null, text: String = "",
		lifetime: float = 2.0, moveOffset: Vector2 = Vector2.ZERO, bFade: bool = true) -> void:
	position = worldPosition

	imgDisplay.visible  = image != null
	if image != null:
		imgDisplay.texture = image

	lblDisplay.visible  = text != ""
	if text != "":
		lblDisplay.text = text

	if lifetime <= 0.0:
		return

	var tween := create_tween().set_parallel(true)

	if moveOffset != Vector2.ZERO:
		tween.tween_property(self, "position", worldPosition + moveOffset, lifetime)

	if bFade:
		tween.tween_property(self, "modulate:a", 0.0, lifetime)

	# Anchor for queue_free: fires once the lifetime duration has elapsed,
	# regardless of whether movement or fade tweeners were added.
	tween.tween_interval(lifetime)
	tween.chain().tween_callback(queue_free)
